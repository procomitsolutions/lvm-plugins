# Mapa de la documentación oficial

Base: `https://docs.github.com/es` (cambia `/es` por `/en` para el original en inglés; la versión en español puede ser traducción automática, ante dudas consulta la inglesa). Versiones: GitHub.com por defecto; `.../enterprise-cloud@latest/...` y `.../enterprise-server@3.X/...` para Enterprise. Cada artículo tiene "Copiar Markdown".

## Actions
- Índice: https://docs.github.com/es/actions
- Sintaxis: https://docs.github.com/es/actions/reference/workflows-and-actions/workflow-syntax
- Eventos: https://docs.github.com/es/actions/reference/workflows-and-actions/events-that-trigger-workflows
- Contextos: https://docs.github.com/es/actions/reference/workflows-and-actions/contexts
- Expresiones: https://docs.github.com/es/actions/reference/workflows-and-actions/expressions
- Variables: https://docs.github.com/es/actions/reference/workflows-and-actions/variables
- Comandos de workflow: https://docs.github.com/es/actions/reference/workflows-and-actions/workflow-commands
- Metadatos de acciones: https://docs.github.com/es/actions/reference/workflows-and-actions/metadata-syntax
- Reutilización: https://docs.github.com/es/actions/reference/workflows-and-actions/reusing-workflow-configurations
- Cache: https://docs.github.com/es/actions/reference/workflows-and-actions/dependency-caching
- Environments: https://docs.github.com/es/actions/reference/workflows-and-actions/deployments-and-environments
- Concurrency: https://docs.github.com/es/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency
- Runners hospedados: https://docs.github.com/es/actions/reference/runners/github-hosted-runners
- Larger runners: https://docs.github.com/es/actions/reference/runners/larger-runners
- Self-hosted: https://docs.github.com/es/actions/reference/runners/self-hosted-runners
- ARC: https://docs.github.com/es/actions/concepts/runners/actions-runner-controller
- Límites: https://docs.github.com/es/actions/reference/limits
- Uso seguro: https://docs.github.com/es/actions/reference/security/secure-use
- pull_request_target: https://docs.github.com/es/actions/reference/security/securely-using-pull_request_target
- OIDC: https://docs.github.com/es/actions/reference/security/oidc
- OIDC AWS/Azure/GCP: https://docs.github.com/es/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws (cambia `aws` por `azure`, `google-cloud-platform`, `hashicorp-vault`, `pypi`)
- Atestaciones: https://docs.github.com/es/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations
- GITHUB_TOKEN: https://docs.github.com/es/actions/tutorials/authenticate-with-github_token
- Troubleshooting: https://docs.github.com/es/actions/how-tos/troubleshoot-workflows
- Migrar a Actions: https://docs.github.com/es/actions/tutorials/migrate-to-github-actions/automated-migrations/use-github-actions-importer
- Imágenes de runners (SO y software): https://github.com/actions/runner-images

## Facturación
- Actions: https://docs.github.com/es/billing/concepts/product-billing/github-actions
- Precios de runners: https://docs.github.com/es/billing/reference/actions-runner-pricing
- GHAS: https://docs.github.com/es/billing/concepts/product-billing/github-advanced-security
- Copilot: https://docs.github.com/es/billing/concepts/product-billing/github-copilot-billing
- Packages / Codespaces / LFS: https://docs.github.com/es/billing/concepts/product-billing/github-packages (cambia por `github-codespaces`, `git-lfs`)
- Presupuestos: https://docs.github.com/es/billing/concepts/budgets-and-alerts
- Precios públicos: https://github.com/pricing

## Repositorios y PRs
- Índice: https://docs.github.com/es/repositories
- Rulesets (reglas): https://docs.github.com/es/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets
- Branch protection: https://docs.github.com/es/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches
- CODEOWNERS: https://docs.github.com/es/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners
- Merge queue: https://docs.github.com/es/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue
- Límites: https://docs.github.com/es/repositories/creating-and-managing-repositories/repository-limits
- Archivos grandes / LFS: https://docs.github.com/es/repositories/working-with-files/managing-large-files/about-large-files-on-github
- Releases: https://docs.github.com/es/repositories/releasing-projects-on-github/about-releases
- Pull requests: https://docs.github.com/es/pull-requests

## Autenticación
- Índice: https://docs.github.com/es/authentication
- PAT: https://docs.github.com/es/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens
- SSH: https://docs.github.com/es/authentication/connecting-to-github-with-ssh
- Firma de commits: https://docs.github.com/es/authentication/managing-commit-signature-verification
- Datos sensibles: https://docs.github.com/es/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository
- Huellas SSH: https://docs.github.com/es/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints

## API, Apps, webhooks
- REST: https://docs.github.com/es/rest
- Versiones / cambios disruptivos: https://docs.github.com/es/rest/about-the-rest-api/breaking-changes
- Rate limits: https://docs.github.com/es/rest/using-the-rest-api/rate-limits-for-the-rest-api
- Permisos fine-grained por endpoint: https://docs.github.com/es/rest/authentication/permissions-required-for-fine-grained-personal-access-tokens
- GraphQL: https://docs.github.com/es/graphql
- Apps: https://docs.github.com/es/apps
- Webhooks: https://docs.github.com/es/webhooks

## Seguridad del código
- Índice: https://docs.github.com/es/code-security
- Secretos: https://docs.github.com/es/code-security/how-tos/secure-your-secrets
- Vulnerabilidades (code scanning): https://docs.github.com/es/code-security/how-tos/find-and-fix-code-vulnerabilities
- Cadena de suministro (Dependabot): https://docs.github.com/es/code-security/how-tos/secure-your-supply-chain
- A escala: https://docs.github.com/es/code-security/how-tos/secure-at-scale
- CodeQL (escritura de queries): https://codeql.github.com/docs
- Advisory Database: https://github.com/advisories

## Copilot
- Índice: https://docs.github.com/es/copilot
- Planes: https://docs.github.com/es/copilot/get-started/plans
- Cloud agent: https://docs.github.com/es/copilot/concepts/agents/cloud-agent/about-cloud-agent
- Personalización (cheat sheet): https://docs.github.com/es/copilot/reference/customization-cheat-sheet
- Custom agents: https://docs.github.com/es/copilot/reference/custom-agents-configuration
- Hooks: https://docs.github.com/es/copilot/reference/hooks-reference
- Modelos: https://docs.github.com/es/copilot/reference/ai-models/supported-models
- Matriz de features: https://docs.github.com/es/copilot/reference/copilot-feature-matrix
- Copilot CLI: https://docs.github.com/es/copilot/how-tos/copilot-cli

## Otros productos
- GitHub CLI: https://docs.github.com/es/github-cli y manual https://cli.github.com/manual
- Pages: https://docs.github.com/es/pages
- Packages: https://docs.github.com/es/packages
- Codespaces: https://docs.github.com/es/codespaces
- Issues / Projects: https://docs.github.com/es/issues
- Discussions: https://docs.github.com/es/discussions
- Organizaciones: https://docs.github.com/es/organizations
- Enterprise: https://docs.github.com/es/enterprise-cloud@latest/admin
- Migraciones: https://docs.github.com/es/migrations
- Búsqueda: https://docs.github.com/es/search-github
- Desktop: https://docs.github.com/es/desktop
- Sponsors / Education: https://docs.github.com/es/sponsors , https://docs.github.com/es/education
- Well-Architected: https://wellarchitected.github.com/
- Changelog: https://github.blog/changelog/ — Estado: https://www.githubstatus.com/ — Comunidad: https://github.com/orgs/community/discussions
