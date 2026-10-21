# Plantillas listas para copiar

Todas asumen `compatibility_date` igual a la fecha de hoy, `nodejs_compat` y `npx wrangler types` ejecutado tras configurar los bindings. Ajusta nombres e IDs.

## Contenido
1. API REST con Hono + D1
2. Subida y descarga de archivos con R2
3. Chat en tiempo real con Durable Objects (WebSocket Hibernation)
4. Productor y consumidor de Queues
5. Workflow de pedido con aprobación humana
6. RAG con Workers AI + Vectorize
7. Servidor MCP remoto stateless
8. Full-stack: React (Vite) + API en el mismo Worker
9. Turnstile: validación en el servidor
10. Cron + KV
11. Validar un JWT de Cloudflare Access

---

## 1. API REST con Hono + D1

```sh
npm create cloudflare@latest my-api -- --framework=hono
npx wrangler d1 create my-db
npx wrangler d1 migrations create my-db init
```
`migrations/0001_init.sql`:
```sql
CREATE TABLE IF NOT EXISTS todos (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, done INTEGER NOT NULL DEFAULT 0);
```
`wrangler.jsonc`:
```jsonc
{
  "name": "my-api", "main": "src/index.ts",
  "compatibility_date": "2026-10-01", "compatibility_flags": ["nodejs_compat"],
  "observability": { "enabled": true },
  "d1_databases": [{ "binding": "DB", "database_name": "my-db", "database_id": "<D1_ID>" }]
}
```
`src/index.ts`:
```ts
import { Hono } from "hono";

const app = new Hono<{ Bindings: Env }>();

app.get("/todos", async (c) => {
  const { results } = await c.env.DB.prepare("SELECT * FROM todos ORDER BY id DESC").all();
  return c.json(results);
});

app.post("/todos", async (c) => {
  const body = await c.req.json<{ title?: string }>();
  if (!body.title) return c.json({ error: "title requerido" }, 400);
  const row = await c.env.DB.prepare("INSERT INTO todos (title) VALUES (?) RETURNING *").bind(body.title).first();
  return c.json(row, 201);
});

app.onError((err, c) => {
  console.error(JSON.stringify({ message: "unhandled", error: err.message }));
  return c.json({ error: "Internal server error" }, 500);
});

export default app;
```
```sh
npx wrangler d1 migrations apply my-db --remote && npx wrangler deploy
```

## 2. R2: subida y descarga

```jsonc
"r2_buckets": [{ "binding": "BUCKET", "bucket_name": "uploads" }]
```
```ts
const MAX = 50 * 1024 * 1024;

export default {
  async fetch(req, env) {
    const key = new URL(req.url).pathname.slice(1);
    if (!key) return new Response("Falta la clave", { status: 400 });

    if (req.method === "PUT") {
      const len = Number(req.headers.get("content-length") ?? 0);
      if (!len || len > MAX) return new Response("Tamaño inválido", { status: 413 });
      await env.BUCKET.put(key, req.body, { httpMetadata: { contentType: req.headers.get("content-type") ?? "application/octet-stream" } });
      return new Response("OK", { status: 201 });
    }
    if (req.method === "GET") {
      const obj = await env.BUCKET.get(key);
      if (!obj) return new Response("Not found", { status: 404 });
      const h = new Headers(); obj.writeHttpMetadata(h); h.set("etag", obj.httpEtag);
      return new Response(obj.body, { headers: h });        // streaming, sin buffer
    }
    if (req.method === "DELETE") { await env.BUCKET.delete(key); return new Response(null, { status: 204 }); }
    return new Response("Method not allowed", { status: 405 });
  },
} satisfies ExportedHandler<Env>;
```
Agrega autenticación antes de exponerlo. Para subidas directas desde el navegador, usa presigned URLs de la API S3.

## 3. Chat con Durable Objects (WebSocket Hibernation)

```jsonc
"durable_objects": { "bindings": [{ "name": "CHAT_ROOM", "class_name": "ChatRoom" }] },
"exports": { "ChatRoom": { "type": "durable-object", "storage": "sqlite" } }
```
```ts
import { DurableObject } from "cloudflare:workers";

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    const room = url.searchParams.get("room") ?? "lobby";
    if (req.headers.get("Upgrade") !== "websocket") return new Response("Expected WebSocket", { status: 426 });
    return env.CHAT_ROOM.getByName(room).fetch(req);
  },
} satisfies ExportedHandler<Env>;

export class ChatRoom extends DurableObject<Env> {
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    this.ctx.setWebSocketAutoResponse(new WebSocketRequestResponsePair("ping", "pong"));
    this.ctx.storage.sql.exec("CREATE TABLE IF NOT EXISTS msgs (ts INTEGER, text TEXT)");
  }
  async fetch(_req: Request) {
    const [client, server] = Object.values(new WebSocketPair());
    this.ctx.acceptWebSocket(server);                    // habilita la hibernación
    const history = this.ctx.storage.sql.exec("SELECT text FROM msgs ORDER BY ts DESC LIMIT 50").toArray();
    server.send(JSON.stringify({ type: "history", history }));
    return new Response(null, { status: 101, webSocket: client });
  }
  async webSocketMessage(_ws: WebSocket, msg: string | ArrayBuffer) {
    const text = typeof msg === "string" ? msg : new TextDecoder().decode(msg);
    this.ctx.storage.sql.exec("INSERT INTO msgs VALUES (?, ?)", Date.now(), text);
    for (const c of this.ctx.getWebSockets()) c.send(JSON.stringify({ type: "msg", text }));
  }
  async webSocketClose(ws: WebSocket, code: number, reason: string) { ws.close(code, reason); }
}
```

## 4. Queues

```jsonc
"queues": {
  "producers": [{ "binding": "EMAILS", "queue": "emails" }],
  "consumers": [{ "queue": "emails", "max_batch_size": 10, "max_batch_timeout": 5, "max_retries": 5, "dead_letter_queue": "emails-dlq" }]
}
```
```ts
type Job = { to: string; template: string };

export default {
  async fetch(req, env) {
    const job = await req.json<Job>();
    await env.EMAILS.send(job);
    return Response.json({ status: "queued" }, { status: 202 });
  },
  async queue(batch: MessageBatch<Job>, env) {
    for (const m of batch.messages) {
      try { await sendEmail(env, m.body); m.ack(); }
      catch (e) { console.error(JSON.stringify({ message: "send failed", id: m.id, attempts: m.attempts })); m.retry({ delaySeconds: 30 * m.attempts }); }
    }
  },
} satisfies ExportedHandler<Env, Job>;
```
```sh
npx wrangler queues create emails && npx wrangler queues create emails-dlq
```

## 5. Workflow con aprobación humana

```jsonc
"workflows": [{ "name": "refund-flow", "binding": "REFUND", "class_name": "RefundFlow" }]
```
```ts
import { WorkflowEntrypoint, WorkflowEvent, WorkflowStep } from "cloudflare:workers";
type P = { orderId: string; amount: number };

export class RefundFlow extends WorkflowEntrypoint<Env, P> {
  async run(event: WorkflowEvent<P>, step: WorkflowStep) {
    const order = await step.do("load order", async () => loadOrder(this.env, event.payload.orderId));
    if (event.payload.amount > 100) {
      const ev = await step.waitForEvent<{ approved: boolean }>("approval", { type: "refund-approval", timeout: "3 days" });
      if (!ev.payload.approved) return { status: "rejected" };
    }
    await step.do("refund", { retries: { limit: 5, delay: "30 seconds", backoff: "exponential" } }, async () => refund(order));
    await step.do("notify", async () => notify(this.env, order));
    return { status: "refunded" };
  }
}

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    if (url.pathname === "/refund") {
      const p = await req.json<P>();
      const inst = await env.REFUND.create({ id: `refund-${p.orderId}`, params: p });
      return Response.json({ id: inst.id });
    }
    if (url.pathname === "/approve") {
      const id = url.searchParams.get("id")!;
      await (await env.REFUND.get(id)).sendEvent({ type: "refund-approval", payload: { approved: true } });
      return new Response("ok");
    }
    return new Response("Not found", { status: 404 });
  },
} satisfies ExportedHandler<Env>;
```
Verifica la firma actual de `step.do`, `waitForEvent` y `sendEvent` en `workflows/llms.txt`.

## 6. RAG con Workers AI + Vectorize

```sh
npx wrangler vectorize create kb --dimensions=768 --metric=cosine
```
```jsonc
"ai": { "binding": "AI" },
"vectorize": [{ "binding": "KB", "index_name": "kb" }]
```
```ts
const EMBED = "@cf/baai/bge-base-en-v1.5";           // 768 dims; verifica el catálogo
const LLM = "@cf/meta/llama-3.1-8b-instruct";        // verifica el catálogo

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    if (req.method === "POST" && url.pathname === "/ingest") {
      const { id, text } = await req.json<{ id: string; text: string }>();
      const { data } = await env.AI.run(EMBED, { text: [text] });
      await env.KB.upsert([{ id, values: data[0], metadata: { text } }]);
      return new Response("ok");
    }
    const q = url.searchParams.get("q");
    if (!q) return new Response("Falta q", { status: 400 });
    const { data } = await env.AI.run(EMBED, { text: [q] });
    const { matches } = await env.KB.query(data[0], { topK: 4, returnMetadata: "all" });
    const context = matches.map((m) => m.metadata?.text).join("\n---\n");
    const answer = await env.AI.run(LLM, {
      messages: [
        { role: "system", content: `Responde solo con este contexto:\n${context}` },
        { role: "user", content: q },
      ],
    });
    return Response.json({ answer, sources: matches.map((m) => m.id) });
  },
} satisfies ExportedHandler<Env>;
```
Si el usuario no necesita control fino, sugiere AI Search (RAG gestionado).

## 7. Servidor MCP remoto stateless

```sh
npm i agents @modelcontextprotocol/server@2.0.0 zod
```
```ts
import { McpServer } from "@modelcontextprotocol/server";
import { createMcpHandler } from "agents/mcp/server";
import { z } from "zod";

function createServer(env: Env) {
  const server = new McpServer({ name: "kv-tools", version: "1.0.0" });
  server.registerTool("get_note", { description: "Lee una nota", inputSchema: { key: z.string() } },
    async ({ key }) => ({ content: [{ type: "text", text: (await env.NOTES.get(key)) ?? "(vacía)" }] }));
  server.registerTool("save_note", { description: "Guarda una nota", inputSchema: { key: z.string(), text: z.string() } },
    async ({ key, text }) => { await env.NOTES.put(key, text); return { content: [{ type: "text", text: "guardada" }] }; });
  return server;
}

export default {
  fetch(request, env, ctx) {
    return createMcpHandler(() => createServer(env))(request, env, ctx);
  },
} satisfies ExportedHandler<Env>;
```
Pruébalo con `npx @modelcontextprotocol/inspector@latest` contra `http://localhost:8787/mcp`. Antes de exponer tools que escriben datos, agrega OAuth (`@cloudflare/workers-oauth-provider` o Cloudflare Access). Con un custom domain, configura `allowedHostnames`.

## 8. Full-stack: React (Vite) + API

```sh
npm create cloudflare@latest my-app -- --framework=react
```
```jsonc
{
  "name": "my-app", "main": "worker/index.ts",
  "compatibility_date": "2026-10-01", "compatibility_flags": ["nodejs_compat"],
  "assets": { "directory": "./dist", "not_found_handling": "single-page-application", "run_worker_first": ["/api/*"] }
}
```
```ts
export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    if (url.pathname.startsWith("/api/")) return Response.json({ hello: "world" });
    return new Response(null, { status: 404 });   // el resto lo sirve Static Assets
  },
} satisfies ExportedHandler<Env>;
```
Con `@cloudflare/vite-plugin`, `npm run dev` levanta front y Worker juntos. Verifica la semántica de `run_worker_first` en `workers/static-assets/routing/index.md`.

## 9. Turnstile: validación en el servidor

```ts
async function verifyTurnstile(token: string, secret: string, ip?: string) {
  const body = new FormData();
  body.append("secret", secret);
  body.append("response", token);
  if (ip) body.append("remoteip", ip);
  const r = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", { method: "POST", body });
  const data = await r.json<{ success: boolean; "error-codes": string[]; hostname?: string; action?: string }>();
  return data;
}

export default {
  async fetch(req, env) {
    const form = await req.formData();
    const token = form.get("cf-turnstile-response");
    if (typeof token !== "string") return new Response("Falta el token", { status: 400 });
    const res = await verifyTurnstile(token, env.TURNSTILE_SECRET, req.headers.get("CF-Connecting-IP") ?? undefined);
    if (!res.success) return new Response("Verificación fallida", { status: 403 });
    return new Response("OK");
  },
} satisfies ExportedHandler<Env>;
```
`npx wrangler secret put TURNSTILE_SECRET`.

## 10. Cron + KV (cachear una API externa)

```jsonc
"triggers": { "crons": ["*/10 * * * *"] },
"kv_namespaces": [{ "binding": "CACHE", "id": "<KV_ID>" }]
```
```ts
export default {
  async scheduled(_c, env, ctx) {
    const r = await fetch("https://api.example.com/rates");
    if (!r.ok) { console.error(JSON.stringify({ message: "upstream failed", status: r.status })); return; }
    await env.CACHE.put("rates", await r.text(), { expirationTtl: 3600 });
  },
  async fetch(_req, env) {
    const rates = await env.CACHE.get("rates");
    return rates ? new Response(rates, { headers: { "content-type": "application/json" } }) : new Response("Sin datos aún", { status: 503 });
  },
} satisfies ExportedHandler<Env>;
```
Prueba local: `npx wrangler dev --test-scheduled` y luego `curl "http://localhost:8787/__scheduled?cron=*/10+*+*+*+*"`.

## 11. Validar un JWT de Cloudflare Access en el origen o en un Worker

```ts
import { createRemoteJWKSet, jwtVerify } from "jose";

export async function verifyAccess(req: Request, teamDomain: string, aud: string) {
  const token = req.headers.get("cf-access-jwt-assertion");
  if (!token) throw new Error("Sin token de Access");
  const JWKS = createRemoteJWKSet(new URL(`${teamDomain}/cdn-cgi/access/certs`));
  const { payload } = await jwtVerify(token, JWKS, { issuer: teamDomain, audience: aud });
  return payload;  // email, sub, etc.
}
```
`teamDomain` tiene la forma `https://<team>.cloudflareaccess.com`; `aud` es el Application Audience (AUD) Tag de la aplicación de Access. Crea el JWKS una sola vez a nivel de módulo si vas a validar en cada request (es caché, no estado de usuario).
