# Repositorios, ramas y pull requests

## 1. Repositorios

- Visibilidad: `public`, `private`, `internal` (solo en Enterprise: visible para miembros de la empresa). Cambiar de público a privado desactiva features gratuitas (GHAS) y desvincula forks públicos.
- Plantillas: marcar "Template repository" → "Use this template" (copia sin historial). Repo solo de issues.
- Transferir: redirecciones automáticas para web y git (excepto si se crea otro repo con el nombre viejo). Renombrar: igual, redirige.
- Borrar: owner/admin; restaurable dentro de **90 días** en muchos casos (no si era fork con red borrada, etc.).
- Archivar: solo lectura (issues/PRs/código), reversible.
- Archivos de comunidad (raíz, `.github/` o `docs/`): `README.md`, `LICENSE`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `SUPPORT.md`, `FUNDING.yml`, `CITATION.cff`. Un repo público `.github` de la org provee defaults (no para LICENSE).
- Topics, social preview, autolinks (p. ej. `JIRA-` → URL), `.gitattributes` con `linguist-*` para lenguajes/diffs (`linguist-generated=true` colapsa archivos generados).

### Límites de tamaño
| Elemento | Límite |
|---|---|
| Archivo en git | aviso a 50 MiB, **bloqueo a 100 MiB** |
| Subida por navegador | 25 MiB |
| Repo | ideal < 1 GB, muy recomendado < 5 GB (ver "Límites de los repositorios") |
| Push único | 2 GB |
| Asset de release | < 2 GiB por archivo |
| Git LFS | límites por plan (consultar "Git LFS" en facturación) |

Archivos grandes: Git LFS (`git lfs track "*.psd"`, commitear `.gitattributes`). Para sacar un archivo grande ya commiteado: `git lfs migrate import --include="*.zip" --everything` o `git filter-repo`. LFS no se incluye en los archivos "Download ZIP" salvo que se habilite en settings.

## 2. Ramas protegidas vs rulesets

| | Branch protection (clásica) | Rulesets |
|---|---|---|
| Alcance | Repo | Repo, **organización** y empresa (con condiciones por nombre de repo o custom properties) |
| Múltiples a la vez | Una regla por patrón | Se **apilan**: aplica la más restrictiva |
| Modo prueba | No | `evaluate` (Insights de reglas) en Enterprise |
| Bypass | Admins | Lista de bypass: roles, equipos, GitHub Apps, deploy keys, Copilot |
| Objetivos | Ramas | Ramas, tags y **push rulesets** (rutas, extensiones, tamaño de archivo) |
| Visibilidad | Solo admins | Cualquiera con lectura ve las reglas |

Disponibilidad: públicos en Free; públicos y privados en Pro, Team, Enterprise Cloud. Push rulesets: privados/internos en Team+.

Reglas disponibles: restrict creations / updates / deletions, require linear history, require deployments to succeed, require signed commits, **require a pull request** (aprobaciones N, dismiss stale approvals, require review from Code Owners, require approval of the most recent reviewable push, require conversation resolution, allowed merge methods, **required reviewers por rutas** (hasta 15 equipos), aprobación extra para PRs de Copilot sin atribuir — preview, activo por defecto), **require status checks** (strict = rama actualizada; se puede fijar la App fuente), block force pushes, require code scanning results, require code quality results, restrict code coverage (preview), require secret scanning alerts resolved (preview), restrict file paths / path length / extensions / file size (push rules; límite 200 entradas; `fnmatch`).

Conversión: "Convert to ruleset" desde la página de branch protection. API: `POST /repos/{owner}/{repo}/rulesets`, `GET /repos/{owner}/{repo}/rules/branches/{branch}` (reglas efectivas). Con `gh`: `gh ruleset list|view|check <rama>`.

Notas:
- Firmas requeridas: commits sin firma en la rama head pueden bloquear incluso un squash (GitHub firma el squash, pero evalúa el merge de prueba).
- Bloquear force push impide también renombrar/cambiar la rama por defecto sin bypass.
- Copilot cloud agent no puede cumplir algunas reglas (p. ej. autores de commit restringidos): agrega Copilot como bypass en el ruleset.

## 3. CODEOWNERS

Ubicación: `.github/CODEOWNERS`, raíz o `docs/` (se usa el primero encontrado en ese orden). Sintaxis tipo gitignore; **la última coincidencia gana**.
```
*                       @org/plataforma
/.github/workflows/     @org/devops
*.tf                    @org/infra
/docs/                  @usuario docs@empresa.com
/src/generado/          # sin owner = sin revisión requerida
```
Los owners necesitan permiso de escritura. Errores de sintaxis visibles en la vista del archivo en GitHub. Tamaño máx. 3 MB. Combinar con "Require review from Code Owners".

## 4. Pull requests

- Tipos: normal o **draft** (no se puede fusionar ni notifica a code owners hasta "Ready for review").
- Palabras clave para cerrar issues al fusionar en la rama por defecto: `close(s|d)`, `fix(es|ed)`, `resolve(s|d)` + `#123` u `owner/repo#123`.
- Métodos de merge (habilitables por repo): **merge commit**, **squash** (título/mensaje por defecto configurable: `squash_merge_commit_title`), **rebase** (sin merge commit; reescribe SHAs). Historial lineal requiere squash o rebase.
- **Auto-merge**: `gh pr merge --auto --squash`; se fusiona cuando se cumplen los requisitos.
- **Merge queue**: agrupa PRs, crea ramas `gh-readonly-queue/...` y corre los checks sobre el resultado combinado. Los workflows deben escuchar `merge_group`. Configurable: método, tamaño de grupo, timeout de checks, "only merge non-failing PRs".
- "Update branch" (merge o rebase desde la base); sugerencia obligatoria con checks strict.
- Borrado automático de ramas head tras merge (setting del repo). Las ramas se pueden restaurar desde el PR.
- Revisiones: comment / approve / request changes; sugerencias de código (```suggestion), aplicar en lote; revisores requeridos por ruleset; asignación automática a equipos (round robin / load balance).
- Plantillas: `.github/pull_request_template.md` o varias en `.github/PULL_REQUEST_TEMPLATE/` (seleccionables con `?template=nombre.md`).
- PRs apilados (stacked PRs): soporte nativo en la API (`/pulls/stacks`) — verificar estado en la doc.
- Checkout local: `gh pr checkout 123` o `git fetch origin pull/123/head:pr-123`.
- Comparar: `https://github.com/owner/repo/compare/base...head` (tres puntos = desde el ancestro común).

### Status checks
- Dos APIs: *commit statuses* (`/statuses`, contexto por nombre) y *checks* (`check_runs`, solo GitHub Apps). Los jobs de Actions generan check runs con nombre `workflow / job` (el check requerido usa el nombre del job, ojo con matrices: `test (ubuntu-latest, 22)`).
- "Expected — Waiting for status to be reported": el check requerido nunca se reporta (workflow filtrado por paths, nombre de job cambiado, falta `merge_group`).

## 5. Releases y tags

- Release = tag + notas + assets. Notas automáticas configurables con `.github/release.yml` (categorías por label, exclusiones).
- `gh release create v1.2.0 --generate-notes --verify-tag dist/*`
- **Releases inmutables**: impiden modificar assets y mover el tag tras publicar; recomendado para acciones y artefactos firmados.
- Último release: `https://github.com/owner/repo/releases/latest`; asset directo: `/releases/latest/download/<archivo>`.
- Tags protegidos: usa rulesets de tags (los "protected tags" clásicos fueron reemplazados).

## 6. Forks

- Política de forks de repos privados configurable por org/repo. Los forks de privados se borran si se quita el acceso.
- Sincronizar: botón "Sync fork", `gh repo sync owner/fork`, o `git fetch upstream && git merge upstream/main`.
- Desvincular un fork (detach): vía soporte o al cambiar visibilidad del padre.

## 7. Git básico relacionado (recordatorios)

- Rama por defecto para nuevos repos: setting de usuario/org (`main`). Renombrar la rama por defecto redirige PRs y reglas; los clones locales deben `git branch -m master main && git fetch origin && git branch -u origin/main main && git remote set-head origin -a`.
- Firmar commits: `git config commit.gpgsign true` (+ `gpg.format ssh` y `user.signingkey ~/.ssh/id_ed25519.pub` para SSH).
- Commits web y de squash/rebase hechos por GitHub se firman con la clave de GitHub ("Verified").
- Co-autoría: trailer `Co-authored-by: Nombre <email>`.
- Email privado: `ID+usuario@users.noreply.github.com`; "Block command line pushes that expose my email".
