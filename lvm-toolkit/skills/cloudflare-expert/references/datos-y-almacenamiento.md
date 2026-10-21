# Datos y almacenamiento

## Contenido
1. Tabla de elección
2. KV
3. R2
4. D1
5. Durable Objects
6. Hyperdrive
7. Queues
8. Workflows
9. Analytics Engine
10. Basin (Pipelines, Catalog, SQL)
11. K2
12. Artifacts
13. Flagship
14. Secrets Store

---

## 1. Tabla de elección

| Necesidad | Producto | Ideal para |
|---|---|---|
| Clave-valor de lectura masiva | KV | Config, sesiones, routing, A/B |
| Objetos / blobs | R2 | Assets, uploads, datasets, logs |
| SQL ligero gestionado | D1 | Usuarios, productos, pedidos (lectura intensiva) |
| Postgres o MySQL existente | Hyperdrive | Bases grandes (1 TB+), ORMs y drivers existentes |
| Coordinación con estado | Durable Objects | Chat, juegos, colaboración, estado por tenant, consistencia fuerte |
| Tareas en segundo plano | Queues | Emails, webhooks, batching |
| Procesos multipaso durables | Workflows | Pagos → envío → notificación; aprobaciones humanas |
| Vectores | Vectorize | Búsqueda semántica y RAG |
| Ingesta de streams para analítica | Basin Pipelines | Clickstream, telemetría |
| Métricas de series de tiempo | Analytics Engine | Facturación por uso, métricas por cliente |
| Log de eventos con replay | K2 | Pub-sub con múltiples lectores e historial |
| Repos versionados tipo git | Artifacts | Código y archivos generados por agentes |
| Feature flags | Flagship | Rollouts y targeting |

**D1 vs SQLite en Durable Objects**: D1 es una base gestionada (HTTP API, migraciones, import/export, query insights) y se accede por red. SQLite en DO es un bloque de bajo nivel: el código corre en la misma máquina que la base, permite una base por usuario o tenant y ofrece serialización estricta, pero requiere construir más tooling propio. Precios y límites SQL son equivalentes.

## 2. KV

- Consistencia eventual (los cambios pueden tardar unos 60 s en propagarse globalmente). Límite de 1 escritura por segundo por clave. Lecturas de claves "calientes" en 500 µs–10 ms.
- No sirve para contadores ni para datos que requieran read-after-write global: para eso usa Durable Objects.

```ts
await env.KV.put("user:42", JSON.stringify(data), { expirationTtl: 3600, metadata: { v: 1 } });
const user = await env.KV.get<User>("user:42", { type: "json", cacheTtl: 60 });
const { keys, list_complete, cursor } = await env.KV.list({ prefix: "user:" });
await env.KV.delete("user:42");
```
CLI: `wrangler kv namespace create CACHE`, `wrangler kv key put --binding=CACHE k v`.

## 3. R2

- Compatible con S3 (endpoint `https://<ACCOUNT_ID>.r2.cloudflarestorage.com`), sin costos de egress, consistencia fuerte por objeto. Buckets públicos vía `r2.dev` (solo para pruebas) o dominio propio (con caché). Presigned URLs vía la API S3 (p. ej. `aws4fetch`). Event notifications hacia Queues, lifecycle rules, Super Slurper y Sippy para migraciones, y jurisdicciones (EU, FedRAMP).

```ts
await env.BUCKET.put(key, request.body, { httpMetadata: { contentType: request.headers.get("content-type") ?? "application/octet-stream" } });
const obj = await env.BUCKET.get(key);            // null si no existe
if (!obj) return new Response("Not found", { status: 404 });
const headers = new Headers(); obj.writeHttpMetadata(headers); headers.set("etag", obj.httpEtag);
return new Response(obj.body, { headers });
// También: head(), delete(), list({ prefix, cursor }), createMultipartUpload()
```
CLI: `wrangler r2 bucket create my-bucket`, `wrangler r2 object put my-bucket/key --file ./f`.

## 4. D1

- SQLite gestionado, 10 GB máximo por base (escala horizontalmente con varias bases, p. ej. una por tenant). Read replication con la Sessions API para consistencia secuencial. Time Travel (restore a un punto en el tiempo), HTTP API y query insights.

```ts
const user = await env.DB.prepare("SELECT * FROM users WHERE id = ?").bind(id).first<User>();
const { results } = await env.DB.prepare("SELECT * FROM posts WHERE author = ?").bind(id).all<Post>();
await env.DB.prepare("INSERT INTO users (email) VALUES (?)").bind(email).run();
await env.DB.batch([stmt1, stmt2]);              // transaccional
```
Usa siempre `.bind()` (nunca interpoles strings en SQL).

Migraciones:
```sh
npx wrangler d1 create my-db
npx wrangler d1 migrations create my-db init     # crea migrations/0001_init.sql
npx wrangler d1 migrations apply my-db --local
npx wrangler d1 migrations apply my-db --remote  # producción
npx wrangler d1 execute my-db --remote --command "SELECT count(*) FROM users"
```
ORMs: Drizzle y Prisma (con adaptador D1).

## 5. Durable Objects

- Cada ID corresponde a una única instancia en el mundo, de un solo hilo, con almacenamiento SQLite propio y transaccional (también expone una API KV síncrona sobre SQLite). Point-in-Time Recovery de 30 días. Alarms para despertarse en el futuro. WebSocket Hibernation.
- Disponible en Free (solo backend SQLite) y Paid.

```ts
import { DurableObject } from "cloudflare:workers";

export class Counter extends DurableObject<Env> {
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    ctx.blockConcurrencyWhile(async () => {
      this.ctx.storage.sql.exec("CREATE TABLE IF NOT EXISTS hits (ts INTEGER)");
    });
  }
  async increment(): Promise<number> {                   // método RPC
    this.ctx.storage.sql.exec("INSERT INTO hits VALUES (?)", Date.now());
    return this.ctx.storage.sql.exec<{ n: number }>("SELECT count(*) AS n FROM hits").one().n;
  }
  async alarm() { /* trabajo programado con setAlarm() */ }
}

// Worker
const stub = env.COUNTER.getByName("user-123");          // o idFromName/newUniqueId + get
const n = await stub.increment();
```

Configuración (forma actual, declarativa con `exports`):
```jsonc
"durable_objects": { "bindings": [{ "name": "COUNTER", "class_name": "Counter" }] },
"exports": { "Counter": { "type": "durable-object", "storage": "sqlite" } }
```
- Las operaciones destructivas se declaran con `state`: `"deleted"`, `"renamed"` (+`renamed_to`), `"transferred"` (+`transferred_to`) o `"expecting-transfer"` (+`transfer_from`). Borrar una clase elimina TODOS sus datos de forma permanente.
- Renombrar sin downtime: 3 despliegues (alias en el código → tombstone `renamed` → quitar alias).
- `exports` y `migrations` son mutuamente excluyentes para DO; una vez que pasas a `exports` no puedes volver.
- El array `migrations` con `new_sqlite_classes` sigue soportado (es "legacy") y aparece en muchos ejemplos, incluida la guía rápida de Agents. Para migrar: `new_sqlite_classes` → `storage: "sqlite"` y `new_classes` → `storage: "legacy-kv"`.
- Ya no se pueden crear namespaces nuevos con backend KV en cuentas que no tengan uno.

Reglas de diseño ("Rules of Durable Objects", resumen): modela un DO por unidad de coordinación (sala, documento, usuario), no un DO global (se convierte en cuello de botella); usa `blockConcurrencyWhile` solo para la inicialización; guarda en storage lo que deba sobrevivir a la eviction; usa alarms en vez de `setTimeout` largos; trata los errores `retryable` y `overloaded`. Desde la compatibility date 2026-10-01, el I/O pendiente evita la eviction hasta 15 min sin cliente conectado.

## 6. Hyperdrive

Pool regional de conexiones cerca de tu base, más caché de queries. Crea un `Client` nuevo por request y requiere `nodejs_compat`.
```sh
npx wrangler hyperdrive create my-pg --connection-string="postgres://user:pass@host:5432/db"
```
```ts
import { Client } from "pg";
const client = new Client({ connectionString: env.HYPERDRIVE.connectionString });
await client.connect();
const { rows } = await client.query("SELECT id, name FROM users LIMIT 10");
```
Compatible con `pg`, `postgres` (postgres.js), `mysql2`, Drizzle y Prisma. Proveedores con guía oficial: Neon, Supabase, PlanetScale, Xata, AWS RDS/Aurora, GCP y Azure. Para bases privadas: Hyperdrive + Cloudflare Tunnel o Workers VPC.

## 7. Queues

Entrega al menos una vez, batching, reintentos por mensaje, dead letter queue, delays, pull consumers por HTTP y sin costo de egress.
```ts
await env.JOBS.send({ orderId }, { delaySeconds: 30 });
await env.JOBS.sendBatch([{ body: a }, { body: b }]);

export default {
  async queue(batch: MessageBatch<{ orderId: string }>, env: Env) {
    for (const msg of batch.messages) {
      try { await process(msg.body); msg.ack(); }
      catch { msg.retry({ delaySeconds: 60 }); }
    }
  },
} satisfies ExportedHandler<Env>;
```
CLI: `wrangler queues create jobs`. El consumer tiene un límite de 15 min de wall time. Los consumers deben ser idempotentes.

## 8. Workflows

Motor de ejecución durable: cada `step.do` persiste su resultado; si falla, solo se reintenta ese paso. Pausas de horas o semanas.
```ts
import { WorkflowEntrypoint, WorkflowStep, WorkflowEvent } from "cloudflare:workers";

type Params = { orderId: string };
export class OrderFlow extends WorkflowEntrypoint<Env, Params> {
  async run(event: WorkflowEvent<Params>, step: WorkflowStep) {
    const charge = await step.do("charge card", { retries: { limit: 5, delay: "10 seconds", backoff: "exponential" }, timeout: "2 minutes" },
      async () => chargeCard(event.payload.orderId));
    await step.sleep("wait before shipping", "1 hour");
    const approval = await step.waitForEvent<{ ok: boolean }>("manager approval", { type: "approval", timeout: "7 days" });
    if (approval.payload.ok) await step.do("ship", async () => ship(charge.id));
  }
}
// Desde un Worker:
const instance = await env.ORDER_FLOW.create({ id: orderId, params: { orderId } });
await (await env.ORDER_FLOW.get(orderId)).sendEvent({ type: "approval", payload: { ok: true } });
```
Reglas de Workflows: pasos idempotentes y deterministas; no guardes estado fuera de `step.do` (el `run` puede re-ejecutarse); devuelve desde cada paso datos serializables y pequeños; nombres de paso estables. Verifica el detalle en `workflows/build/rules-of-workflows/index.md`.

## 9. Analytics Engine

```ts
env.METRICS.writeDataPoint({ blobs: [customerId, path], doubles: [latencyMs], indexes: [customerId] });
```
Se consulta con la SQL API (HTTP). Ideal para facturación por uso y métricas por cliente. Cardinalidad ilimitada.

## 10. Basin

Plataforma de analítica sobre R2 con tablas Apache Iceberg (GA en oct. 2026; antes "Cloudflare Data Platform").
- **Basin Pipelines** (antes Pipelines): ingesta por HTTP o binding, transformaciones SQL y escritura en tablas Iceberg o archivos en R2. Hasta 1 GB/s por stream. `npx wrangler basin pipelines setup`.
- **Basin Catalog** (antes R2 Data Catalog): catálogo Iceberg REST con compactación y expiración de snapshots automáticas. `npx wrangler basin catalog enable <BUCKET>`. Compatible con Spark, DuckDB, Trino, Snowflake, PyIceberg, etc.
- **Basin SQL** (antes R2 SQL): OLAP distribuido sin clusters. `npx wrangler basin sql query <WAREHOUSE> "SELECT * FROM default.events LIMIT 10"`.
- Los recursos y configuraciones existentes con los nombres anteriores siguen funcionando. La facturación está activa en cuentas no-enterprise.

## 11. K2

Stream de eventos durable (log). Producir no bloquea por lectores lentos; varios lectores independientes; replay histórico según la retención (TTL).
- **Records**: `content` binario (base64 en HTTP) y `headers` opcionales string→string; máx. 1 MB.
- **Producir**: endpoint HTTP (con o sin auth) o binding de Worker.
- **Suscripciones**: cada suscripción recibe todo el stream; varios consumidores comparten una suscripción para repartir la carga. Posición inicial `earliest` o `latest`.
- **Leases**: `POST .../consume` entrega mensajes con un lease de 5 minutos; `ack` o `nack`; los mensajes con nack o lease vencido se reentregan.
- K2 vs Queues: K2 para pub-sub o replay y múltiples consumidores independientes; Queues para colas de trabajo simples con Workers como consumer.

## 12. Artifacts (open beta)

Repositorios versionados y compatibles con git (git-over-HTTPS) para artefactos de filesystem, organizados en namespaces (por entorno o tenant). Acceso por binding de Worker, REST API, Wrangler (`wrangler artifacts ...`) o cualquier cliente git. Incluye ArtifactFS (montar repos grandes sin clonar), importar repos, build y deploy on push (también a Workers for Platforms), suscripción a eventos, data localization y tokens con alcance por repo. Casos típicos: workspaces de agentes de código y sandboxes.

## 13. Flagship

```jsonc
"flagship": [{ "binding": "FLAGS", "app_id": "<APP_ID>" }]
```
```ts
const on = await env.FLAGS.getBooleanValue("new-checkout", false, { userId });
// También getStringValue, getNumberValue, getObjectValue y variantes *Details (reason, errorCode)
```
- Apps → flags → variantes → targeting rules (11 operadores, anidamiento) → rollouts porcentuales con hashing consistente (sticky).
- Los cambios se propagan globalmente en segundos. Si la evaluación falla, devuelve el valor por defecto.
- Fuera de Workers: `@cloudflare/flagship` (OpenFeature) para Node, navegador, Python y Go, con un token que tenga permiso "Flagship Evaluate". Dentro de un Worker, pasa el binding al provider (`new FlagshipServerProvider({ binding: env.FLAGS })`).
- CLI: `wrangler flagship ...`.

## 14. Secrets Store

Secretos a nivel de cuenta compartidos entre Workers vía binding (`wrangler secrets-store ...`). Úsalo cuando varios Workers necesiten la misma credencial; para secretos de un solo Worker basta `wrangler secret put`.
