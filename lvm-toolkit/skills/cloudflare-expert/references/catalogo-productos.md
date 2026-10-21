# Catálogo de productos Cloudflare

Fuente: `https://developers.cloudflare.com/llms.txt` (octubre de 2026). Cada producto tiene su índice en `https://developers.cloudflare.com/<slug>/llms.txt` y cada página tiene versión Markdown agregando `index.md` a su URL.

## Contenido
1. Developer Platform (cómputo, datos, IA, media)
2. Rendimiento de aplicaciones
3. Seguridad de aplicaciones
4. Cloudflare One (Zero Trust / SASE)
5. Seguridad de red
6. Plataforma core, IaC y operación
7. Servicios de consumo y otros
8. Herramientas para agentes de código

---

## 1. Developer Platform

### Cómputo
| Producto | Slug | Qué es |
|---|---|---|
| Workers | `workers` | Serverless en V8 isolates sobre la red global (JS/TS, Python, Rust/Wasm). Sin cold starts relevantes. |
| Static Assets | `workers/static-assets` | Hosting de frontends (SPA/SSG/SSR) dentro de un Worker. Reemplaza a Pages para proyectos nuevos. |
| Pages | `pages` | Plataforma anterior de frontends. Sigue funcionando; lo nuevo va a Workers. |
| Durable Objects | `durable-objects` | Objetos con estado, únicos globalmente, de un solo hilo, con SQLite embebido. Base de Agents, D1 y Queues. |
| Containers | `containers` | Contenedores serverless controlados desde Workers/Durable Objects. |
| Dynamic Workers | `dynamic-workers` | Crear isolates bajo demanda para ejecutar código arbitrario (Worker Loader). Base de Code Mode. |
| Sandboxes | `sandbox` | Ejecución aislada de código no confiable sobre Containers (Linux) o Dynamic Workers (JS). SDK `@cloudflare/sandbox`. |
| Queues | `queues` | Mensajería con entrega al menos una vez, batching, reintentos y DLQ. |
| Workflows | `workflows` | Ejecución durable multipaso (pasos persistidos, reintentos, sleep, esperar eventos). Puede durar días o semanas. |
| Flagship | `flagship` | Feature flags evaluados en el edge (binding y SDKs OpenFeature). |
| Browser Run | `browser-run` | Chrome headless: Quick Actions HTTP (screenshot, pdf, markdown, json, crawl), Puppeteer, Playwright, CDP, Stagehand. Antes "Browser Rendering". |
| Workers VPC | `workers-vpc` | Conectar Workers a redes privadas o nubes privadas. |
| Cloudflare for Platforms | `cloudflare-for-platforms` | Multi-tenant: Workers for Platforms (dispatch namespaces) y Custom Hostnames (SSL for SaaS). |
| Email Service | `email-service` | Envío transaccional (binding, REST, SMTP) y Email Routing entrante a Workers. |

### IA
| Producto | Slug | Qué es |
|---|---|---|
| Workers AI | `workers-ai` | Inferencia serverless en GPU (LLMs, embeddings, imagen, voz, clasificación). Binding `AI`. Incluye los modelos "Clef" de decisión (oct. 2026). |
| AI (Models) | `ai` | Catálogo unificado de modelos. |
| AI Gateway | `ai-gateway` | Proxy para cualquier proveedor de LLM: caché, rate limiting, logs, reintentos, fallback, analítica. |
| AI Search | `ai-search` | RAG totalmente gestionado (GA en oct. 2026). Antes "AutoRAG". |
| Vectorize | `vectorize` | Base de datos vectorial. |
| Agents | `agents` | Agents SDK (`agents`): agentes con estado, WebSockets, scheduling, MCP (cliente y servidor), harness "Think", Code Mode, pagos x402/MPP. |
| Agent Memory | `agent-memory` | Memoria persistente para agentes: extrae, clasifica y recupera conocimiento de conversaciones (namespaces y perfiles). |
| Wallets | `wallets` | Identidad de wallet legible para pagos agénticos. |
| AI Crawl Control | `ai-crawl-control` | Analizar y controlar crawlers de IA sobre tu sitio (incluye pay-per-crawl). |
| Agent Lee | `agent-lee` | Copiloto de IA dentro del dashboard. |

### Almacenamiento y bases de datos
| Producto | Slug | Qué es |
|---|---|---|
| KV | `kv` | Clave-valor global, consistencia eventual, lecturas muy rápidas. |
| R2 | `r2` | Almacenamiento de objetos compatible con S3, sin egress. |
| D1 | `d1` | SQL serverless (SQLite) gestionado, con read replication. Máx. 10 GB por base. |
| Hyperdrive | `hyperdrive` | Pool de conexiones y caché para Postgres/MySQL existentes. |
| Basin | `basin` | Plataforma de analítica (antes "Cloudflare Data Platform"): Basin Pipelines (`basin-pipelines`, antes Pipelines), Basin Catalog (`basin-catalog`, antes R2 Data Catalog, Iceberg REST) y Basin SQL (`basin-sql`, antes R2 SQL). |
| K2 | `k2` | Stream de eventos durable (log ordenado con suscripciones, leases, ack/nack y replay). |
| Artifacts | `artifacts` | Repositorios versionados compatibles con git para artefactos de filesystem (open beta, oct. 2026). |
| Analytics Engine | `analytics/analytics-engine` | Series de tiempo de alta cardinalidad escritas desde Workers, consultables con SQL. |
| Secrets Store | `secrets-store` | Secretos a nivel de cuenta reutilizables como binding. |

### Media
| Producto | Slug | Qué es |
|---|---|---|
| Images | `images` | Almacenar, transformar y servir imágenes (binding y URLs `/cdn-cgi/image/`). |
| Stream | `stream` | Video: subida, codificación, entrega, live y Media Transformations. |
| Realtime | `realtime` | RealtimeKit, SFU (WebRTC) y TURN. |
| MoQ | `moq` | Media over QUIC para video en vivo. |

## 2. Rendimiento de aplicaciones
| Producto | Slug | Qué es |
|---|---|---|
| Cache / CDN | `cache` | Caché global, Cache Rules, purga, Tiered Cache, Cache Reserve. |
| Speed | `speed` | Optimizaciones: Brotli, Early Hints, HTTP/3, Rocket Loader, Observatory. |
| DNS | `dns` | DNS autoritativo, proxy (nube naranja), DNSSEC, CNAME flattening. |
| SSL/TLS | `ssl` | Certificados edge y de origen, modos de cifrado, mTLS. |
| Load Balancing | `load-balancing` | Balanceo con health checks, steering geográfico y por latencia. |
| Smart Shield | `smart-shield` | Protección y descarga del origen. |
| Argo Smart Routing | `argo-smart-routing` | Enrutamiento por las rutas más rápidas de la red. |
| Waiting Room | `waiting-room` | Sala de espera virtual para picos de tráfico. |
| Spectrum | `spectrum` | Proxy y protección para cualquier TCP/UDP. |
| Health Checks | `health-checks` | Monitoreo de orígenes. |
| Web Analytics | `web-analytics` | Analítica sin cookies y Core Web Vitals. |
| Zaraz | `zaraz` | Ejecutar scripts de terceros en el edge. |
| Automatic Platform Optimization | `automatic-platform-optimization` | Optimización para WordPress. |
| China Network | `china-network` | Entrega dentro de China. |
| Google tag gateway | `google-tag-gateway` | Servir Google Tag Manager desde tu dominio. |
| Web3 | `web3` | Gateways IPFS y Ethereum. |

## 3. Seguridad de aplicaciones
| Producto | Slug | Qué es |
|---|---|---|
| WAF | `waf` | Reglas gestionadas, custom rules, rate limiting, credenciales filtradas. |
| DDoS Protection | `ddos-protection` | Mitigación automática L3/4/7. |
| Bots | `bots` | Bot Fight Mode, Super Bot Fight Mode, Bot Management (bot score). |
| Challenges | `cloudflare-challenges` | Desafíos gestionados e interstitial. |
| Turnstile | `turnstile` | Alternativa a CAPTCHA (widget + validación Siteverify en el servidor). |
| API Shield | `api-shield` | Descubrimiento de APIs, validación de esquemas, mTLS, JWT validation. |
| Client-side security / Page Shield | `client-side-security`, `page-shield` | Monitoreo de scripts del lado del cliente. |
| Security Center | `security-center` | Postura de seguridad e insights. |
| Firewall Rules | `firewall` | DEPRECADO: usar WAF custom rules. |
| DMARC Management | `dmarc-management` | Reportes DMARC y protección de dominio de correo. |
| Key Transparency | `key-transparency` | Auditoría de claves públicas para E2EE. |

## 4. Cloudflare One (Zero Trust / SASE)
| Producto | Slug | Qué es |
|---|---|---|
| Cloudflare One | `cloudflare-one` | Access (ZTNA), Gateway (SWG/DNS), WARP, CASB, DLP, Browser Isolation, Email Security, MCP server portals. |
| Cloudflare Tunnel | `tunnel` | `cloudflared`: conectar orígenes sin IP pública ni puertos abiertos. |
| Cloudflare Mesh | `mesh` | Red mesh cifrada post-cuántica entre servicios y dispositivos. |
| Cloudflare WAN | `cloudflare-wan` | Antes Magic WAN. |
| Cloudflare Network Firewall | `cloudflare-network-firewall` | Firewall como servicio (antes Magic Firewall). |
| Multi-Cloud Networking | `multi-cloud-networking` | Descubrimiento y red entre nubes públicas. |
| Data Localization Suite | `data-localization` | Controlar dónde se almacenan e inspeccionan los datos. |
| WARP Client | `warp-client` | Cliente de dispositivo. |

## 5. Seguridad de red
Magic Transit (`magic-transit`), BYOIP (`byoip`), Network Interconnect (`network-interconnect`), Network Flow (`network-flow`), Network Error Logging (`network-error-logging`).

## 6. Plataforma core, IaC y operación
| Producto | Slug | Qué es |
|---|---|---|
| Fundamentals | `fundamentals` | Cuentas, zonas, API tokens, conceptos generales. |
| API | `api` | Referencia REST: `https://api.cloudflare.com/client/v4/...`. |
| Terraform / Pulumi | `terraform`, `pulumi` | Infraestructura como código. |
| Cloudflare CLI (`cf`) | `cf` | CLI unificada (beta) para toda la API pública más proyectos Workers. |
| Rules | `rules` | Transform, Redirect, Origin, Configuration, Cache, Compression y Snippets. |
| Ruleset Engine | `ruleset-engine` | Lenguaje de expresiones común a las reglas. |
| Logs / Logpush / Log Explorer | `logs`, `log-explorer` | Exportar y explorar logs. |
| Analytics | `analytics` | GraphQL Analytics API, dashboards. |
| Notifications | `notifications` | Alertas. |
| Registrar | `registrar` | Dominios a precio de costo. |
| Monetization Gateway | `monetization-gateway` | Cobrar por acceso a APIs, herramientas MCP, páginas o datasets. |
| Tenant | `tenant` | Aprovisionar cuentas para equipos o clientes. |
| Version Management | `version-management` | Versionado y staging de configuración de zona. |
| Resource Tagging | `resource-tagging` | Metadatos clave-valor en recursos. |
| Reference Architecture | `reference-architecture` | Diagramas y guías de arquitectura. |
| Migration Guides | `migration-guides` | Migrar desde otros proveedores. |

## 7. Servicios de consumo y otros
1.1.1.1 (`1.1.1.1`), Radar (`radar`), Time Services (`time-services`), Randomness Beacon (`randomness-beacon`), Privacy Gateway, Privacy Pass, Privacy Proxy.

## 8. Herramientas para agentes de código
- **Cloudflare Skills** (`github.com/cloudflare/skills`): bundle oficial de skills (agents-sdk, durable-objects, workers-best-practices, wrangler, cloudflare-email-service, cloudflare-one, nextjs-on-cloudflare, sandbox-*, turnstile-spin, web-perf). En Claude Code se instala con `/plugin marketplace add cloudflare/skills` y luego `/plugin install cloudflare@cloudflare`.
- **MCP de la API completa (Code Mode)**: `https://mcp.cloudflare.com/mcp`. Expone solo `search()` y `execute()` para más de 2.500 endpoints en unos 1.000 tokens.
- **MCP por dominio**: documentación `https://docs.mcp.cloudflare.com/mcp`, bindings `https://bindings.mcp.cloudflare.com/mcp`, observabilidad `https://observability.mcp.cloudflare.com/mcp`, builds `https://builds.mcp.cloudflare.com/mcp`, Browser Run `https://browser.mcp.cloudflare.com/mcp`, Radar `https://radar.mcp.cloudflare.com/mcp`, AI Gateway `https://ai-gateway.mcp.cloudflare.com/mcp`, audit logs `https://auditlogs.mcp.cloudflare.com/mcp`, DNS analytics `https://dns-analytics.mcp.cloudflare.com/mcp`, Logpush `https://logs.mcp.cloudflare.com/mcp`, containers `https://containers.mcp.cloudflare.com/mcp`, CASB, DEX.
- **Docs para agentes**: `/llms.txt` global y por producto, más `index.md` por página.
