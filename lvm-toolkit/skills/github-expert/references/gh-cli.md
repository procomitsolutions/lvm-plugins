# GitHub CLI (`gh`) — chuleta

Instalación: `brew install gh`, `winget install GitHub.cli`, paquetes oficiales apt/dnf (repo `cli.github.com/packages`). En runners hospedados ya viene instalado (en Actions usa `GH_TOKEN: ${{ github.token }}`).

## Autenticación y config
```bash
gh auth login                       # interactivo (HTTPS o SSH, navegador o token)
gh auth login --hostname ghe.empresa.com
echo "$TOKEN" | gh auth login --with-token
gh auth status                      # cuentas, scopes, host
gh auth refresh -s workflow,read:project   # añadir scopes
gh auth switch                      # cambiar entre cuentas
gh auth setup-git                   # usar gh como credential helper de git
gh auth token                       # imprime el token activo
gh config set git_protocol ssh
gh config set editor "code --wait"
```
Variables: `GH_TOKEN`/`GITHUB_TOKEN`, `GH_HOST`, `GH_REPO` (owner/repo), `GH_ENTERPRISE_TOKEN`, `GH_DEBUG=api`, `NO_COLOR`, `GH_PROMPT_DISABLED=1`.

## Repos
```bash
gh repo create mi-org/app --private --clone --add-readme --license mit --gitignore Node
gh repo create --source=. --public --push        # publicar un repo local existente
gh repo clone owner/repo -- --depth 1
gh repo fork owner/repo --clone --remote
gh repo sync owner/mi-fork                        # sincronizar fork con upstream
gh repo view owner/repo --web
gh repo edit --default-branch main --enable-auto-merge --delete-branch-on-merge --visibility private --accept-visibility-change-consequences
gh repo set-default owner/repo                    # repo por defecto en el directorio
gh repo list mi-org --limit 500 --json name,visibility,isArchived
gh repo archive owner/repo ; gh repo delete owner/repo --yes   # ⚠ irreversible
gh repo rename nuevo-nombre
gh repo deploy-key add key.pub --allow-write
```

## Pull requests
```bash
gh pr create --fill --base main --draft --reviewer org/equipo --label bug --assignee @me
gh pr create --title "feat: x" --body-file cuerpo.md
gh pr list --state open --author @me --search "review:required"
gh pr view 123 --comments ; gh pr diff 123 --name-only
gh pr checkout 123
gh pr checks 123 --watch --fail-fast
gh pr review 123 --approve | --request-changes -b "..." | --comment -b "..."
gh pr merge 123 --squash --delete-branch          # --merge | --rebase
gh pr merge 123 --auto --squash                   # auto-merge al pasar checks
gh pr merge 123 --admin                           # saltar requisitos (si tienes bypass) ⚠
gh pr ready 123 ; gh pr ready 123 --undo
gh pr edit 123 --add-label x --add-reviewer @copilot   # pedir code review a Copilot (verificar)
gh pr update-branch 123 --rebase
gh pr close 123 --delete-branch ; gh pr reopen 123
```

## Issues y proyectos
```bash
gh issue create -t "Bug" -b "..." -l bug -a @me --project "Roadmap"
gh issue list -l bug -s all --json number,title,state --jq '.[] | "\(.number)\t\(.title)"'
gh issue view 42 --web ; gh issue close 42 -r "not planned"
gh issue develop 42 --checkout          # crea rama vinculada al issue
gh issue transfer 42 owner/otro-repo
gh label create "prioridad:alta" -c FF0000
gh project list --owner mi-org ; gh project item-add 5 --owner mi-org --url <issue-url>
```

## Actions
```bash
gh workflow list ; gh workflow view ci.yml
gh workflow run deploy.yml --ref main -f env=prod -f dry_run=true
gh workflow enable|disable ci.yml
gh run list --workflow ci.yml --branch main --status failure -L 20
gh run watch <run-id> --exit-status
gh run view <run-id> --log-failed            # solo logs de los steps fallidos
gh run view <run-id> --job <job-id> --log
gh run rerun <run-id> --failed [--debug]
gh run cancel <run-id> ; gh run delete <run-id>
gh run download <run-id> -n nombre-artefacto -D ./out
gh cache list ; gh cache delete --all
gh secret set NAME < archivo ; gh secret set NAME --env production ; gh secret set NAME --org mi-org --repos "a,b"
gh secret list ; gh variable set NAME --body valor ; gh variable list
gh secret set NAME --app dependabot          # secretos de Dependabot / codespaces
```

## Releases y atestaciones
```bash
gh release create v1.2.0 dist/* --generate-notes --verify-tag [--draft|--prerelease] [--latest]
gh release upload v1.2.0 extra.zip --clobber
gh release download v1.2.0 -p "*.tar.gz"
gh release list ; gh release delete v1.2.0 --cleanup-tag ⚠
gh attestation verify archivo.tgz -R owner/repo
gh attestation verify oci://ghcr.io/owner/img:tag -o owner
```

## API
```bash
gh api user --jq .login
gh api repos/{owner}/{repo}/branches --paginate --jq '.[].name'     # {owner}/{repo} se rellenan del repo actual
gh api -X PATCH repos/{owner}/{repo} -f description="nueva" -F has_wiki=false   # -F tipa números/bools/@archivo
gh api repos/{owner}/{repo}/rulesets --input ruleset.json -X POST
gh api -H "X-GitHub-Api-Version: 2026-03-10" repos/{owner}/{repo}
gh api graphql -f query='query{viewer{login}}'
gh api --cache 1h orgs/mi-org/members --paginate --slurp
```
`-f` string, `-F` tipado/`@archivo`, `--input` cuerpo JSON, `-i` incluye headers, `--jq`/`--template` para formatear.

## Otros
```bash
gh search repos "topic:terraform stars:>1000" --limit 20
gh search code "TODO repo:owner/repo" ; gh search prs --review-requested=@me --state=open
gh ruleset list ; gh ruleset check main         # reglas efectivas
gh codespace create -r owner/repo -m standardLinux32gb ; gh codespace ssh ; gh codespace stop
gh gist create archivo.txt --public
gh ssh-key add ~/.ssh/id_ed25519.pub --type signing
gh browse src/app.ts:42
gh status                                         # notificaciones, PRs y issues relevantes
gh alias set prs 'pr list --author @me'
gh extension install github/gh-copilot ; gh extension list ; gh extension upgrade --all
gh copilot                                        # integración con Copilot CLI (verificar subcomandos vigentes)
gh agent-task create "..."                        # tareas para Copilot cloud agent (verificar)
```

## Scripting robusto
- Usa `--json campos --jq expr` en lugar de parsear texto: `gh pr list --json number,headRefName,statusCheckRollup`.
- Para ver campos disponibles: `gh pr view --json` (sin campos) los lista.
- Códigos de salida: 0 ok, 1 error, 2 cancelado, 4 auth requerida; `gh pr checks` sale ≠0 si hay checks fallidos/pending.
- En CI: `GH_TOKEN` en `env:` del step, nunca en la línea de comandos.
