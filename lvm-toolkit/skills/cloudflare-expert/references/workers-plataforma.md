# Workers: plataforma, configuración, runtime y CLI

Docs: `https://developers.cloudflare.com/workers/llms.txt`

## Contenido
1. Crear y desplegar
2. `wrangler.jsonc`: estructura y bindings
3. Handlers y runtime
4. Routing: custom domains vs routes vs workers.dev
5. Entornos, versiones y despliegues
6. Límites (Free vs Paid)
7. Errores comunes
8. Observabilidad
9. Testing y desarrollo local
10. CI/CD
11. Wrangler vs la nueva CLI `cf`
12. Lenguajes y frameworks

---

## 1. Crear y desplegar

```sh
npm create cloudflare@latest my-app     # C3: elige una plantilla o framework
cd my-app
npx wrangler dev                        # local (workerd + Miniflare)
npx wrangler deploy                     # a producción
npx wrangler types                      # genera worker-configuration.d.ts con Env
npx wrangler tail                       # logs en vivo
```

Proyecto existente: `npx wrangler deploy` detecta el framework y autoconfigura (ver "Deploy an existing project"). Plantillas: `npm create cloudflare@latest -- --template <org/repo/path>`.

## 2. `wrangler.jsonc`

```jsonc
{
  "$schema": "./node_modules/wrangler/config-schema.json",
  "name": "my-worker",
  "main": "src/index.ts",
  "compatibility_date": "2026-10-01",          // fecha de hoy en proyectos nuevos
  "compatibility_flags": ["nodejs_compat"],
  "observability": { "enabled": true, "logs": { "head_sampling_rate": 1 }, "traces": { "enabled": true, "head_sampling_rate": 0.01 } },
  "placement": { "mode": "smart" },             // opcional: Smart Placement, acerca el Worker a sus backends
  "limits": { "cpu_ms": 30000 },                // Paid: hasta 300000

  "vars": { "API_BASE_URL": "https://api.example.com" },   // NO secretos aquí

  "assets": { "directory": "./dist", "binding": "ASSETS", "not_found_handling": "single-page-application" },
  "routes": [{ "pattern": "api.example.com", "custom_domain": true }],
  "triggers": { "crons": ["*/15 * * * *"] },

  // Bindings (cada uno se vuelve env.<NOMBRE>)
  "kv_namespaces":   [{ "binding": "KV", "id": "<KV_ID>" }],
  "r2_buckets":      [{ "binding": "BUCKET", "bucket_name": "my-bucket" }],
  "d1_databases":    [{ "binding": "DB", "database_name": "my-db", "database_id": "<D1_ID>", "migrations_dir": "migrations" }],
  "hyperdrive":      [{ "binding": "HYPERDRIVE", "id": "<HYPERDRIVE_ID>" }],
  "durable_objects": { "bindings": [{ "name": "ROOM", "class_name": "ChatRoom" }] },
  "exports":         { "ChatRoom": { "type": "durable-object", "storage": "sqlite" } },  // ver cambios-recientes.md
  "queues": {
    "producers": [{ "binding": "JOBS", "queue": "jobs" }],
    "consumers": [{ "queue": "jobs", "max_batch_size": 10, "max_batch_timeout": 5, "max_retries": 3, "dead_letter_queue": "jobs-dlq" }]
  },
  "workflows":       [{ "name": "order-flow", "binding": "ORDER_FLOW", "class_name": "OrderFlow" }],
  "ai":              { "binding": "AI" },
  "vectorize":       [{ "binding": "VECTORIZE", "index_name": "docs-idx" }],
  "services":        [{ "binding": "AUTH", "service": "auth-worker", "entrypoint": "AuthService" }],
  "analytics_engine_datasets": [{ "binding": "METRICS", "dataset": "metrics" }],
  "send_email":      [{ "name": "EMAIL" }],
  "flagship":        [{ "binding": "FLAGS", "app_id": "<APP_ID>" }],
  "browser":         { "binding": "BROWSER" },
  "ratelimits":      [{ "name": "RATE_LIMITER", "namespace_id": "1001", "simple": { "limit": 100, "period": 60 } }]
}
```

Notas:
- `wrangler.toml` sigue siendo válido; la doc muestra ambos formatos. Prefiere JSONC en proyectos nuevos.
- Los IDs se obtienen al crear el recurso: `wrangler kv namespace create`, `wrangler d1 create`, `wrangler r2 bucket create`, `wrangler queues create`, `wrangler hyperdrive create`, `wrangler vectorize create`.
- Sintaxis de bindings menos comunes (ratelimits, browser, mTLS, Secrets Store, dispatch namespaces, Worker Loader): verifica en `workers/wrangler/configuration/index.md`.
- Variables y secretos: máx. 64 (Free) o 128 (Paid) por Worker, 5 KB cada uno.

## 3. Handlers y runtime

```ts
import { WorkerEntrypoint, DurableObject } from "cloudflare:workers";

export default {
  async fetch(request, env, ctx) { return new Response("ok"); },
  async scheduled(controller, env, ctx) { /* cron */ },
  async queue(batch, env, ctx) { for (const m of batch.messages) { /* ... */ m.ack(); } },
  async email(message, env, ctx) { await message.forward("me@example.com"); },
  async tail(events, env, ctx) { /* Tail Worker */ },
} satisfies ExportedHandler<Env>;
```

APIs del runtime: Fetch, Request/Response, Headers, Streams (Readable/Writable/TransformStream), Web Crypto, WebSockets, HTMLRewriter (reescribir HTML en streaming), Cache API (`caches.default`), TCP sockets (`connect()` de `cloudflare:sockets`), `scheduler.wait()`, EventSource, MessageChannel, WebAssembly. Con `nodejs_compat`: `node:crypto`, `buffer`, `stream`, `async_hooks` (AsyncLocalStorage), `net`, `tls`, `http`/`https`, `fs` (virtual), `zlib`, `dns` (DoH), `process`, `path`, `util`, `events`, `timers`.

`ctx`: `waitUntil()`, `passThroughOnException()` (evitar), `props` (datos pasados por el llamador vía service binding o OAuth), `exports` (stubs a tus propias entrypoints).

Objeto `request.cf`: país, ciudad, ASN, colo, `botManagement`, versión TLS, etc. Útil para geolocalización y A/B.

RPC: exporta clases que extiendan `WorkerEntrypoint` y llámalas vía service binding como métodos tipados (`await env.AUTH.verifyToken(t)`). Lo mismo aplica a Durable Objects (`stub.miMetodo()`). Se pueden pasar funciones, streams y `RpcTarget`.

Workers Cache (`workers/cache`): caché de respuestas del propio Worker con purga por tag o prefijo vía `ctx.cache.purge()`.

## 4. Routing

- **Custom Domain** (`{ "pattern": "api.example.com", "custom_domain": true }`): el Worker ES el origen; Cloudflare crea el DNS y el certificado. Usarlo cuando el Worker atiende todo el hostname.
- **Route** (`{ "pattern": "shop.example.com/*", "zone_name": "example.com" }`): el Worker corre DELANTE de un origen. Requiere un registro DNS proxied (nube naranja). Sin origen real, usa un AAAA a `100::` proxied. Olvidar el DNS da `ERR_NAME_NOT_RESOLVED`.
- **workers.dev**: `<worker>.<subdominio>.workers.dev`, ideal para pruebas.
- Un `fetch()` global a otro Worker de la misma zona falla: usa service bindings.
- Límites: 1.000 routes por zona, 100 custom domains por zona.

## 5. Entornos, versiones y despliegues

- **Entornos Wrangler**: `env.staging`, `env.production` → Workers distintos llamados `{name}-{env}`. Bindings y `vars` NO se heredan (decláralos en cada entorno). El Worker raíz es otro despliegue más: si no lo usas, despliega siempre con `--env`.
- **Versiones**: `wrangler versions upload` (sube sin activar) → `wrangler versions deploy` (gradual, p. ej. 10/90). También hay version affinity, version overrides, version URLs y `wrangler rollback`.
- **Previews**: copias aisladas por rama o PR (Workers Builds, GitHub Actions u otro CI).
- **Durable Objects**: los cambios de ciclo de vida (crear, borrar o renombrar clases) solo se aplican con `wrangler deploy`, no con `versions upload`, y no admiten despliegue gradual.

## 6. Límites (Free / Paid)

| | Free | Paid |
|---|---|---|
| Requests | 100.000/día (error 1027 al superarlo) | sin límite |
| CPU por request HTTP | 10 ms | 30 s por defecto, configurable hasta 5 min (`limits.cpu_ms`) |
| CPU por Cron | 10 ms | 30 s (intervalo < 1 h) / 15 min (≥ 1 h) |
| Memoria por isolate | 128 MB | 128 MB |
| Subrequests por invocación | 50 | 10.000 por defecto (configurable hasta 10M) |
| Conexiones simultáneas esperando headers | 6 | 6 |
| Tamaño del Worker (sin comprimir) | 64 MiB | 64 MiB |
| Startup (scope global) | 1 s | 1 s |
| Workers por cuenta | 100 | 500 (más con Workers for Platforms) |
| Cron Triggers por cuenta | 5 | 250 |
| Archivos de Static Assets por versión | 20.000 | 100.000 (25 MiB por archivo) |

- Duración (wall time): HTTP sin límite mientras el cliente siga conectado; `waitUntil` hasta 30 s después de la respuesta; Cron, Queue consumer y alarmas de DO, 15 min; pasos de Workflows sin límite de wall time.
- Request body según plan de la zona: Free/Pro 100 MB, Business 200 MB, Enterprise hasta 5 GB. URL 16 KB; headers 128 KB.
- Cache API: objetos de hasta 512 MB; 50 (Free) o 1.000 (Paid) llamadas por request.
- Logs: 256 KB por request.
- El tiempo de espera de red (fetch, KV, D1) NO cuenta como CPU. El Worker promedio usa unos 2,2 ms de CPU.

## 7. Errores comunes

| Síntoma | Causa | Solución |
|---|---|---|
| Error 1102 "Worker exceeded resource limits" (`exceededCpu` / `exceededMemory`) | CPU o memoria | Subir `cpu_ms` (Paid), perfilar con DevTools, hacer streaming en vez de buffering, mover datos a KV/R2/D1 |
| Error 1027 | Límite diario Free | Pasar a Paid; configurar fail open o fail closed en la route |
| `Cannot perform I/O on behalf of a different request` | Estado o objetos de I/O guardados en el scope global | Pasar el estado por argumentos |
| `Illegal invocation` | Desestructurar `ctx` (`const { waitUntil } = ctx`) | Llamar `ctx.waitUntil(...)` |
| `Script startup exceeded CPU time limit` (10021) | Trabajo pesado en el scope global | Mover la inicialización al handler o al build; `wrangler check startup` |
| `Memory limit would be exceeded before EOF` | `await res.text()` sobre un cuerpo enorme | Streaming |
| `ERR_NAME_NOT_RESOLVED` con una route | Falta el registro DNS proxied | Crear el registro (o AAAA a `100::`) o usar custom domain |
| Imports de Node fallan | Falta `nodejs_compat` | Agregar el flag y una `compatibility_date` reciente |
| Memoria alta con Zod | Versiones viejas | Zod ≥ 4.5.0 |

## 8. Observabilidad

Workers Logs (activar `observability`), Query Builder, Traces automáticos con spans custom, Workers Issues (agrupa fallos recurrentes y permite automatizaciones hacia agentes de código o webhooks), `wrangler tail`, Tail Workers, Logpush, export OpenTelemetry (Axiom, Grafana, Honeycomb, Sentry, PostHog), source maps (`upload_source_maps: true`), DevTools (breakpoints y perfiles de CPU y memoria).

## 9. Testing y desarrollo local

- `wrangler dev` (local por defecto). Remote bindings: `"remote": true` en un binding concreto para usar el recurso real desde local.
- `.dev.vars` o `.env` para secretos locales. Local Explorer para ver los datos locales de los bindings en el navegador.
- Vite: `@cloudflare/vite-plugin` (recomendado con frameworks; incluye entornos Vite y HMR).
- Tests: `@cloudflare/vitest-plugin` (reemplaza a `@cloudflare/vitest-pool-workers`): `import { env } from "cloudflare:workers"` dentro de los tests. También `createTestHarness` de Wrangler para integración y Miniflare como API de bajo nivel.
- Compartir el servidor local con un túnel público: "Share a local dev server".

## 10. CI/CD

- **Workers Builds**: integración con GitHub, GitLab o Cursor; build en cada push, ramas de preview, watch paths para monorepos, deploy hooks, caché de build y suscripción a eventos.
- **CI externo**: GitHub Actions o GitLab con `CLOUDFLARE_API_TOKEN` y `CLOUDFLARE_ACCOUNT_ID`.
- Botón "Deploy to Cloudflare": `https://deploy.workers.cloudflare.com/?url=<repo>`.
- IaC: Terraform (`cloudflare_workers_script` y recursos afines), Pulumi o los SDKs de la API.

## 11. Wrangler vs `cf` (CLI unificada, beta)

`cf` cubre toda la API pública (más de 2.900 comandos) y proyectos Workers.

| | Wrangler | cf |
|---|---|---|
| Login | `wrangler login` | `cf auth login` (credenciales propias) |
| Config | `wrangler.jsonc` / `.toml` | `cloudflare.config.ts` (TypeScript tipado) |
| Entornos | `--env` | `--mode` |
| Identificadores | nombres (p. ej. nombre de la D1) | IDs que espera la API |
| Salida | tablas; `--json` en algunos comandos | JSON en la mayoría |
| Datos | algunos comandos son locales por defecto | remoto por defecto; `--local` solo en KV, D1 y R2 |

Ejemplo: `wrangler d1 execute my-db --remote --command "SELECT 1"` equivale a `cf d1 query <DATABASE_ID> --sql "SELECT 1"`.

Reglas:
- `cf d1 list`, `cf r2 buckets list` y demás comandos de recursos funcionan en cualquier directorio, pero NO leen el `account_id` de Wrangler: define `CLOUDFLARE_ACCOUNT_ID`.
- **No ejecutes `cf dev`, `cf build` ni `cf deploy` en un proyecto Wrangler sin migrar**: la autoconfiguración puede reescribir `package.json`, generar configs incorrectas o desplegar un Worker sin tu código ni tus bindings. Primero `cf migrate --dry-run` y luego `cf migrate`.
- Tras migrar quedan tareas manuales: migraciones de DO, Workflows, Containers y scripts.
- Todavía requiere Wrangler para: logs en vivo (`npx wrangler tail`) y setear un secreto individual.
- Ambos leen `CLOUDFLARE_API_TOKEN` y `CLOUDFLARE_ACCOUNT_ID` en CI.

## 12. Lenguajes y frameworks

- JS/TS (principal), Python (Pyodide; paquetes con pywrangler; FastAPI, Flask, Django, LangChain), Rust (`workers-rs`), otros vía Wasm.
- Frameworks con guía oficial: React + Vite, React Router, Next.js (vinext u OpenNext), Astro, SvelteKit, Nuxt, Vue, Angular, Qwik, Solid, TanStack Start, RedwoodSDK, Hono, Vike, Waku, Gatsby, Docusaurus, Analog, y microfrontends con un router Worker.
- Migraciones con guía oficial: Pages → Workers, Vercel → Workers, Netlify → Workers.
