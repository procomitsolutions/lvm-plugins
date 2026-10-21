# GitHub Actions — Workflows y acciones

## Índice
1. Anatomía de un workflow
2. Triggers (`on:`)
3. Jobs: dependencias, condiciones, outputs, matrix
4. Concurrency
5. Contextos, expresiones y variables
6. Comandos de workflow (GITHUB_OUTPUT, ENV, PATH, STEP_SUMMARY)
7. Reutilización: reusable workflows vs composite/JS/Docker actions
8. Cache y artefactos
9. Environments y despliegues
10. Contenedores y servicios
11. Errores de sintaxis frecuentes

## 1. Anatomía

Archivos en `.github/workflows/*.yml|yaml`, ≤ 500 KB cada uno (si no, no arranca).

```yaml
name: CI
run-name: CI ${{ github.ref_name }} por @${{ github.actor }}   # título de la ejecución

on:
  push:
    branches: [main]
    paths-ignore: ['docs/**', '**.md']
  pull_request:
  workflow_dispatch:

permissions:
  contents: read            # mínimo; ampliar por job

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

env:
  NODE_VERSION: '22'

defaults:
  run:
    shell: bash
    working-directory: ./app

jobs:
  test:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-node@v4          # verifica la major vigente
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: npm
      - run: npm ci
      - run: npm test
```

Claves de nivel superior: `name`, `run-name`, `on`, `permissions`, `env`, `defaults`, `concurrency`, `jobs`.
Claves de job: `name`, `needs`, `if`, `runs-on`, `environment`, `permissions`, `concurrency`, `outputs`, `env`, `defaults`, `timeout-minutes`, `strategy`, `continue-on-error`, `container`, `services`, `steps`; para llamar un reusable: `uses`, `with`, `secrets`.
Claves de step: `id`, `name`, `if`, `uses`, `run`, `shell`, `with`, `env`, `working-directory`, `continue-on-error`, `timeout-minutes`.

## 2. Triggers

| Evento | Uso típico / notas |
|---|---|
| `push` | `branches`, `branches-ignore`, `tags`, `tags-ignore`, `paths`, `paths-ignore` (no mezclar `branches` y `branches-ignore` en el mismo evento). |
| `pull_request` | Default `types: [opened, synchronize, reopened]`. Corre sobre el *merge commit* de prueba (`refs/pull/N/merge`). Desde forks: token de solo lectura y **sin secretos**. PRs de forks de colaboradores nuevos pueden requerir aprobación según la política del repo. |
| `pull_request_target` | Contexto de la rama base **con secretos y token de escritura**. Solo para tareas que no ejecutan código del PR (etiquetar, comentar). Ver `actions-seguridad.md`. |
| `workflow_dispatch` | Manual (UI, `gh workflow run`, API). `inputs` tipos: `string`, `boolean`, `choice` (`options:`), `number`, `environment`. El archivo debe existir en la rama por defecto para aparecer en la UI. En la API `2026-03-10` el dispatch responde `200` con los detalles del run. |
| `schedule` | `cron` en UTC; intervalo mínimo 5 min; puede retrasarse en horas pico; usa la última commit de la rama por defecto. En repos públicos se deshabilita tras 60 días sin actividad. |
| `workflow_call` | Convierte el workflow en reutilizable (inputs, secrets, outputs). |
| `workflow_run` | Encadenar: `workflows: [CI]`, `types: [completed]`. Privilegiado como `pull_request_target`: trata artefactos del run previo como no confiables. |
| `repository_dispatch` | Disparo externo vía API (`event_type`, `client_payload`). |
| `merge_group` | Imprescindible si usas merge queue con checks requeridos. |
| `release`, `issues`, `issue_comment`, `pull_request_review`, `discussion`, `deployment`, `registry_package`, `check_run`, `create`, `delete`, `label`, `watch`… | Ver "Eventos que desencadenan flujos de trabajo". |

Reglas importantes:
- **Eventos causados por el `GITHUB_TOKEN` no disparan nuevos workflows** (excepto `workflow_dispatch` y `repository_dispatch`). Para encadenar push→workflow usa token de GitHub App o PAT.
- Saltar CI: `[skip ci]`, `[ci skip]`, `[no ci]`, `[skip actions]`, `[actions skip]` en el mensaje del commit (solo `push`/`pull_request`). Un check requerido que no corre deja el PR bloqueado en "Expected".
- `paths`/`branches` en un workflow cuyo check es **requerido** → si no corre, el check queda pendiente para siempre. Solución: que el workflow siempre corra y filtrar dentro (job "gate" que decide), o no hacer requerido ese check.

## 3. Jobs

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.ver.outputs.version }}
    steps:
      - id: ver
        run: echo "version=1.2.3" >> "$GITHUB_OUTPUT"

  deploy:
    needs: build
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - run: echo "Desplegando ${{ needs.build.outputs.version }}"
```

- `if:` en job/step: `${{ }}` opcional, salvo que la expresión empiece con `!` (usa `${{ !cond }}`).
- Funciones de estado: `success()` (implícita), `always()`, `failure()`, `cancelled()`. Prefiere `!cancelled()` sobre `always()` para que cancelar funcione.
- Jobs con `needs` se saltan si un antecesor falla, salvo `if: ${{ !cancelled() }}`. `needs.<job>.result` ∈ `success|failure|cancelled|skipped`.

### Matrix
```yaml
strategy:
  fail-fast: false
  max-parallel: 4
  matrix:
    os: [ubuntu-latest, windows-latest, macos-latest]
    node: [20, 22, 24]
    include:
      - os: ubuntu-latest
        node: 24
        coverage: true
    exclude:
      - os: windows-latest
        node: 20
runs-on: ${{ matrix.os }}
```
- Máximo **256 jobs** por run.
- Matriz dinámica: un job publica JSON en un output y otro usa `matrix: ${{ fromJSON(needs.setup.outputs.matrix) }}`.

## 4. Concurrency

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.head_ref || github.run_id }}
  cancel-in-progress: true
```
- Default (`queue: single`): a lo sumo una ejecución en curso y **una pendiente** por grupo; una nueva pendiente cancela la anterior pendiente.
- `queue: max`: hasta **100** pendientes en cola FIFO (ideal para despliegues secuenciales). **Incompatible** con `cancel-in-progress: true` (error de validación).
- `cancel-in-progress` acepta expresiones: `${{ !contains(github.ref, 'release/') }}`.
- El nombre del grupo no distingue mayúsculas. Incluye `github.workflow` para no cancelar runs de otros workflows.
- Contextos permitidos: `github`, `inputs`, `vars`, `needs`, `strategy`, `matrix`.

## 5. Contextos, expresiones, variables

Contextos: `github`, `env`, `vars`, `job`, `jobs` (reusable), `steps`, `runner`, `secrets`, `strategy`, `matrix`, `needs`, `inputs`.

| Dato | Cómo |
|---|---|
| Rama/tag | `github.ref` (`refs/heads/main`), `github.ref_name` (`main`), `github.ref_type` |
| Ramas del PR | `github.head_ref` / `github.base_ref` (solo eventos de PR) |
| SHA | `github.sha` (en `pull_request` es el merge commit; el del head: `github.event.pull_request.head.sha`) |
| Evento | `github.event_name`; payload en `github.event` (archivo `$GITHUB_EVENT_PATH`) |
| Repo | `github.repository` (`owner/repo`), `github.repository_owner` |
| Ejecución | `github.run_id`, `github.run_number`, `github.run_attempt` |
| Variables de configuración | `vars.NOMBRE` (repo/environment/org), no secretas |
| Secretos | `secrets.NOMBRE`, `secrets.GITHUB_TOKEN` (o `github.token`) |

Funciones: `contains()`, `startsWith()`, `endsWith()`, `format('{0}-{1}', a, b)`, `join(arr, ',')`, `toJSON()`, `fromJSON()`, `hashFiles('**/package-lock.json')`. Strings con comillas simples (`'it''s'`). Operadores: `== != < > <= >= && || !`. Ternario: `cond && 'a' || 'b'` (falla si 'a' es falsy).

- **Los secretos no se pueden usar directamente en `if:`**: pásalos a `env` y compara `env.X != ''`.
- Variables por defecto: `GITHUB_WORKSPACE`, `GITHUB_SHA`, `GITHUB_REF`, `GITHUB_REPOSITORY`, `GITHUB_RUN_ID`, `RUNNER_OS`, `RUNNER_TEMP`, `CI=true`… `${{ env.X }}` se evalúa antes de enviar al runner; `$X` lo resuelve el shell.
- Secretos ≤ 48 KB c/u; para archivos mayores, cifrar (gpg) y guardar la passphrase como secreto.
- Precedencia: secreto/variable de environment > repo > organización.

## 6. Comandos de workflow

```bash
echo "name=value" >> "$GITHUB_OUTPUT"        # outputs de step
echo "MI_VAR=valor" >> "$GITHUB_ENV"         # env para steps siguientes
echo "$HOME/.local/bin" >> "$GITHUB_PATH"    # PATH para steps siguientes
echo "### Resumen" >> "$GITHUB_STEP_SUMMARY" # markdown en el resumen del job
{ echo "BODY<<EOF"; cat notas.md; echo "EOF"; } >> "$GITHUB_ENV"   # multilínea

echo "::add-mask::$VALOR_DERIVADO"
echo "::error file=app.js,line=10,col=5,title=Lint::Mensaje"
echo "::warning::..."; echo "::notice::..."
echo "::group::Instalando"; ...; echo "::endgroup::"
```
`::set-output` y `::save-state` por stdout están obsoletos: usa los archivos. Depuración: secreto/variable `ACTIONS_STEP_DEBUG=true` (y `ACTIONS_RUNNER_DEBUG=true`) o "Re-run with debug logging".

## 7. Reutilización

| | Reusable workflow | Composite action | JavaScript action | Docker action |
|---|---|---|---|---|
| Se usa en | `jobs.<id>.uses` | `steps[*].uses` | `steps[*].uses` | `steps[*].uses` |
| Contiene | jobs completos (runners, environments) | steps | código Node (`runs.using: node24`/`node20`) | contenedor (solo Linux) |
| Secretos | `secrets:` explícitos o `secrets: inherit` | vía `inputs`/env | idem | idem |
| Logs | por job | un step | un step | un step |

Reusable workflow:
```yaml
on:
  workflow_call:
    inputs:
      environment: { type: string, required: true }
    secrets:
      DEPLOY_KEY: { required: true }
    outputs:
      image:
        value: ${{ jobs.build.outputs.image }}
```
Llamada: `uses: org/repo/.github/workflows/build.yml@<sha|tag|rama>` o `./.github/workflows/build.yml` (mismo repo y commit). Notas:
- El `env` del caller **no** se propaga; usa `inputs`.
- Anidamiento limitado (del orden de 10 niveles y 50 workflows llamados por run; verifica en "Reutilización de configuraciones de flujo de trabajo").
- `permissions` del llamado no pueden superar las del caller.
- Repos privados: Settings → Actions → General → Access para compartir.
- Plantillas de workflow de org: repo `.github` de la org, carpeta `workflow-templates/` (`.yml` + `.properties.json`).

Composite action (`action.yml`): `runs: using: composite`; cada step `run` exige `shell:`. Metadatos: `name`, `description`, `inputs`, `outputs`, `runs`, `branding`. Publicar en Marketplace: repo público con `action.yml` en la raíz, releases inmutables, tags semver + tag major.

## 8. Cache y artefactos

```yaml
- uses: actions/cache@v4      # verifica la major vigente
  with:
    path: ~/.cache/pip
    key: pip-${{ runner.os }}-${{ hashFiles('**/requirements*.txt') }}
    restore-keys: pip-${{ runner.os }}-
```
- Muchas `setup-*` tienen cache integrada (`cache: npm|pip|maven|gradle|go`).
- 10 GB por repo incluidos (ampliable pagando); entradas sin uso 7 días se eliminan; una rama solo lee cache propia, de la base o de la rama por defecto. Límites: 200 subidas/min, 1500 descargas/min, 400 borrados/min por repo.
- Artefactos: `actions/upload-artifact` / `download-artifact` (v4+: inmutables, nombre único por run; para juntar varios usa `pattern:` + `merge-multiple: true`). `retention-days` (default 90). Entre jobs → artefactos; entre runs → cache o artefactos vía API.

## 9. Environments y despliegues

```yaml
deploy:
  environment:
    name: production
    url: ${{ steps.deploy.outputs.url }}
```
Reglas de protección: revisores requeridos (hasta 6; se puede impedir la auto-aprobación), temporizador (hasta 30 días), ramas/tags de despliegue permitidos, reglas personalizadas (GitHub Apps). Secretos y variables por environment. En repos privados, algunas reglas requieren Team/Enterprise (verificar por plan). Historial en "Deployments".

## 10. Contenedores y servicios

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    container: node:22
    services:
      postgres:
        image: postgres:17
        env: { POSTGRES_PASSWORD: postgres }
        options: >-
          --health-cmd pg_isready --health-interval 10s
          --health-timeout 5s --health-retries 5
        ports: ['5432:5432']   # solo necesario si el job NO corre en container
```
Dentro de `container:` el host del servicio es su nombre (`postgres`); fuera, `localhost`. `container`/`services` solo en Linux. `ubuntu-slim` no soporta Docker-in-Docker. Las Docker actions deben correr como root (sin `USER` en el Dockerfile) para acceder a `GITHUB_WORKSPACE`.

## 11. Errores frecuentes

- Tabs en YAML → error. Solo espacios.
- `if: ${{ a }} && b` mezcla → todo dentro de un `${{ }}` o nada.
- `needs.x.outputs.y` vacío: el step no tiene `id`, el job no mapea el output, o el valor contenía un secreto (se omite).
- Contextos no disponibles en ciertas claves (`runs-on`, `concurrency`, `env` de workflow…): revisa la tabla "Disponibilidad de contextos".
- `workflow_dispatch` no aparece: el archivo no está en la rama por defecto.
- Valida con `actionlint`; prueba local aproximada con `act`.
