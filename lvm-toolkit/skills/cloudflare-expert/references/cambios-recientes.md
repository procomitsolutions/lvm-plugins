# Cambios recientes, renombres y deprecaciones (snapshot de octubre de 2026)

Revisa esta lista antes de escribir código. Tu conocimiento previo y muchos ejemplos de internet pueden usar la forma antigua. Si el usuario tiene código antiguo, no lo rompas: explica la diferencia y ofrece migrarlo.

| Tema | Antes | Ahora | Acción |
|---|---|---|---|
| Servidores MCP | `McpAgent` (`MyMCP.serve("/mcp")`), `experimental_createMcpHandler`, SDK v1 `@modelcontextprotocol/sdk` | `createMcpHandler(factory)` de `agents/mcp/server` + MCP SDK v2 `@modelcontextprotocol/server` (stateless) | Código nuevo con `createMcpHandler`. `McpAgent` está deprecado y congelado. `createLegacyMcpHandler` solo como puente temporal. |
| OAuth para MCP | Workers OAuth Provider 0.x | `@cloudflare/workers-oauth-provider` v1 (API separada, step-up auth, spec MCP 2026-07-28) | Verifica la API v1 antes de escribir el código. |
| Clases de Durable Objects | Array `migrations` con `tag` y `new_sqlite_classes` | Campo declarativo `exports` (`{ "Clase": { "type": "durable-object", "storage": "sqlite" } }`) | Ambos funcionan, pero son excluyentes. `exports` es lo recomendado; una vez adoptado no se vuelve atrás. La guía rápida de Agents todavía muestra `migrations`. |
| Backend de Durable Objects | KV-backed | SQLite-backed | Ya no se pueden crear namespaces KV nuevos (salvo cuentas que ya tengan uno). |
| Durable Objects sin cliente | Eviction al terminar el request | Con compat date ≥ 2026-10-01, el I/O pendiente evita la eviction hasta 15 min | Útil para trabajo largo sin cliente conectado. |
| WebSockets en DO | Llamar `ws.close()` en `webSocketClose` | Con compat date ≥ 2026-04-07 el runtime responde solo a los frames Close | Llamar `close()` sigue siendo seguro. |
| Analítica de datos | Cloudflare Data Platform: Pipelines, R2 Data Catalog, R2 SQL | **Basin**: Basin Pipelines, Basin Catalog, Basin SQL (GA) | Comandos `wrangler basin ...`. Los recursos antiguos siguen funcionando. Ingesta hasta 1 GB/s por stream. |
| Navegador headless | Browser Rendering | **Browser Run** | Mismas capacidades más CDP, Live View, Stagehand, Kitesurf. La API REST sigue bajo `browser_rendering`. |
| RAG gestionado | AutoRAG | **AI Search** (GA, precio por uso) | — |
| Frontends | Cloudflare Pages | **Workers + Static Assets** | Pages funciona, pero lo nuevo va a Workers. Hay guía de migración. |
| Hosting estático en Workers | Workers Sites | Static Assets | No usar Workers Sites en proyectos nuevos. |
| Firewall | Firewall Rules | WAF custom rules | Firewall Rules está deprecado. |
| Reglas de zona | Page Rules | Redirect, Transform, Origin, Cache y Configuration Rules | Migrar. |
| Testing | `@cloudflare/vitest-pool-workers`, `unstable_dev`, Miniflare 2 | `@cloudflare/vitest-plugin` (Vitest 4), `createTestHarness` | Hay guías de migración. |
| CLI | Solo Wrangler | Wrangler + **`cf`** (beta, toda la API, `cloudflare.config.ts`) | No ejecutar `cf dev/build/deploy` sin `cf migrate`. Wrangler sigue siendo lo estándar. |
| Sandboxes | `@cloudflare/sandbox` 0.x (clase `Sandbox`, `exec()`, `exposePort()`, `mountBucket()`, `createBackup()`) | SDK 1.0: un Durable Object propio que arranca su container; `container.exec()`, `Files`, `DirectoryBackup`, `S3Mount` | Pregunta la versión. La 0.12 tiene guía de migración y el deploy de migración es irreversible. |
| Next.js | `@cloudflare/next-on-pages` | **vinext** u **OpenNext** (`@opennextjs/cloudflare`) | next-on-pages es legacy. |
| Correo | Email Routing separado; envío con `EmailMessage` y MIME crudo | **Email Service** unificado (envío + routing); `env.EMAIL.send({ to, from, subject, html })` | `EmailMessage` queda como legacy. |
| WAN | Magic WAN, Magic Firewall | Cloudflare WAN, Cloudflare Network Firewall | Renombres. |
| Workers AI | — | Modelos "Clef" y "Clef-flash" (decisión tipada con probabilidades, Apache 2.0) | Verifica IDs con `wrangler ai models`. |
| Productos nuevos 2026 | — | Flagship (feature flags), K2 (event stream), Artifacts (repos git, open beta), Agent Memory, Wallets, Monetization Gateway, Cloudflare Mesh, Workers VPC, Dynamic Workers, Workers Issues, Previews | Ver `catalogo-productos.md`. |
| Planes de Workers | Bundled / Unbound | Workers Free / Workers Paid | Bundled y Unbound ya no existen para cuentas nuevas. |
| CPU en Paid | 30 s máximo | 30 s por defecto, configurable hasta 5 min (`limits.cpu_ms`) | — |
| Subrequests en Paid | 1.000 | 10.000 por defecto (hasta 10M configurable) | — |
| Static Assets | 20.000 archivos | 100.000 en Paid (requiere Wrangler ≥ 4.34.0) | — |
| Wrangler | v3 | v4 (requisitos nuevos de Node y otros defaults) | Guía "Migrate from Wrangler v3 to v4". |

## Cómo detectar código desactualizado en lo que comparte el usuario
- `addEventListener("fetch", ...)` → formato Service Worker; migrar a ES Modules (`export default { fetch }`).
- `McpAgent` / `MyMCP.serve()` / `MyMCP.mount()` → MCP con el modelo deprecado.
- `migrations` + `new_classes` (sin `sqlite`) → DO con backend KV legacy.
- `[site]` en wrangler.toml → Workers Sites.
- `@cloudflare/next-on-pages`, `functions/` de Pages → stack de Pages.
- `env.AI.run` con modelos viejos (`@cf/meta/llama-2-...`) → verificar catálogo.
- `wrangler publish`, `wrangler generate` → comandos de Wrangler v1/v2.
