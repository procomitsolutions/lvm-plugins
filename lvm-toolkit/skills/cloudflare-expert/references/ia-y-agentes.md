# IA, agentes y servicios relacionados

## Contenido
1. Workers AI
2. AI Gateway
3. Vectorize y RAG a medida
4. AI Search (RAG gestionado)
5. Agents SDK
6. MCP: servidores y clientes
7. Agent Memory
8. Sandboxes, Containers y Dynamic Workers
9. Browser Run
10. Email Service
11. Pagos agénticos y monetización

---

## 1. Workers AI

```jsonc
"ai": { "binding": "AI" }
```
```ts
const out = await env.AI.run("@cf/meta/llama-3.1-8b-instruct", {
  messages: [{ role: "system", content: "Eres conciso." }, { role: "user", content: prompt }],
  stream: false,
});
// Embeddings
const { data } = await env.AI.run("@cf/baai/bge-base-en-v1.5", { text: ["hola mundo"] }); // 768 dimensiones
```
- **Los IDs de modelos cambian a menudo.** Antes de recomendar un modelo, verifica el catálogo con `npx wrangler ai models` o en `https://developers.cloudflare.com/workers-ai/models/`. Los ejemplos de arriba son ilustrativos.
- Tareas: generación de texto, embeddings, clasificación, reranking, traducción, resumen, texto a imagen, ASR (Whisper), TTS, visión, detección de objetos.
- Modelos de decisión "Clef" y "Clef-flash" (oct. 2026): devuelven respuestas tipadas con probabilidades; son open source (Apache 2.0).
- Endpoint compatible con OpenAI (`/ai/v1/chat/completions`), function calling, JSON mode, LoRA, batch y Vercel AI SDK (`workers-ai-provider`).
- REST: `POST https://api.cloudflare.com/client/v4/accounts/{account_id}/ai/run/{model}`.

## 2. AI Gateway

Proxy delante de cualquier proveedor (Workers AI, OpenAI, Anthropic, Google, Bedrock, Groq, etc.): caché, rate limiting, reintentos, fallback entre modelos, logs de prompts y respuestas, analítica de costos, guardrails y DLP.
- URL: `https://gateway.ai.cloudflare.com/v1/{account_id}/{gateway_id}/{provider}/...` (reemplaza el `baseURL` del SDK del proveedor).
- Desde Workers AI: `env.AI.run(model, input, { gateway: { id: "my-gateway" } })`.
- Hay un endpoint unificado compatible con OpenAI. Verifica la sintaxis actual en `ai-gateway/llms.txt`.

## 3. Vectorize y RAG a medida

```sh
npx wrangler vectorize create docs-idx --dimensions=768 --metric=cosine
npx wrangler vectorize create-metadata-index docs-idx --property-name=category --type=string
```
```ts
await env.VECTORIZE.upsert([{ id: "doc-1", values: embedding, metadata: { category: "faq", text } }]);
const res = await env.VECTORIZE.query(queryEmbedding, { topK: 5, returnMetadata: "all", filter: { category: "faq" } });
```
Patrón RAG: chunking → embeddings con Workers AI → Vectorize (metadata con el texto, o el ID que apunte a D1/R2) → query → prompt con contexto → LLM. Las dimensiones del índice deben coincidir con las del modelo de embeddings.

## 4. AI Search (GA)

RAG totalmente gestionado (antes AutoRAG): conecta una fuente (bucket R2, sitio web), indexa, hace chunking y embeddings y responde. Precio por uso, incluye llamadas a Workers AI. Se usa desde un binding de Workers, la REST API o como herramienta de agentes. Elígelo cuando el usuario quiere RAG sin construir el pipeline; elige Vectorize cuando necesita control fino.

## 5. Agents SDK (`agents`)

El `Agent` es un Durable Object con estado sincronizado, SQL, WebSockets, scheduling, RPC invocable desde el cliente, colas, reintentos, sub-agentes y Workflows.

```ts
import { Agent, routeAgentRequest, callable } from "agents";

type State = { count: number };
export class CounterAgent extends Agent<Env, State> {
  initialState: State = { count: 0 };
  @callable() increment() { this.setState({ count: this.state.count + 1 }); return this.state.count; }
  async onRequest(req: Request) { return Response.json(this.state); }
  // this.sql`SELECT ...`, this.schedule(delay|date|cron, "method", payload), this.queue(...), this.broadcast(...)
}

export default {
  async fetch(req, env) { return (await routeAgentRequest(req, env)) ?? new Response("Not found", { status: 404 }); },
} satisfies ExportedHandler<Env>;
```
Configuración: binding de DO con `name` y `class_name` iguales a la clase, clase SQLite declarada (en la doc aparece con `migrations` + `new_sqlite_classes`; también vale `exports`, ver `datos-y-almacenamiento.md`) y `nodejs_compat`.

Puntos clave y errores frecuentes:
- Ruta por defecto: `/agents/{agent-name}/{instance-name}` (configurable con `prefix`). Cada nombre de instancia es un agente independiente.
- Cliente: `useAgent` (`agents/react`) o `AgentClient` (`agents/client`); `agent.stub.metodo()` llama a los métodos `@callable()`.
- Desde el servidor: `getAgentByName(env.CounterAgent, "shared")`.
- Decoradores TC39: `tsconfig` debe extender `agents/tsconfig` (`target: ES2021`). **No** actives `experimentalDecorators` (rompe `@callable()` en silencio). Con Vite, agrega el plugin `agents()` de `agents/vite`.
- Devuelve sin modificar la respuesta de `routeAgentRequest` (envolverla rompe los WebSockets).
- Usa `this.setState()`; mutar `this.state` directamente no persiste.
- Con chat: `AIChatAgent` + `useAgentChat` (persistencia de mensajes, streaming, tools).
- **Think**: harness opinado de agente de chat (tools integradas incluido bash, memoria, hooks de ciclo de vida, aprobaciones, canales y messengers como Telegram, tareas programadas, `ThinkWorkflow`).
- **Code Mode** (`@cloudflare/codemode`): el modelo escribe código que compone tools y corre aislado en Dynamic Workers. Ahorra muchos tokens con APIs grandes.
- Ejecución durable: `runFiber()` y `keepAlive()` para trabajo que sobrevive a la eviction; integración con Workflows para procesos largos.
- Canales: WebSocket, HTTP/SSE, email, Slack, voz, webhooks y push notifications.
- Modelos: Workers AI (sin API key), OpenAI, Anthropic, Gemini y otros vía AI SDK, opcionalmente detrás de AI Gateway.
- Arranque rápido: `npm create cloudflare@latest -- --template cloudflare/agents-starter`.

## 6. MCP

### Servidor MCP remoto (forma actual)
**`McpAgent` está DEPRECADO y congelado.** Para servidores nuevos usa `createMcpHandler` (stateless) con MCP SDK v2:

```sh
npm i agents @modelcontextprotocol/server@2.0.0 zod   # usa las versiones exactas que pida tu release de agents
```
```ts
import { McpServer } from "@modelcontextprotocol/server";
import { createMcpHandler } from "agents/mcp/server";
import { z } from "zod";

function createServer() {                     // factory: un servidor nuevo por request
  const server = new McpServer({ name: "my-server", version: "1.0.0" });
  server.registerTool("add", { description: "Suma dos números", inputSchema: { a: z.number(), b: z.number() } },
    async ({ a, b }) => ({ content: [{ type: "text", text: String(a + b) }] }));
  return server;
}

export default {
  fetch(request, env, ctx) { return createMcpHandler(createServer)(request, env, ctx); },
} satisfies ExportedHandler;
```
- Pasa la **factory**, no una instancia global. No exportes el handler directamente como `default` (Wrangler interpreta las funciones exportadas como `WorkerEntrypoint`).
- Opciones: `route` (por defecto `/mcp`), `corsOptions`, `allowedHostnames` y `allowedOriginHostnames` (necesarios con un custom domain), `legacy: "stateless" | "reject"`, `responseMode: "auto" | "json" | "sse"`.
- Stateless: sin session ID. GET y DELETE devuelven 405. La elicitación usa multi-round-trip (`inputRequired`). El estado durable va en DO, D1, KV o R2 detrás de un handle autenticado.
- Notificaciones (`notify.toolsChanged()`, etc.): crea el handler una sola vez a nivel de módulo; son locales al isolate.
- Puente temporal para servidores con sesión: `createLegacyMcpHandler` (`agents/mcp`, SDK v1 `@modelcontextprotocol/sdk`). Guía: "Migrate to MCP SDK v2".
- Las plantillas de deploy rápido (`cloudflare/ai/demos/remote-mcp-authless`) todavía usan `McpAgent`: para código nuevo parte del ejemplo `mcp-worker` del repo `cloudflare/agents`.

### Autenticación
- `@cloudflare/workers-oauth-provider` (v1, oct. 2026): separa el authorization server de los servidores MCP, admite step-up authorization y la spec MCP 2026-07-28. El `AuthInfo` verificado llega en `context.http.authInfo`; las props de la app con `getMcpAuthContext()`. Nunca devuelvas ni registres en logs `authInfo.token`.
- Proveedores: Cloudflare Access (Access for SaaS), GitHub, Google, Auth0, WorkOS, Stytch, etc. KV `OAUTH_KV` para el estado OAuth.
- Gobernanza: MCP server portals en Cloudflare One.

### Probar
`npx @modelcontextprotocol/inspector@latest` → `http://localhost:8788/mcp`. Clientes sin transporte remoto: `npx mcp-remote <url>`. También el AI Playground.

### Cliente MCP desde un Agent
`this.addMcpServer(name, url)` / `McpClient`, con OAuth hacia servidores protegidos.

## 7. Agent Memory

Memoria persistente para agentes: ingesta conversaciones, extrae y clasifica conocimiento y lo recupera después. Se aísla por **namespaces** (aplicación) y **perfiles** (usuario o agente). Acceso por binding de Workers o HTTP API. Verifica la API exacta en `agent-memory/api/workers-api/index.md`.

## 8. Ejecución de código aislado

| Opción | Cuándo |
|---|---|
| **Dynamic Workers** (Worker Loader) | Código JS/TS generado o de usuarios que solo necesita llamar a métodos que tu Worker le expone. Arranque en milisegundos. |
| **Sandboxes** (`@cloudflare/sandbox`) | Linux completo: shell, Python, git, tests, servidores con preview URLs, montar R2, snapshots, terminal en el navegador, agentes de código (Claude Code, Codex, OpenCode, Cursor, Devin). |
| **Containers** | Cualquier imagen Docker controlada desde un Durable Object (`this.ctx.container`). |

- **Sandbox SDK 1.0** cambia el modelo: la lógica de la clase `Sandbox` de 0.x pasa a un Durable Object que escribes tú (que arranca su propio container y decide ciclo de vida, red y estado). `exec()` pasa a `container.exec()`, y aparecen `Files`, `DirectoryBackup` y `S3Mount`. La 0.x (0.12) tiene guía de migración paso a paso. Pregunta qué versión usa el usuario antes de escribir código.
- Seguridad: el sandbox puede usar todo lo que le pongas dentro. Inyecta credenciales desde el Worker (proxy de salida) y nunca dentro del sandbox. Usa un hostname de preview por sandbox para aislar cookies.

## 9. Browser Run (antes Browser Rendering)

- **Quick Actions** (REST, sin código): `/screenshot`, `/pdf`, `/content`, `/markdown`, `/json` (extracción con IA), `/scrape`, `/links`, `/crawl`, `/snapshot`, `/accessibilityTree`.
- **Desde Workers**: binding `browser` con `@cloudflare/puppeteer` o `@cloudflare/playwright`. Reutiliza sesiones (combina bien con Durable Objects).
- **CDP**: sesiones persistentes vía `/devtools` desde cualquier entorno Node, `chrome-devtools-mcp`, Playwright MCP y Stagehand.
- Funciones: Live View, human-in-the-loop, grabación de sesiones, guardrails por hostname, Outbound Workers, WebMCP, fuentes personalizadas. Kitesurf es un navegador stateless orientado a agentes.
- Respeta robots.txt; las requests llevan headers que identifican el bot.

## 10. Email Service

Envío:
```jsonc
"send_email": [{ "name": "EMAIL" }]
```
```ts
const { messageId } = await env.EMAIL.send({
  to: "user@example.com",                       // máx. 50 destinatarios entre to, cc y bcc
  from: { email: "noreply@tudominio.com", name: "Mi App" },
  subject: "Bienvenido",
  html: "<h1>Hola</h1>", text: "Hola",
  // attachments: [{ content: base64, filename, type, disposition: "attachment" }]  máx. 32; mensaje total ≤ 5 MiB
});
```
- Errores con `e.code`: `E_SENDER_NOT_VERIFIED`, `E_RATE_LIMIT_EXCEEDED`, `E_DAILY_LIMIT_EXCEEDED`, `E_TOO_MANY_RECIPIENTS`, `E_RECIPIENT_SUPPRESSED`, `E_CONTENT_TOO_LARGE`, `E_HEADER_NOT_ALLOWED`, etc.
- También REST API y SMTP (`smtp.mx.cloudflare.net`). El dominio requiere SPF, DKIM y DMARC. Listas de supresión. Eventos de envío hacia Queues. Se pueden restringir remitentes y destinatarios en el binding.
- La API `EmailMessage` (`cloudflare:email`, MIME crudo) queda como legacy.

Recepción (Email Routing): reglas hacia direcciones o hacia un Worker con `async email(message, env, ctx)` → `message.forward()`, `message.reply()`, `message.setReject()`. Un Agent puede recibir y responder correos.

## 11. Pagos agénticos y monetización

- **x402** y **MPP** (Machine Payments Protocol) en Agents SDK: cobrar por endpoints HTTP o por tools MCP (`paidTool`) y pagar desde agentes (`withX402Client`).
- **Monetization Gateway**: políticas para cobrar el acceso a APIs, tools MCP, páginas o datasets.
- **Wallets**: identidad de wallet legible para la cuenta y sus agentes.
- **AI Crawl Control**: controlar o cobrar a los crawlers de IA.
