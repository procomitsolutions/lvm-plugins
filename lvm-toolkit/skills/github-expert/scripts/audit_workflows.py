#!/usr/bin/env python3
"""Auditoría estática de workflows de GitHub Actions (sin red, sin dependencias).

Uso:
    python3 audit_workflows.py [RUTA ...] [--json] [--min-severity {info,warn,critical}]

RUTA puede ser un repo (busca .github/workflows), un directorio o archivos .yml/.yaml.
Sale con código 1 si hay hallazgos 'critical', 0 en otro caso.

Detecta:
  critical  - interpolación de contexto no confiable dentro de `run:` / `script:` (inyección)
  critical  - pull_request_target / workflow_run + checkout del código del PR
  warn      - falta `permissions:` a nivel workflow; uso de write-all
  warn      - acciones de terceros no fijadas a un SHA de 40 caracteres
  warn      - self-hosted runner en workflow disparado por pull_request(_target)
  warn      - secrets: inherit
  info      - jobs sin timeout-minutes
  info      - acciones oficiales (actions/*, github/*) con tag en vez de SHA
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, asdict
from pathlib import Path

SEVERITIES = {"info": 0, "warn": 1, "critical": 2}

UNTRUSTED = re.compile(
    r"\$\{\{\s*[^}]*("
    r"github\.event\.(issue|pull_request|comment|review|review_comment|discussion|pages|commits|head_commit|workflow_run)"
    r"[\w.\[\]*'-]*\.(title|body|message|name|email|ref|label|head_branch|page_name|default_branch)"
    r"|github\.head_ref"
    r"|github\.event\.pull_request\.head\.(ref|label)"
    r")[^}]*\}\}"
)
USES = re.compile(r"^\s*(?:-\s*)?uses:\s*['\"]?([^'\"\s#]+)")
SHA40 = re.compile(r"^[0-9a-f]{40}$")
PR_HEAD_CHECKOUT = re.compile(
    r"github\.event\.pull_request\.head\.(sha|ref)|github\.head_ref|refs/pull/|github\.event\.workflow_run\.head_(sha|branch)"
)


@dataclass
class Finding:
    file: str
    line: int
    severity: str
    rule: str
    message: str


def indent_of(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def find_files(paths: list[str]) -> list[Path]:
    out: list[Path] = []
    for p in paths:
        path = Path(p)
        if path.is_file():
            out.append(path)
        elif path.is_dir():
            wf = path / ".github" / "workflows"
            base = wf if wf.is_dir() else path
            out += sorted(list(base.glob("*.yml")) + list(base.glob("*.yaml")))
    return out


def block_lines(lines: list[str], start: int) -> list[tuple[int, str]]:
    """Valor de una clave YAML: la parte inline más las líneas más indentadas que siguen."""
    key_line = lines[start]
    m = re.match(r"^(\s*)(-\s+)?", key_line)
    key_indent = len(m.group(1)) + (len(m.group(2)) if m.group(2) else 0)
    result = [(start, key_line.split(":", 1)[1] if ":" in key_line else "")]
    for j in range(start + 1, len(lines)):
        ln = lines[j]
        if ln.strip() == "":
            continue
        if indent_of(ln) <= key_indent:
            break
        result.append((j, ln))
    return result


def split_jobs(lines: list[str]) -> list[tuple[int, str, list[str]]]:
    """[(línea, id_job, líneas_del_job)] a partir de la clave `jobs:` de nivel superior."""
    try:
        start = next(i for i, l in enumerate(lines) if re.match(r"^jobs\s*:\s*$", l))
    except StopIteration:
        return []
    body = []
    for i in range(start + 1, len(lines)):
        ln = lines[i]
        if ln.strip() and indent_of(ln) == 0 and not ln.lstrip().startswith("#"):
            break
        body.append((i, ln))
    indents = [indent_of(l) for _, l in body if l.strip() and not l.lstrip().startswith("#")]
    if not indents:
        return []
    jind = min(indents)
    jobs, cur = [], None
    for i, ln in body:
        if ln.strip() and indent_of(ln) == jind and re.match(r"^\s*[\w-]+\s*:\s*$", ln):
            cur = (i, ln.strip().rstrip(":"), [])
            jobs.append(cur)
        elif cur is not None:
            cur[2].append(ln)
    return jobs


def audit_file(path: Path) -> list[Finding]:
    raw = path.read_text(encoding="utf-8", errors="replace")
    # quita comentarios de línea (aproximado: ' #' fuera de comillas simples/dobles)
    lines = [re.sub(r"""(^|\s)#(?=(?:[^"']|"[^"]*"|'[^']*')*$).*$""", "", l).rstrip() for l in raw.splitlines()]
    text = "\n".join(lines)
    f: list[Finding] = []
    name = str(path)

    is_workflow = bool(re.search(r"(?m)^['\"]?on['\"]?\s*:", text)) and bool(re.search(r"(?m)^jobs\s*:", text))
    is_action = bool(re.search(r"(?m)^runs\s*:", text)) and not is_workflow
    if not (is_workflow or is_action):
        return f   # dependabot.yml, issue forms, etc.

    def add(i, sev, rule, msg):
        f.append(Finding(name, i + 1, sev, rule, msg))

    # --- Triggers ---
    on_block = re.search(r"(?ms)^['\"]?on['\"]?\s*:(.*?)(?=^\S)", text + "\nEOF:")
    on_text = on_block.group(1) if on_block else ""
    on_inline = re.search(r"(?m)^['\"]?on['\"]?\s*:\s*(.+)$", text)
    triggers = on_text + (on_inline.group(1) if on_inline else "")
    privileged = bool(re.search(r"\b(pull_request_target|workflow_run)\b", triggers))
    pr_like = bool(re.search(r"\bpull_request(_target)?\b", triggers))

    # --- permissions a nivel workflow ---
    if is_workflow and not re.search(r"(?m)^permissions\s*:", text):
        add(0, "warn", "missing-permissions",
            "Sin `permissions:` a nivel workflow: el GITHUB_TOKEN hereda el default del repo/org "
            "(puede ser escritura). Declara `permissions: contents: read` y amplía por job.")
    for i, ln in enumerate(lines):
        if re.search(r"permissions\s*:\s*write-all", ln):
            add(i, "warn", "write-all", "`permissions: write-all` concede todo: usa permisos mínimos.")

    # --- uses: pinning y checkout ---
    for i, ln in enumerate(lines):
        m = USES.match(ln)
        if not m:
            continue
        ref = m.group(1)
        if ref.startswith("./") or ref.startswith("docker://"):
            continue
        if "@" not in ref:
            add(i, "warn", "unpinned-action", f"`{ref}` sin versión.")
            continue
        repo, version = ref.rsplit("@", 1)
        if SHA40.match(version):
            continue
        owner = repo.split("/")[0].lower()
        if owner in ("actions", "github"):
            add(i, "info", "official-action-tag",
                f"`{ref}` usa tag; en entornos sensibles fíjala a SHA (`@<sha40> # {version}`).")
        else:
            add(i, "warn", "unpinned-action",
                f"Acción de terceros `{ref}` no fijada a SHA completo: un tag/rama puede moverse. "
                f"Usa `{repo}@<sha40> # {version}` y Dependabot para actualizar.")

        # checkout del head del PR en workflows privilegiados
        if privileged and repo.lower() == "actions/checkout":
            following = "\n".join(lines[i:i + 8])   # bloque `with:` que suele seguir
            if PR_HEAD_CHECKOUT.search(following):
                add(i, "critical", "pwn-request",
                    "Checkout del código del PR en un workflow `pull_request_target`/`workflow_run` "
                    "(con secretos y token de escritura). No ejecutes código no confiable aquí; "
                    "separa en `pull_request` (sin privilegios) + `workflow_run` que solo lea artefactos.")

    # --- inyección de scripts en run: / script: ---
    for i, ln in enumerate(lines):
        if re.match(r"^\s*(-\s+)?(run|script)\s*:", ln):
            for j, bl in block_lines(lines, i):
                for mm in UNTRUSTED.finditer(bl):
                    add(j, "critical", "script-injection",
                        f"`{mm.group(0).strip()}` se interpola directamente en un script. "
                        "Pásalo por `env:` (p. ej. `TITLE: ${{ ... }}`) y usa \"$TITLE\" entre comillas.")

    # --- self-hosted expuesto a PRs ---
    if pr_like:
        for i, ln in enumerate(lines):
            if re.search(r"runs-on\s*:.*self-hosted", ln) or (
                re.match(r"^\s*runs-on\s*:\s*$", ln) and "self-hosted" in "\n".join(lines[i:i + 4])):
                add(i, "warn", "self-hosted-pr",
                    "Runner self-hosted en un workflow disparado por PRs: en repos públicos cualquiera puede "
                    "ejecutar código persistente en tu máquina. Usa runners hospedados o efímeros/JIT aislados.")

    # --- secrets: inherit ---
    for i, ln in enumerate(lines):
        if re.match(r"^\s*secrets\s*:\s*inherit\s*$", ln):
            add(i, "warn", "secrets-inherit",
                "`secrets: inherit` pasa TODOS los secretos al workflow llamado; pásalos explícitamente.")

    # --- timeout-minutes por job ---
    for i, job_id, jl in split_jobs(lines):
        content = [l for l in jl if l.strip() and not l.lstrip().startswith("#")]
        if not content:
            continue
        kind = min(indent_of(l) for l in content)   # indentación de las claves del job
        keys = {l.strip().split(":", 1)[0] for l in content if indent_of(l) == kind}
        if "uses" in keys:          # llamada a reusable workflow: el timeout va en el llamado
            continue
        if "timeout-minutes" not in keys:
            add(i, "info", "missing-timeout",
                f"Job `{job_id}` sin `timeout-minutes` (default 360 min): un cuelgue consume 6 h de minutos.")

    return f


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("paths", nargs="*", default=["."])
    ap.add_argument("--json", action="store_true", help="salida JSON")
    ap.add_argument("--min-severity", choices=list(SEVERITIES), default="info")
    a = ap.parse_args()

    files = find_files(a.paths)
    if not files:
        print("No se encontraron workflows (.yml/.yaml).", file=sys.stderr)
        return 0
    findings = [x for p in files for x in audit_file(p)
                if SEVERITIES[x.severity] >= SEVERITIES[a.min_severity]]
    findings.sort(key=lambda x: (-SEVERITIES[x.severity], x.file, x.line))

    if a.json:
        print(json.dumps([asdict(x) for x in findings], ensure_ascii=False, indent=2))
    else:
        icon = {"critical": "🔴 CRITICAL", "warn": "🟠 WARN", "info": "🔵 INFO"}
        for x in findings:
            print(f"{icon[x.severity]:12} {x.file}:{x.line} [{x.rule}] {x.message}")
        counts = {s: sum(1 for x in findings if x.severity == s) for s in SEVERITIES}
        print(f"\n{len(files)} archivo(s) | critical={counts['critical']} warn={counts['warn']} info={counts['info']}")
    return 1 if any(x.severity == "critical" for x in findings) else 0


if __name__ == "__main__":
    sys.exit(main())
