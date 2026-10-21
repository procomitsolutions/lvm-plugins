# Diagnóstico por síntoma

Método: reproducir → leer el mensaje exacto → identificar la credencial/actor en juego → revisar permisos/reglas → corregir lo mínimo. Primero `gh auth status`, `git remote -v` y el estado de https://www.githubstatus.com/.

## Git (push/clone/pull)

| Síntoma | Causa probable | Arreglo |
|---|---|---|
| `Support for password authentication was removed` | Contraseña por HTTPS | `gh auth login && gh auth setup-git`, GCM o PAT como contraseña |
| `Permission denied (publickey)` | Clave no cargada / no subida / usuario equivocado | `ssh -vT git@github.com`; `ssh-add -l`; subir `.pub`; URL `git@github.com:` (usuario `git`) |
| `Host key verification failed` | known_hosts viejo (GitHub rotó la clave RSA en 2023) | `ssh-keygen -R github.com` y verificar huellas oficiales |
| `ssh: connect to host github.com port 22: Connection timed out` | Puerto 22 bloqueado | `ssh.github.com` puerto 443 (ver autenticación) |
| `Permission to owner/repo.git denied to otro-usuario` | Credencial cacheada de otra cuenta | Borrar credencial (Keychain/Credential Manager), `gh auth switch`, alias SSH por cuenta |
| `remote: Repository not found` | Sin acceso a repo privado, typo, o token sin el repo (fine-grained) | Verificar acceso/URL y repos del token; SSO autorizado |
| `! [rejected] main -> main (non-fast-forward)` / `fetch first` | Remoto tiene commits nuevos | `git pull --rebase` y push; no `--force` en ramas compartidas |
| `remote: error: GH006: Protected branch update failed` / `GH013: Repository rule violations` | Rama protegida / ruleset (PR requerido, firmas, checks, push protection, rutas) | Abrir PR; firmar commits; leer la regla citada; push protection: quitar el secreto |
| `refusing to allow ... to create or update workflow` | Token sin scope `workflow` / permiso `workflows` | Añadir scope o usar App con permiso Workflows |
| `this exceeds GitHub's file size limit of 100.00 MB` | Archivo > 100 MB en el historial | Git LFS (`git lfs migrate import`) o `git filter-repo`, re-push |
| `RPC failed; HTTP 400/500`, `early EOF` en push grande | Push > 2 GB o red | Pushear en lotes (por rango de commits), SSH, revisar proxy |
| `fatal: refusing to merge unrelated histories` | Repo creado con README + repo local distinto | `git pull origin main --allow-unrelated-histories` (si es intencional) |
| `You have divergent branches` | Política de pull no definida | `git config pull.rebase true` (o `ff only`) |
| Commits "Unverified" | Email del commit no verificado / clave no subida como signing key | Ver firma en autenticación |
| Commits no cuentan en el gráfico de contribuciones | Email no asociado, fork, rama no por defecto | Asociar email; contribuciones cuentan al llegar a la rama por defecto del repo padre |

## Actions

| Síntoma | Causa probable | Arreglo |
|---|---|---|
| El workflow no aparece/no corre | YAML inválido (se ve en la pestaña Actions), archivo fuera de `.github/workflows`, Actions deshabilitado, filtros `branches/paths` no coinciden, evento hecho por `GITHUB_TOKEN`, `[skip ci]`, archivo > 500 KB | Revisar la pestaña Actions, `actionlint`, settings, filtros |
| `workflow_dispatch` no muestra botón | El archivo no está en la rama por defecto | Mergearlo a la rama por defecto |
| `schedule` no corre / se retrasa | Repo público inactivo 60 días, carga alta, cron en UTC | Reactivar; tolerar retraso; no usar intervalos exactos |
| Job "Queued" mucho tiempo | Etiqueta de runner inexistente (self-hosted offline o typo en `runs-on`), límite de concurrencia, sin minutos/presupuesto | Revisar etiquetas, runners online, billing |
| `Resource not accessible by integration` (403) | `GITHUB_TOKEN` sin permiso, PR desde fork (solo lectura), Dependabot | `permissions:` correctos; para forks usar patrón `workflow_run`; secretos de Dependabot |
| `Bad credentials`/`Requires authentication` en `gh` | Falta `GH_TOKEN` en el step | `env: GH_TOKEN: ${{ github.token }}` |
| Secretos vacíos | PR desde fork / Dependabot / nombre mal escrito / secreto de environment sin `environment:` | Ver reglas de exposición |
| `Error: Process completed with exit code 137` | OOM o cancelación por recursos | Menos paralelismo, larger runner, swap |
| `No space left on device` | 14 GB de disco en hospedados | Limpiar herramientas preinstaladas (`/usr/share/dotnet`, `/opt/ghc`, `docker system prune`), larger runner |
| Job cortado a las 6 h | Límite de job hospedado | Dividir o self-hosted; `timeout-minutes` menor para fallar antes |
| Rompe tras cambio de imagen `-latest` | Migración de imagen (`ubuntu-latest`, `macos-latest`) | Fijar `ubuntu-24.04` etc. y planear la migración |
| Cache no se restaura | Key distinta, rama sin acceso al scope, expulsada (7 días/10 GB) | Revisar `key`/`restore-keys`, `gh cache list` |
| `Unable to resolve action` | Repo/tag inexistente, acción privada sin acceso, política de org bloquea la acción, pin a SHA requerido | Verificar ref, settings de Access, política de acciones permitidas |
| `The job was not started because recent account payments have failed or your spending limit needs to be increased` | Billing/presupuesto | Revisar métodos de pago y presupuestos |
| Check requerido queda "Expected" | Workflow filtrado por paths/branches, nombre de job distinto, falta `merge_group` con merge queue | Ver repos-ramas-prs.md |
| Re-run usa el workflow viejo | Re-run reutiliza el commit/definición original | Nuevo push o `workflow_dispatch` |

Depuración: `gh run view <id> --log-failed`, re-run con debug logging, `ACTIONS_STEP_DEBUG`, tmate-like solo en repos privados de confianza. Para runners: diagnósticos en `_diag/` del self-hosted.

## API / gh

| Síntoma | Causa | Arreglo |
|---|---|---|
| `API rate limit exceeded` | Cuota primaria agotada | Esperar `x-ratelimit-reset`; autenticar; GitHub App; ETags |
| `You have exceeded a secondary rate limit` | Ráfagas/concurrencia/mutaciones rápidas | Serializar, `retry-after`, backoff ≥ 60 s |
| 404 en recurso que existe | Token sin acceso (privado), SSO no autorizado, fine-grained sin ese repo | Revisar permisos del token |
| 403 con "Resource protected by organization SAML enforcement" | PAT/SSH key no autorizada para SSO | Configure SSO → Authorize |
| 403 "classic personal access tokens are forbidden" | Política de org | Fine-grained PAT o GitHub App |
| 422 "Validation Failed" | Parámetros (rama inexistente, PR sin cambios, ya existe) | Leer `errors[]` del cuerpo |
| Campos que "desaparecieron" (`assignee`, `merge_commit_sha`) | Usando API `2026-03-10` | Migrar a `assignees`, etc. (ver api-rest-graphql-webhooks.md) |
| Webhook "failed" | Timeout > 10 s, TLS, firma mal validada (cuerpo re-serializado) | Responder rápido; validar sobre bytes crudos |

## Pages
- 404 tras publicar: fuente/carpeta incorrecta, falta `index.html`, baseurl en sitios de proyecto (`/repo/`), caché (esperar unos minutos).
- "Domain's DNS record could not be retrieved" / certificado pendiente: DNS mal apuntado, CAA que no permite letsencrypt, esperar propagación; quitar y volver a poner el dominio.
- Build de Jekyll falla: revisar la ejecución "pages build and deployment" en Actions.

## Packages / GHCR
- `denied: permission_denied` / `unauthorized`: token sin `write:packages`, fine-grained (no soportado), owner con mayúsculas en el nombre de imagen, repo sin acceso de Actions al paquete (Package settings → Manage Actions access), SSO.
- Imagen no aparece en el repo: falta label `org.opencontainers.image.source`.

## Dependabot
- No abre PRs: `dependabot.yml` inválido (revisar Insights → Dependency graph → Dependabot), ecosistema/directorio incorrecto, límite de PRs abiertos, registro privado sin credenciales.
- Workflows fallan en PRs de Dependabot por secretos: usar secretos de Dependabot.

## Copilot
- Cloud agent no arranca: política deshabilitada, repo excluido, ruleset incompatible (añadir bypass), `copilot-setup-steps` falla (ver logs de la sesión), firewall bloquea un host (allowlist).
- Sin AI credits: revisar uso/presupuesto; completions siguen funcionando en planes pagos.
- Copilot no ve un archivo: content exclusion o archivo no indexado.

## Cuenta
- Perdiste 2FA: códigos de recuperación, llaves/passkeys, GitHub Mobile, o recuperación con verificación (puede tardar días).
- Cuenta marcada/spam o pagos bloqueados: soporte (`support.github.com`).
