# Plataforma: Pages, Packages, Codespaces, Issues/Projects, orgs, planes y migraciones

## 1. GitHub Pages
- Tipos: sitio de usuario/org (`USUARIO.github.io`) y de proyecto (`USUARIO.github.io/repo`). Repos públicos en Free; privados con Pro/Team/Enterprise (en Enterprise Cloud, visibilidad privada del sitio con control de acceso).
- Fuentes de publicación: **GitHub Actions** (recomendado) o rama (`main` / `gh-pages`, carpeta `/` o `/docs`, con Jekyll por defecto; `.nojekyll` para desactivarlo).
- Workflow mínimo: `actions/configure-pages` → build → `actions/upload-pages-artifact` → job `deploy` con `environment: github-pages`, `permissions: pages: write, id-token: write`, `actions/deploy-pages`.
- Límites (verificar): sitio publicado ≤ 1 GB, ancho de banda blando 100 GB/mes, 10 builds/hora para builds por rama, despliegue con timeout de 10 min. No es para e-commerce ni SaaS.
- Dominio personalizado: archivo `CNAME` (en publicación por rama) o setting; DNS: apex con registros `A` a 185.199.108.153, .109, .110, .111 (y `AAAA` 2606:50c0:8000::153 …8003::153) o `ALIAS/ANAME`; subdominio con `CNAME` a `USUARIO.github.io`. **Verifica el dominio** en la cuenta/org para evitar takeover. "Enforce HTTPS" tras emitir el certificado (puede tardar hasta 24 h).
- 404: `404.html`. SPA: copiar `index.html` como `404.html`.

## 2. GitHub Packages / GHCR
- Registros: Container (`ghcr.io`), npm (`npm.pkg.github.com`), Maven, Gradle, NuGet, RubyGems. Docker registry antiguo (`docker.pkg.github.com`) migrado a GHCR.
- Login: `echo $TOKEN | docker login ghcr.io -u USUARIO --password-stdin`. En Actions: `docker/login-action` con `username: ${{ github.actor }}`, `password: ${{ secrets.GITHUB_TOKEN }}` y `permissions: packages: write`.
- Imagen: `ghcr.io/OWNER/IMAGEN:tag` (owner en minúsculas). Vincular al repo con label OCI `org.opencontainers.image.source=https://github.com/OWNER/REPO` (hereda permisos y aparece en el repo).
- Permisos: paquetes de org pueden tener permisos granulares independientes del repo ("Manage Actions access" para que otro repo publique). Visibilidad por paquete (pública/privada/interna).
- Tokens: fuera de Actions, PAT **classic** (`read:packages`, `write:packages`, `delete:packages`); fine-grained aún no soporta Packages.
- Facturación: públicos gratis; privados comparten cuota de almacenamiento con artefactos de Actions (0,25 USD/GB-mes extra); transferencia gratis desde Actions. Borrar versiones: UI, API o `actions/delete-package-versions`.
- npm: `.npmrc` con `@scope:registry=https://npm.pkg.github.com` y `//npm.pkg.github.com/:_authToken=${NODE_AUTH_TOKEN}`; el scope debe coincidir con el owner.

## 3. Codespaces
- Entornos de desarrollo en la nube (VM con contenedor), configurados con `.devcontainer/devcontainer.json` (imagen, features, extensiones, `postCreateCommand`, `forwardPorts`, `hostRequirements`). Varias configs en `.devcontainer/<nombre>/devcontainer.json`.
- Máquinas de 2 a 32 núcleos (GPU según disponibilidad). Timeout de inactividad (default 30 min, máx 240) y retención de codespaces detenidos (hasta 30 días).
- **Prebuilds** (vía Actions) para arranques rápidos; consumen almacenamiento.
- Cuota personal gratuita mensual (Free y Pro tienen horas-núcleo y GB de almacenamiento incluidos; del orden de 120/180 horas-núcleo y 15/20 GB — verificar). Para orgs se factura a la org si lo habilita; presupuestos y políticas (tipos de máquina, timeout, regiones).
- Secretos de Codespaces (usuario/repo/org) separados de Actions. `GITHUB_TOKEN` del codespace limitado al repo; permisos extra se declaran en `customizations.codespaces.repositories`.
- CLI: `gh codespace create|list|ssh|code|ports|stop|delete`.

## 4. Issues, Projects y Discussions
- Issues: plantillas y **issue forms** en `.github/ISSUE_TEMPLATE/*.yml` (+ `config.yml` para `blank_issues_enabled` y `contact_links`), **sub-issues** (jerarquía), **dependencias** (blocked by / blocking), **issue types** a nivel org (Bug, Feature, Task…), **issue fields** (campos personalizados de org — verificar estado), labels, milestones, asignación a Copilot.
- Búsqueda avanzada: `is:issue state:open label:bug -label:wontfix assignee:@me type:Bug parent-issue:org/repo#1`, con `AND`/`OR` y paréntesis.
- **Projects** (v2): tablas, boards, roadmaps; campos personalizados (single select, iteración, número, fecha, texto); workflows integrados (auto-add, auto-archive, set status); vistas con filtros/agrupación; insights; API GraphQL/REST. Pueden abarcar varios repos de la org.
- Discussions: categorías (incl. Q&A con respuesta marcada, Polls, Announcements), formularios de categoría en `.github/DISCUSSION_TEMPLATE/`, convertir issue ↔ discusión.
- Moderación: interaction limits, bloquear usuarios, reportar contenido, bloquear conversaciones.

## 5. Organizaciones y Enterprise
- Org: miembros, equipos (anidados, sincronizados con IdP en Enterprise), roles de org/repo personalizados, base permissions, políticas (creación de repos, forks, visibilidad, Actions, PAT, apps), audit log (stream a SIEM en Enterprise), custom properties de repos, rulesets de org, security configurations.
- Enterprise Cloud: cuenta empresa que agrupa orgs; SAML SSO u OIDC; **EMU** (Enterprise Managed Users, cuentas controladas por el IdP vía SCIM); **GHE.com** (residencia de datos en UE, Australia, EE. UU., Japón — verificar regiones); políticas centralizadas; IP allow list; centros de costo; enterprise teams.
- Enterprise Server (GHES): autohospedado, versiones con soporte ~1 año; features llegan después; GitHub Connect para sincronizar Actions, Dependabot y licencias.

## 6. Planes (verificar precios en github.com/pricing)
| Plan | Para | Puntos clave |
|---|---|---|
| Free (personal) | individuos | repos ilimitados, 2.000 min Actions, 500 MB Packages, protección de ramas/rulesets solo en públicos |
| Pro | individuos | 3.000 min, 1 GB, rulesets/protección/code owners en privados, Pages en privados |
| Free para organizaciones | equipos pequeños | igual que Free personal en features |
| Team | orgs | 3.000 min, 2 GB, revisores requeridos en privados, draft PRs, rulesets de push, larger runners, soporte web |
| Enterprise (Cloud/Server) | empresas | 50.000 min, 50 GB, SAML/EMU, audit log streaming, GHAS comprable, environments avanzados, 99,9 % SLA |
Precios de referencia históricos: Pro ~4 USD/mes, Team ~4 USD/usuario/mes, Enterprise ~21 USD/usuario/mes. Descuentos: Education (Student Developer Pack, Copilot Student), nonprofits, OSS.

Facturación: ciclos mensuales/anuales, **presupuestos y alertas** por producto/SKU (hard stop opcional), centros de costo (Enterprise), pago con Azure subscription, informes de uso (UI y API `/billing/usage`). Productos medidos: Actions, Packages, Codespaces, Git LFS, GHAS, Copilot (asientos y AI credits), Code Quality.

## 7. Migraciones
- **GitHub Enterprise Importer (GEI)**: migra repos con historial, PRs, issues, etc. desde GitHub (GHES/GHEC), Azure DevOps, Bitbucket Server/Data Center, GitLab (verificar soporte vigente). Extensiones `gh gei`, `gh ado2gh`, `gh bbs2gh`. Migraciones de org completas entre productos GitHub. Planifica: pruebas, reclamar mannequins (mapear usuarios), freeze de escritura.
- **Importador web** (repos git simples con historial; no issues): "Import repository" / `github.com/new/import`. Para mover solo git: `git clone --mirror` + `git push --mirror`.
- **GitHub Actions Importer** (`gh actions-importer`): audit, forecast, dry-run y migrate desde Azure DevOps, Bamboo, Bitbucket Pipelines, CircleCI, GitLab, Jenkins, Travis CI. Traduce lo que puede; revisa manualmente. Equivalencias manuales en "Migrar desde X".

### Equivalencias rápidas para migrar CI
| Concepto | GitLab CI | Jenkins | Azure Pipelines | Actions |
|---|---|---|---|---|
| Archivo | `.gitlab-ci.yml` | `Jenkinsfile` | `azure-pipelines.yml` | `.github/workflows/*.yml` |
| Etapas | `stages` | `stage` | `stages` | jobs + `needs` |
| Agente | `tags` | `agent { label }` | `pool` | `runs-on` |
| Variables secretas | CI/CD variables (masked) | credentials | variable groups / Key Vault | secrets / vars / environments |
| Condición | `rules:` | `when` | `condition:` | `if:` |
| Reutilización | `include`, `extends` | shared libraries | templates | reusable workflows / composite actions |
| Artefactos | `artifacts` | `archiveArtifacts` | `PublishPipelineArtifact` | upload/download-artifact |
| Manual | `when: manual` | `input` | approvals | environment con revisores / `workflow_dispatch` |
