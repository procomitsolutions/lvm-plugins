# Seguridad del código (GHAS, Dependabot, CodeQL, secret scanning)

## 1. Productos y licencias

| Producto | Incluye | Repos públicos | Privados/internos |
|---|---|---|---|
| (gratis para todos) | Dependency graph, Dependabot alerts, Dependabot security/version updates, security advisories del repo, private vulnerability reporting | ✓ | ✓ |
| **GitHub Secret Protection** | Secret scanning (patrones de partners, genéricos, IA/Copilot, custom patterns), **push protection**, bypass delegado, validez de secretos | Secret scanning y push protection gratis | Licencia |
| **GitHub Code Security** | Code scanning (CodeQL y terceros vía SARIF), **Copilot Autofix**, dependency review (bloqueo en PR), reglas Dependabot premium, security campaigns | Code scanning gratis | Licencia |
| GitHub Code Quality | Hallazgos de calidad/mantenibilidad, cobertura, umbrales en PRs | — | Producto aparte (verificar) |

Licenciamiento: Team o Enterprise; se cobra por **committer activo único** (alguien que hizo push a un repo con el producto habilitado en los últimos 90 días). Facturación medida (Enterprise Cloud, mensual) o por volumen/suscripción. Presupuestos de SKU bloquean nuevas habilitaciones, no apagan lo existente. Gratis para orgs: Secret risk assessment y Code security risk assessment.

**Security configurations** (org/empresa): plantillas que habilitan features en lote; la "GitHub-recommended" es un buen punto de partida. Overview de seguridad en la pestaña Security de la org.

## 2. Secret scanning y push protection

- Detecta en todo el historial git, issues, PRs, discussions, wikis. Patrones de partners (se notifica al proveedor y muchos revocan automáticamente en repos públicos), patrones genéricos/no-provider, detección con IA (contraseñas), **custom patterns** (regex; repo/org/empresa; Copilot puede generarlas).
- **Push protection**: bloquea el `git push` (y subidas web/API) que contiene un secreto soportado. Mensaje `GH013: Repository rule violations found` / "Push cannot contain secrets". Opciones:
  1. Quitar el secreto del commit (si es el último: editar y `git commit --amend`; si es anterior: `git rebase -i`) y volver a pushear. **Rotarlo igualmente** si ya salió de tu máquina.
  2. Bypass con motivo (falso positivo / usado en tests / lo arreglaré después) mediante la URL del mensaje; con **delegated bypass** la petición va a revisores.
- Push protection para usuarios (cuenta personal) activo por defecto en repos públicos.
- Ruleset "Require secret scanning alerts to be resolved" (preview) bloquea merges de PRs que introducen secretos.
- Alertas: `gh api repos/{o}/{r}/secret-scanning/alerts`. Cerrar como revoked / false positive / used in tests / won't fix.
- Excluir rutas: `.github/secret_scanning.yml` con `paths-ignore:`.

### Remediar un secreto ya commiteado
1. **Revocar/rotar el secreto** (lo único que realmente lo neutraliza).
2. Reescribir historial si hace falta: `git filter-repo --replace-text expresiones.txt` (o `--path archivo --invert-paths`), luego `git push --force --all && git push --force --tags`.
3. Avisar a colaboradores para que re-clonen; contactar a Soporte para purgar vistas en caché y refs de PRs.
4. Ver guía oficial "Eliminación de datos confidenciales de un repositorio".

## 3. Code scanning (CodeQL)

- **Default setup** (recomendado para empezar): Settings → Code security → Code scanning → Default. Lenguajes CodeQL: C/C++, C#, Go, Java/Kotlin, JavaScript/TypeScript, Python, Ruby, Swift, Rust y **GitHub Actions** (workflows). Corre en push a la rama por defecto/protegidas, PRs y semanalmente. Habilitable a escala por org.
- **Advanced setup**: workflow propio con `github/codeql-action/init|autobuild|analyze` (permisos `security-events: write`, `contents: read`, `actions: read`), para builds manuales, query suites (`security-extended`, `security-and-quality`), packs propios, config en `.github/codeql/codeql-config.yml` (`paths`, `paths-ignore`, `queries`).
  ```yaml
  - uses: github/codeql-action/init@v4      # verifica la major vigente
    with:
      languages: java-kotlin
      build-mode: manual          # none | autobuild | manual
      queries: security-extended
  ```
- `build-mode: none` disponible para lenguajes compilados como C#, Java y C/C++ (sin compilar); Go/Rust/Swift según lenguaje — verificar tabla.
- Herramientas de terceros: subir SARIF con `github/codeql-action/upload-sarif` (`category` distinta por herramienta). Límite de SARIF ~10 MB comprimido y número de resultados por ejecución.
- **Copilot Autofix**: propone parches en alertas y PRs (incluido con Code Security; también en repos públicos).
- Merge protection: ruleset "Require code scanning results" (por herramienta y severidad).
- CodeQL CLI para análisis local / otros CI: `codeql database create`, `codeql database analyze ... --format=sarif-latest`.
- Variant analysis multi-repo (MRVA) desde la extensión de VS Code.

## 4. Dependabot

- **Alerts**: con dependency graph + GitHub Advisory Database. Reglas automáticas (auto-triage presets, reglas custom para descartar/posponer). No alerta acciones fijadas por SHA.
- **Security updates**: PR automático a la versión mínima corregida.
- **Version updates**: `.github/dependabot.yml`:
```yaml
version: 2
updates:
  - package-ecosystem: "npm"            # npm, pip, uv, maven, gradle, nuget, bundler, composer, cargo, gomod, docker, docker-compose, github-actions, terraform, helm, pub, mix, swift, gitsubmodule, devcontainers, bun...
    directories: ["/", "/packages/*"]   # o directory: "/"
    schedule:
      interval: "weekly"                # daily, weekly, monthly, quarterly, semiannually, yearly, cron
      day: "monday"
      time: "06:00"
      timezone: "America/Argentina/Buenos_Aires"
    cooldown:
      default-days: 5                   # no proponer versiones con menos de N días
    groups:
      dev-deps:
        dependency-type: "development"
        update-types: ["minor", "patch"]
    ignore:
      - dependency-name: "react"
        update-types: ["version-update:semver-major"]
    open-pull-requests-limit: 10
    labels: ["dependencies"]
    commit-message:
      prefix: "chore(deps)"
```
  Otras claves: `target-branch`, `versioning-strategy`, `registries` (privados con secretos de Dependabot), `allow`, `assignees`, `reviewers` (preferir CODEOWNERS), `rebase-strategy`, `vendor`, `insecure-external-code-execution`, `multi-ecosystem-groups`, `exclude-paths`.
- Los jobs de Dependabot corren en Actions (gratis) y usan **secretos de Dependabot** (almacén separado). Los workflows disparados por PRs de Dependabot reciben token de solo lectura y sin secretos de Actions → usa secretos de Dependabot o `pull_request_target` con cuidado.
- Auto-merge de patches: `dependabot/fetch-metadata` + `gh pr merge --auto --squash` filtrando por `update-type`.
- Comandos en comentarios: `@dependabot rebase`, `recreate`, `ignore this major version`, etc.
- Ejecución: Insights → Dependency graph → Dependabot (logs de cada job).

## 5. Dependency graph, review y SBOM
- Graph: desde manifiestos/lockfiles; envío desde build con **dependency submission API** (acciones para Maven, Gradle, etc.). Workflows de Actions cuentan como manifiestos.
- **Dependency review action** (`actions/dependency-review-action`): falla el PR si introduce dependencias vulnerables o licencias prohibidas (`fail-on-severity`, `deny-licenses`/`allow-licenses`).
- SBOM: exportar SPDX desde la UI o `GET /repos/{o}/{r}/dependency-graph/sbom`.

## 6. Avisos y reportes
- `SECURITY.md` con política; **private vulnerability reporting** (los investigadores reportan en privado).
- Repository security advisories: borrador privado, fork temporal privado para el fix, solicitar CVE (GitHub es CNA), publicar.
- GitHub Advisory Database (`github.com/advisories`): avisos revisados y no revisados; contribuciones vía PR a `github/advisory-database`.

## 7. Security campaigns y escalado
- Campañas para remediar lotes de alertas (code scanning / secret scanning) con fecha límite; se pueden asignar alertas a Copilot cloud agent.
- Security managers (rol de org): lectura de alertas en todos los repos.
- Custom properties + configurations para aplicar políticas por tipo de repo.
