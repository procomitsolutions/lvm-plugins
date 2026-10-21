# API REST, GraphQL y webhooks

## 1. API REST: lo básico

```bash
curl -L \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-GitHub-Api-Version: 2026-03-10" \
  https://api.github.com/repos/OWNER/REPO
```
- Base: `https://api.github.com` (GHE.com: `https://api.SUBDOMINIO.ghe.com`; GHES: `https://HOST/api/v3`).
- Siempre enviar `User-Agent` (curl/gh/Octokit lo hacen).
- `gh api` resuelve auth, versión y paginación: `gh api repos/{owner}/{repo}/pulls --paginate --jq '.[].number'`.
- OpenAPI completo en `github/rest-api-description`. SDKs oficiales Octokit (JS, Ruby, .NET, Go vía `go-github` comunitario, Python vía PyGithub/githubkit de terceros).

## 2. Versiones

- Versionado por fecha en el header `X-GitHub-Api-Version`. Sin header → `2022-11-28` (verifica el default actual en "Versiones de API"). Versión más reciente: **`2026-03-10`**. Cada versión se soporta ≥ 24 meses tras la siguiente. Versión no soportada → `400`.
- Cambios aditivos llegan a todas las versiones; disruptivos solo a la nueva.

### Cambios disruptivos de `2026-03-10` (los que más rompen)
- `GET /rate_limit`: se elimina `rate` → usa `resources.core`.
- Issues/PRs: se elimina el campo singular **`assignee`** → usa el array `assignees` (lectura y escritura).
- PRs: se elimina **`merge_commit_sha`** de las respuestas.
- Repos: se eliminan `has_downloads`, `use_squash_pr_title_as_default` (→ `squash_merge_commit_title`), y restos del media type `beta` (`master_branch`→`default_branch`, `user`→`owner`, emails como objetos).
- `GET /repos/{o}/{r}/contents/{path}` en directorios: los submódulos traen `type: "submodule"` (antes "file").
- `POST .../actions/workflows/{id}/dispatches`: responde **`200` con detalles del run** (antes `204`); desaparece `return_run_details`.
- `DELETE /app/installations/{id}`: `202` (antes `204`).
- Controles comerciales: varias operaciones devuelven **`451`** en vez de `403`/`422`.
- Code scanning default setup: idioma `javascript-typescript` en lugar de `javascript`/`typescript`.
- Advisories/Dependabot: `cvss` obsoleto → `cvss_severities` (`cvss_v3`, `cvss_v4`).
- Atestaciones (listados): sin `bundle` → usa `bundle_url`.
- Se eliminan `authorizations_url` y `hub_url` de `GET /` y el endpoint `/hub`.
- `POST /orgs/{org}/teams`: sin `permission`.
- SARIF: `Content-Type: application/sarif+json`.
Antes de migrar: lee "Cambios disruptivos", actualiza el header y prueba.

## 3. Paginación
- `per_page` (máx. 100 en la mayoría) y header `Link` con `rel="next"`. Algunos endpoints usan cursores (`before`/`after`). No construyas URLs de página a mano: sigue `Link`.
- Octokit: `octokit.paginate(...)`; gh: `--paginate` (+ `--slurp` para un único array JSON).

## 4. Rate limits

Primarios (por hora):
| Autenticación | Límite |
|---|---|
| Sin autenticar | 60 / IP |
| Usuario (PAT, OAuth, token de usuario de App) | 5.000 (compartido entre todos sus tokens) |
| App/OAuth de org Enterprise Cloud | 15.000 |
| Instalación de GitHub App | 5.000 + 50/repo y 50/usuario sobre 20, máx. 12.500 (15.000 en Enterprise Cloud) |
| `GITHUB_TOKEN` | 1.000 por repo (15.000 en Enterprise Cloud) |

Secundarios (anti-abuso; no ampliables): del orden de 100 solicitudes concurrentes, 900 puntos/min por endpoint REST (GET=1, POST/PATCH/PUT/DELETE=5), 2.000 puntos/min en GraphQL, 90 s de CPU por minuto, y ~80 solicitudes de creación de contenido/min y 500/h. Verifica en "Límites de tasa".

Headers: `x-ratelimit-limit`, `-remaining`, `-used`, `-reset` (epoch), `-resource`. Al exceder: `403` o `429`; si viene `retry-after`, espera esos segundos; si `x-ratelimit-remaining: 0`, espera hasta `reset`; si no, backoff exponencial ≥ 1 min. Consultar: `gh api rate_limit --jq .resources.core` (no consume cuota).

Buenas prácticas: requests condicionales con `ETag`/`If-None-Match` (un `304` no consume cuota primaria), webhooks en vez de polling, serializar mutaciones, cachear.

## 5. Errores HTTP típicos
- `401` credencial inválida/expirada.
- `403` sin permiso, rate limit, PAT classic bloqueado por la org, SSO no autorizado (`X-GitHub-SSO` header), "Resource not accessible by integration" (al token le falta permiso).
- `404` también para recursos privados sin acceso (no revela existencia). Revisa permisos del token antes de asumir que no existe.
- `409` conflicto (repo vacío, merge en curso), `410` deshabilitado (issues off), `422` validación (rama ya existe, PR sin diferencias), `451` bloqueo legal/comercial.

## 6. Recetas REST
```bash
# Crear PR
gh api repos/{owner}/{repo}/pulls -f title="Fix" -f head=feature -f base=main -f body="..."
# Disparar workflow con inputs
gh api repos/{owner}/{repo}/actions/workflows/deploy.yml/dispatches -f ref=main -f 'inputs[env]=prod'
# repository_dispatch
gh api repos/{owner}/{repo}/dispatches -f event_type=sync -F 'client_payload[force]=true'
# Crear/actualizar secreto (gh cifra con la clave pública del repo)
gh secret set API_KEY --body "$VALOR" -R owner/repo
# Contenido de archivo (base64)
gh api repos/{owner}/{repo}/contents/README.md --jq .content | base64 -d
# Reglas efectivas en una rama
gh api repos/{owner}/{repo}/rules/branches/main
# Metadatos (IPs, huellas SSH)
gh api meta --jq .actions
```
Otras áreas de la API: rulesets, custom properties, issue types, sub-issues y dependencias de issues, campos de issue, Projects (v2, REST y GraphQL), agent tasks (Copilot), Copilot user management/metrics, billing usage y budgets, attestations, code security configurations, campaigns, private registries.

## 7. GraphQL

- Endpoint único `POST https://api.github.com/graphql`; explorer en la doc; esquema público descargable.
- Límites: 5.000 **puntos**/h por usuario (10.000 para Apps de Enterprise Cloud, verificar); `first`/`last` entre 1 y 100; máx. 500.000 nodos por consulta. Consulta el costo con `rateLimit { cost remaining resetAt }`.
- Paginación por cursor: `pageInfo { hasNextPage endCursor }` + `after:`.
```bash
gh api graphql -f query='
  query($owner:String!,$name:String!,$cursor:String){
    repository(owner:$owner,name:$name){
      pullRequests(states:OPEN,first:50,after:$cursor){
        nodes{ number title author{login} }
        pageInfo{ hasNextPage endCursor }
      }
    }
  }' -F owner=OWNER -F name=REPO --paginate
```
- Usa GraphQL para traer datos anidados en una sola llamada y para Projects v2 (campos personalizados: `updateProjectV2ItemFieldValue`). REST para operaciones simples y para lo que solo existe en REST.
- IDs globales (`node_id`) compatibles entre REST y GraphQL.

## 8. Webhooks

- Niveles: repo, org, GitHub App, Marketplace, Sponsors. Hasta 20 webhooks por evento por repo/org (verificar).
- Headers: `X-GitHub-Event`, `X-GitHub-Delivery` (GUID), `X-GitHub-Hook-ID`, `X-Hub-Signature-256` (HMAC-SHA256 del cuerpo crudo con el secreto).
- Responde **2XX en < 10 s** y procesa en segundo plano (cola). Payload máx. 25 MB (eventos mayores no se entregan).
- No hay reintento automático: revisa "Recent Deliveries" y **redelivery** manual o por API (deliveries de los últimos 3 días).
- Verificación (Python):
```python
import hmac, hashlib
def valido(secret: bytes, body: bytes, sig_header: str) -> bool:
    esperado = "sha256=" + hmac.new(secret, body, hashlib.sha256).hexdigest()
    return hmac.compare_digest(esperado, sig_header or "")
```
- Idempotencia con `X-GitHub-Delivery`. Desarrollo local: `gh webhook forward --repo=owner/repo --events=push --url=http://localhost:3000/webhook` (extensión `cli/gh-webhook`) o smee.io.
- IPs de origen: clave `hooks` de `GET /meta`.

## 9. GitHub Apps programáticas
1. Registrar App (permisos mínimos, eventos webhook, callback URL si usa tokens de usuario).
2. JWT firmado con la clave privada: `iat` = ahora − 60 s, `exp` ≤ 10 min, `iss` = App ID o Client ID.
3. `GET /app/installations` → `POST /app/installations/{id}/access_tokens` (puedes reducir `repositories` y `permissions`).
4. Usar el token (1 h). Octokit `@octokit/app` gestiona todo.
Apps de Marketplace, manifest flow para crear Apps preconfiguradas, y webhooks de instalación (`installation`, `installation_repositories`).
