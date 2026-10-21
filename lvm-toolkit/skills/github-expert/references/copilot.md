# GitHub Copilot

Estado a oct-2026. Es el área que más cambia: verifica planes, modelos y precios en la doc antes de afirmar.

## 1. Planes y AI credits

Copilot factura con **GitHub AI Credits** (uso basado en tokens según modelo). La facturación por "premium requests" con multiplicadores es **heredada** (aún aplica a algunos planes anuales). **Las sugerencias de código (completions) y Next edit suggestions no consumen AI credits y son ilimitadas en planes pagos.**

| Plan | Precio | AI credits/mes | Notas |
|---|---|---|---|
| Copilot Free | 0 | asignación limitada | 2.000 completions/mes; solo selección automática de modelo; agentes limitados |
| Copilot Student | 0 (estudiantes verificados) | asignación limitada | sin agentes de terceros; auto model selection |
| Copilot Pro | 10 USD | 1.000 base + 500 flex = 1.500 | gratis para docentes verificados y maintainers OSS populares |
| Copilot Pro+ | 39 USD | 3.900 + 3.100 = 7.000 | modelos premium |
| Copilot Max | 100 USD | 10.000 + 10.000 = 20.000 | prioridad en modelos premium |
| Copilot Business | 19 USD/asiento | 1.900 por usuario (pool) | gestión centralizada y políticas |
| Copilot Enterprise | 39 USD/asiento | 3.900 por usuario (pool) | requiere Enterprise Cloud; features empresariales |

- Business/Enterprise: los créditos de cada licencia van a un **pool compartido** de la empresa; el exceso se cobra a **0,01 USD por AI credit**, controlable con presupuestos.
- El 22-04-2026 se pausaron temporalmente las compras self-service de Business/Enterprise (reapertura anunciada para pago con tarjeta/PayPal; trials en pausa). Verificar estado.
- **No disponible en GHES**. GHE.com requiere autenticarse contra el subdominio.
- Copilot Free solo para quien no recibe Copilot de una org.
- Todos los planes incluyen Copilot CLI y la app de Copilot.

Modelos (selección; disponibilidad varía por plan y política): familias Claude (Haiku 4.5, Sonnet 4.6/5, Opus 4.7/4.8/5, Fable 5/5.1 con condiciones de retención de datos), GPT‑5.x (incl. Codex), GPT‑6, Gemini Flash 3.x, Grok 4.x, Kimi, MAI-Code. Ver "Modelos admitidos". Los admins habilitan modelos por política; BYOK (trae tu propia clave) disponible en algunos clientes.

## 2. Superficies

- **IDE**: VS Code, Visual Studio, JetBrains, Eclipse, Xcode, Neovim… Completions, NES, chat, **modo agente** (local), subagentes, MCP.
- **GitHub.com**: Copilot Chat, resúmenes de PR, generación de issues, **Copilot code review**, **cloud agent**, Spaces (contexto curado), Memory (preview).
- **Copilot CLI** (`copilot`): agente en terminal, autopilot, fleet (tareas paralelas), delegación al cloud agent, sandbox local, plugins, ACP server, modo programático (`-p`), GitHub Actions.
- **Copilot app** (escritorio), **SDK** (embebe el bucle agente en tus apps), **GitHub Mobile**, Windows Terminal.
- Integraciones del cloud agent: Slack, Microsoft Teams, Jira, Linear, Azure Boards, Raycast; API y servidor MCP de GitHub.
- Agentes de terceros dentro de GitHub (Anthropic Claude, OpenAI Codex) — preview, según plan.

## 3. Copilot cloud agent (antes "coding agent")

- Trabaja en segundo plano en un entorno efímero **impulsado por GitHub Actions**: investiga, planifica, cambia código en una rama (`copilot/...`), corre tests/linters, y abre **un** PR por tarea.
- Puntos de entrada: panel de agentes, asignar un issue a **Copilot**, `@copilot` en un comentario de PR, Chat, IDE, `gh` (`gh agent-task create` — verificar sintaxis), API (`/agent-tasks`), MCP, Slack/Teams, automations (programadas o por eventos).
- Límites: un repo y una rama por tarea; **59 min máximos por sesión** (configurable menor con `timeout-minutes`); solo repos hospedados en GitHub; no repos de cuentas EMU de usuario.
- Costos: **minutos de Actions + AI credits**.
- Business/Enterprise: un admin debe habilitar la política; owners pueden excluir repos.
- Seguridad: firewall de salida con allowlist personalizable; los workflows de Actions en PRs del agente requieren aprobación de un humano para ejecutarse (por defecto); el PR necesita revisión de alguien distinto de quien lo pidió; reglas pueden exigir una aprobación extra en PRs de Copilot sin atribuir.
- **Entorno**: `.github/workflows/copilot-setup-steps.yml` con un único job llamado **`copilot-setup-steps`** (instala dependencias antes de que el agente empiece; puede usar larger runners o self-hosted vía ARC). Ver `assets/copilot-setup-steps.yml`.
- Secretos/variables para el agente: environment `copilot` del repo (o la nueva API de "Agents secrets/variables").
- MCP: configuración de MCP del repo (Settings → Copilot → Cloud agent) aplica a cloud agent y code review; GitHub MCP y Playwright MCP habilitados por defecto.

## 4. Copilot code review
- Solicitar a "Copilot" como revisor en el PR, revisión automática por ruleset o settings del repo/org, o "Review selection" en el IDE.
- Deja comentarios (no aprueba ni bloquea). Respeta `copilot-instructions.md` y archivos `*.instructions.md` con `applyTo`.
- Consume AI credits **y minutos de Actions en repos privados**.

## 5. Personalización (archivos)

| Qué | Dónde | Activación |
|---|---|---|
| Instrucciones del repo | `.github/copilot-instructions.md` | Automática |
| Instrucciones por ruta | `.github/instructions/*.instructions.md` con frontmatter `applyTo: "src/**/*.ts"` (y `excludeAgent: "code-review"` opcional) | Automática al tocar esas rutas |
| Instrucciones para agentes (estándar abierto) | `AGENTS.md` (también `CLAUDE.md`/`GEMINI.md` según superficie) | Automática |
| Instrucciones personales / de organización | UI de GitHub | Automática |
| Prompt files | `.github/prompts/*.prompt.md` | Manual (`/nombre`) — IDE |
| Custom agents | `.github/agents/NOMBRE.md` (repo); `/agents/` en el repo `.github` o `.github-private` de la org; repo `.github-private` de empresa; perfil de usuario | Seleccionar en el desplegable de agentes |
| Agent skills | `.github/skills/<skill>/SKILL.md`, `.claude/skills/...`, `.agents/skills/...`; personales en `~/.copilot/skills/` o `~/.agents/skills/` | Automática por relevancia |
| Hooks | `.github/hooks/*.json` | Eventos del ciclo de vida (preToolUse, postToolUse, sessionStart…) |
| MCP | `mcp.json` del IDE, config MCP del repo en GitHub, `mcp-servers` en custom agents | Automática / por nombre |

Prioridad de instrucciones: personales > repositorio > organización (todas se combinan). Buenas instrucciones: cómo compilar, testear y lintear; estructura del repo; convenciones; qué NO hacer. Breves y verificables.

Custom agent (frontmatter típico): `name`, `description`, `tools` (lista o `["*"]`), `mcp-servers`, `model` (en algunas superficies), seguido del prompt en Markdown. Ver "Configuración de agentes personalizados".

## 6. Gobierno (Business/Enterprise)
- Políticas por empresa/org: features (chat, agentes, code review, CLI, MCP, terceros), modelos habilitados, sugerencias que coinciden con código público (bloquear/permitir; *code referencing* muestra la licencia), MCP allowlist/registro privado, managed settings por equipo.
- **Content exclusion**: rutas/repos que Copilot ignora (no aplica igual en todas las superficies ni a agentes; revisar tabla de soporte).
- Métricas de uso (API y dashboards), registros de auditoría de actividad agentic, OpenTelemetry, presupuestos y centros de costo.
- Datos: Business/Enterprise no se usan para entrenar; retención según superficie (ver "Session data").
- Asignación de asientos: por equipos/usuarios o self-serve; cobro prorrateado.

## 7. Seguridad al usar agentes
- Trata el output del agente como código de un colaborador nuevo: revisión humana, CI, CODEOWNERS.
- Prompt injection desde issues/PRs/archivos: limita herramientas y MCP, mantén el firewall, no expongas secretos innecesarios en el environment `copilot`.
- Hooks + secret scanning para evitar filtraciones; rulesets aplican igual a las ramas del agente.
