# Actions — Runners, límites y costos

## Runners hospedados estándar (oct-2026)

**Repos públicos** (gratis e ilimitados):

| SO | CPU / RAM / SSD | Etiquetas |
|---|---|---|
| Linux x64 1 CPU (contenedor) | 1 / 5 GB / 14 GB | `ubuntu-slim` (timeout de job 15 min, sin privilegios, sin Docker-in-Docker) |
| Linux x64 | 4 / 16 GB / 14 GB | `ubuntu-latest` (=24.04), `ubuntu-24.04`, `ubuntu-22.04`, `ubuntu-26.04` |
| Windows x64 | 4 / 16 GB / 14 GB | `windows-latest` (=2025), `windows-2025`, `windows-2025-vs2026`, `windows-2022` |
| Linux arm64 | 4 / 16 GB / 14 GB | `ubuntu-24.04-arm`, `ubuntu-22.04-arm`, `ubuntu-26.04-arm` |
| Windows arm64 | 4 / 16 GB / 14 GB | `windows-11-arm`, `windows-11-vs2026-arm` |
| macOS Intel | 4 / 14 GB / 14 GB | `macos-15-intel`, `macos-26-intel` |
| macOS arm64 (M1) | 3 / 7 GB / 14 GB | `macos-latest` (=macOS 26), `macos-14`, `macos-15`, `macos-26`, `xcode-27` (preview) |

**Repos privados**: Linux/Windows x64 y arm64 bajan a **2 CPU / 8 GB**; `ubuntu-slim` y macOS igual que arriba. Consumen minutos incluidos y luego se cobran.

Notas: `-latest` apunta a la imagen estable más reciente de GitHub (no necesariamente el SO más nuevo). Las migraciones de `-latest` se anuncian con semanas de antelación en `actions/runner-images`: si algo se rompe "de golpe", fija la versión (`ubuntu-24.04`). Linux/macOS tienen `sudo` sin contraseña; Windows corre como admin con UAC deshabilitado. IPs: clave `actions` de `GET /meta` (no usar como allowlist: son rangos de Azure; usa larger runners con IP estática o self-hosted). SBOM de cada imagen en los releases de `actions/runner-images`.

Dominios a permitir en firewalls (self-hosted o redes privadas): `github.com`, `api.github.com`, `*.actions.githubusercontent.com`, `codeload.github.com`, `results-receiver.actions.githubusercontent.com`, `*.blob.core.windows.net`, `objects.githubusercontent.com`, `ghcr.io`, `*.pkg.github.com`, `pkg-containers.githubusercontent.com`, `release-assets.githubusercontent.com`, `github-cloud.githubusercontent.com` (LFS).

## Larger runners (Team y Enterprise Cloud)
Más CPU/RAM (Linux hasta 96 núcleos, Windows hasta 96, macOS 12 núcleos y M2 Pro 5 núcleos), GPU (Linux/Windows 4 núcleos), IP estática (hasta 10 por org/empresa), red privada de Azure (VNET injection: reservar ~30 % de IPs extra), grupos de runners, autoescalado e **imágenes personalizadas** (palabra clave `snapshot`, almacenamiento facturado aparte). **Siempre se cobran**, incluso en repos públicos, y no usan minutos incluidos. Se seleccionan por nombre/etiqueta o grupo: `runs-on: { group: gpu-runners, labels: linux-gpu }`.

## Self-hosted
- Gratis en minutos. Niveles: repo, org o empresa; grupos para limitar qué repos los usan.
- `runs-on: [self-hosted, linux, x64, gpu]` (todas las etiquetas deben coincidir).
- Efímeros: `./config.sh --ephemeral` o **JIT** vía API (`./run.sh --jitconfig ...`), un job por runner.
- **ARC (Actions Runner Controller)**: runner scale sets en Kubernetes (chart Helm `gha-runner-scale-set-controller` + `gha-runner-scale-set`); el nombre del scale set se usa en `runs-on`. Autenticar con GitHub App preferentemente.
- Límites: job 5 días, cola 24 h, 1500 registros/5 min, 10.000 runners por grupo.
- Docker Hub: self-hosted siempre sujeto a su rate limit; hospedados no lo sufren con imágenes públicas.

## Límites de Actions (reference/limits)
| Límite | Valor |
|---|---|
| Duración de job (hospedado) | 6 h |
| Duración total de un workflow run (incluye esperas/aprobaciones) | 35 días |
| Espera de aprobación de environment | 30 días |
| Jobs por matrix | 256 |
| Re-ejecuciones por run | 50 |
| Tamaño de archivo de workflow | 500 KB |
| Check runs por check suite | 50.000 |
| Eventos que disparan workflows | 1500 / 10 s / repo |
| Runs encolados | 500 / 10 s |
| Cola de un grupo de concurrency (`queue: max`) | 100 |

Concurrencia de jobs en hospedados estándar: Free 20 (macOS 5), Pro 40 (5), Team 60 (5), Enterprise 500 (50). Larger: hasta 1000 (GPU 100). Ampliable por soporte.

Rate limit de API relevante: `GITHUB_TOKEN` **1000 req/h por repo** (15.000 en recursos de Enterprise Cloud).

## Incluido por plan (repos privados, runners estándar)
| Plan | Minutos/mes | Artefactos + Packages | Cache por repo | Imágenes custom |
|---|---|---|---|---|
| Free (usuario y org) | 2.000 | 500 MB | 10 GB | — |
| Pro | 3.000 | 1 GB | 10 GB | — |
| Team | 3.000 | 2 GB | 10 GB | 75 GB |
| Enterprise Cloud | 50.000 | 50 GB | 10 GB | 150 GB |

Gratis siempre: repos públicos con runners estándar, self-hosted, GitHub Pages y Dependabot. Los minutos se cobran al **dueño del repo**, no a quien dispara. Sin método de pago, al agotar lo incluido el uso se bloquea; con método de pago, lo limitan los **presupuestos** (alertas al 90 % y 100 % de lo incluido).

## Precios por minuto (USD, redondeo al minuto superior por job)
| Runner | SKU | USD/min |
|---|---|---|
| Linux 1 núcleo (`ubuntu-slim`) | `actions_linux_slim` | 0,002 |
| Linux 2 núcleos x64 | `actions_linux` | 0,006 |
| Linux 2 núcleos arm64 | `actions_linux_arm` | 0,005 |
| Windows 2 núcleos (x64/arm64) | `actions_windows(_arm)` | 0,010 |
| macOS 3–4 núcleos | `actions_macos` | 0,062 |
| Larger Linux x64 4/8/16/32/64/96 | `linux_N_core` | 0,012 / 0,022 / 0,042 / 0,082 / 0,162 / 0,252 |
| Larger Linux arm64 4/8/16/32/64 | `linux_N_core_arm` | 0,008 / 0,014 / 0,026 / 0,050 / 0,098 |
| Larger Windows x64 4/8/16/32/64/96 | `windows_N_core` | 0,022 / 0,042 / 0,082 / 0,162 / 0,322 / 0,552 |
| macOS 12 núcleos / M2 Pro 5 núcleos | `macos_l` / `macos_xl` | 0,077 / 0,102 |
| GPU Linux / Windows 4 núcleos | `*_4_core_gpu` | 0,052 / 0,102 |

Almacenamiento extra: artefactos+Packages 0,25 USD/GB-mes; cache 0,07; imágenes custom 0,07. Se mide en GB-hora (borrar artefactos frena el cargo futuro, no el acumulado). Copilot code review y Copilot cloud agent también consumen minutos de Actions en repos privados.

Ejemplo de cálculo: Team, 5.000 min por encima de lo incluido = 3.000 Linux × 0,006 + 2.000 Windows × 0,010 = 18 + 20 = **38 USD**.

Ahorro: `ubuntu-slim` para tareas livianas (labels, bots), arm64 (más barato que x64), cancelar runs obsoletos con `concurrency`, `timeout-minutes`, cache, `paths` filters, matrices más chicas en PRs, artefactos con retención corta.
