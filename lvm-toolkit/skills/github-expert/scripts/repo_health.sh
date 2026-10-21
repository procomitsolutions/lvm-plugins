#!/usr/bin/env bash
# Chequeo de salud de un repo con GitHub CLI (SOLO LECTURA).
# Uso: scripts/repo_health.sh OWNER/REPO
# Requiere: gh autenticado (gh auth status) y jq. Algunos endpoints requieren permisos de admin;
# si fallan se informa y se continúa.
set -uo pipefail

REPO="${1:-}"
if [[ -z "$REPO" ]]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
fi
[[ -z "$REPO" ]] && { echo "Uso: $0 OWNER/REPO"; exit 2; }
command -v gh >/dev/null || { echo "Falta gh"; exit 2; }
command -v jq >/dev/null || { echo "Falta jq"; exit 2; }

H=(-H "X-GitHub-Api-Version: 2022-11-28")   # cambia a 2026-03-10 si tus integraciones ya migraron
api() { gh api "${H[@]}" "$@" 2>/dev/null; }
sec() { printf '\n== %s ==\n' "$1"; }
warn() { printf '  ⚠ %s\n' "$1"; }
ok() { printf '  ✓ %s\n' "$1"; }

sec "Autenticación"
gh auth status 2>&1 | sed 's/^/  /'

sec "Rate limit (core)"
api rate_limit --jq '.resources.core | "  \(.remaining)/\(.limit) restantes, reset \(.reset | todate)"' || warn "no disponible"

sec "Repositorio $REPO"
R="$(api "repos/$REPO")" || { warn "No se pudo leer el repo (¿acceso/SSO?)"; exit 1; }
echo "$R" | jq -r '"  visibilidad: \(.visibility) | rama por defecto: \(.default_branch) | archivado: \(.archived)
  merge: commit=\(.allow_merge_commit) squash=\(.allow_squash_merge) rebase=\(.allow_rebase_merge) auto-merge=\(.allow_auto_merge) borrar-rama=\(.delete_branch_on_merge)"'
DEF="$(echo "$R" | jq -r .default_branch)"

sec "Seguridad y análisis"
echo "$R" | jq -r '.security_and_analysis // {} | to_entries[] | "  \(.key): \(.value.status)"' \
  || warn "sin datos (requiere admin)"
if api "repos/$REPO/vulnerability-alerts" -i >/dev/null; then ok "Dependabot alerts habilitadas"; else warn "Dependabot alerts deshabilitadas o sin permiso para verlo"; fi
api "repos/$REPO/code-scanning/default-setup" --jq '"  code scanning default setup: \(.state) \(.languages // [] | join(","))"' \
  || warn "code scanning: no configurado o sin permiso"
[[ -n "$(api "repos/$REPO/contents/.github/dependabot.yml" --jq .name)" ]] && ok ".github/dependabot.yml presente" || warn "sin .github/dependabot.yml (version updates)"
for f in .github/CODEOWNERS CODEOWNERS docs/CODEOWNERS; do
  [[ -n "$(api "repos/$REPO/contents/$f" --jq .name)" ]] && { ok "CODEOWNERS en $f"; break; }
done
[[ -n "$(api "repos/$REPO/contents/SECURITY.md" --jq .name)$(api "repos/$REPO/contents/.github/SECURITY.md" --jq .name)" ]] \
  && ok "SECURITY.md presente" || warn "sin SECURITY.md"

sec "Reglas efectivas en '$DEF' (rulesets)"
RULES="$(api "repos/$REPO/rules/branches/$DEF")"
if [[ -n "$RULES" && "$RULES" != "[]" ]]; then
  echo "$RULES" | jq -r '.[] | "  - \(.type)\(if .parameters then " " + (.parameters|tostring) else "" end)"' | cut -c1-200
else
  warn "ningún ruleset aplica a '$DEF'"
fi
sec "Branch protection clásica en '$DEF'"
api "repos/$REPO/branches/$DEF/protection" --jq '"  PR reviews: \(.required_pull_request_reviews.required_approving_review_count // 0) | status checks: \(.required_status_checks.contexts // [] | join(",")) | force push: \(.allow_force_pushes.enabled) | admins: \(.enforce_admins.enabled)"' \
  || echo "  (sin protección clásica o sin permiso)"

sec "Actions"
api "repos/$REPO/actions/permissions" --jq '"  habilitado: \(.enabled) | acciones permitidas: \(.allowed_actions) | pin SHA requerido: \(.sha_pinning_required // "n/d")"' || warn "sin permiso"
api "repos/$REPO/actions/permissions/workflow" --jq '"  GITHUB_TOKEN por defecto: \(.default_workflow_permissions) | puede aprobar PRs: \(.can_approve_pull_request_reviews)"' || true
gh run list -R "$REPO" -L 10 --json conclusion,workflowName,headBranch,createdAt \
  --jq '.[] | "  \(.createdAt[0:16]) \(.conclusion // "en curso") \(.workflowName) [\(.headBranch)]"' 2>/dev/null || true
api "repos/$REPO/actions/runners" --jq '"  self-hosted del repo: \(.total_count)"' || true
api "repos/$REPO/actions/cache/usage" --jq '"  cache: \(.active_caches_size_in_bytes/1048576|floor) MB en \(.active_caches_count) entradas"' || true

sec "Alertas abiertas (si hay permiso)"
for kind in dependabot code-scanning secret-scanning; do
  n="$(api "repos/$REPO/$kind/alerts?state=open&per_page=100" --jq 'length')" \
    && echo "  $kind: $n abiertas (máx. 100 mostradas)" || echo "  $kind: n/d"
done
echo
echo "Listo. Revisa los ⚠ y compáralos con las reglas de oro de la skill."
