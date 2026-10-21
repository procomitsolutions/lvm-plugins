# Seguridad, red y operación de zonas

Esta sección cambia menos que la Developer Platform, pero los nombres de planes, los límites de reglas y la ubicación de opciones en el dashboard sí cambian. Verifica los detalles de plan en el `llms.txt` del producto.

## Contenido
1. Conceptos base: cuenta, zona, proxy
2. DNS
3. SSL/TLS
4. Cache / CDN
5. Rules (motor de reglas)
6. WAF, rate limiting y DDoS
7. Bots, Challenges y Turnstile
8. API Shield
9. Cloudflare One (Zero Trust)
10. Tunnel
11. Load Balancing, Spectrum, red L3
12. API, tokens e IaC
13. Troubleshooting por códigos de error

---

## 1. Conceptos base
- **Cuenta** → contiene **zonas** (dominios) y recursos de la Developer Platform.
- Alta de zona: setup completo (cambiar los nameservers a Cloudflare), parcial (CNAME, Business+) o subdominio.
- **Proxied (nube naranja)**: el tráfico pasa por Cloudflare y obtiene CDN, WAF, Workers y SSL edge. **DNS-only (nube gris)**: solo resuelve DNS y expone la IP del origen.
- Planes de zona: Free, Pro, Business, Enterprise. Son independientes del plan de Workers (Free/Paid).

## 2. DNS
Registros A, AAAA, CNAME (con flattening en el apex), MX, TXT, SRV, CAA, etc. DNSSEC con un clic (DS en el registrador). Importar y exportar en formato BIND. Para correo: registros SPF, DKIM y DMARC (y DMARC Management). 1.1.1.1 es el resolver público, distinto del DNS autoritativo.

## 3. SSL/TLS
Modos de cifrado edge→origen: **Off**, **Flexible** (HTTP al origen; causa bucles de redirección si el origen fuerza HTTPS), **Full** (HTTPS sin validar certificado), **Full (strict)** (recomendado: certificado válido o un **Origin CA** de Cloudflare). También: Universal SSL automático, certificados avanzados o personalizados, Always Use HTTPS, HSTS, TLS mínimo, Authenticated Origin Pulls (mTLS hacia el origen), mTLS de cliente y Custom Hostnames (SSL for SaaS) para dominios de clientes.

## 4. Cache / CDN
- Por defecto se cachean extensiones estáticas, no HTML. Para cachear HTML o cambiar TTLs: **Cache Rules** (eligibility, edge TTL, browser TTL, cache key). Respeta `Cache-Control` del origen según la configuración.
- Purga: por URL, por hostname, por prefijo, por cache tag (`Cache-Tag`) o todo. Desde un Worker: Cache API o `fetch(url, { cf: { cacheTtl, cacheEverything, cacheKey, cacheTags } })`.
- Tiered Cache, Cache Reserve (persistencia en R2) y Smart Shield para descargar el origen.
- Header de diagnóstico: `cf-cache-status` (HIT, MISS, EXPIRED, BYPASS, DYNAMIC).
- Tamaño máximo cacheable: 512 MB (Free/Pro/Business) y 5 GB (Enterprise).

## 5. Rules
Lenguaje de expresiones común (Ruleset Engine), estilo Wireshark:
```
(http.host eq "api.example.com" and starts_with(http.request.uri.path, "/v1/") and not ip.src in {203.0.113.0/24})
```
Campos frecuentes: `http.request.uri.path`, `http.request.method`, `http.host`, `ip.src`, `ip.src.country`, `ip.src.asnum`, `http.user_agent`, `cf.bot_management.score`, `cf.client.bot`, `http.request.headers["x"]`.
Tipos de regla: Redirect Rules (individuales y Bulk Redirects), Transform Rules (reescribir URL y modificar headers), Origin Rules (cambiar host, puerto o resolución), Configuration Rules, Cache Rules, Compression Rules, Custom Error Rules y **Snippets** (JS ligero en el edge, alternativa a un Worker para lógica simple). Page Rules están en desuso: migra a estas reglas.

## 6. WAF, rate limiting y DDoS
- **Custom rules**: acciones Block, Managed Challenge, JS Challenge, Interactive Challenge, Skip, Log. (Firewall Rules está deprecado.)
- **Managed rules**: Cloudflare Managed Ruleset y OWASP Core Ruleset (con umbral de anomalía y sensibilidad).
- **Rate limiting rules**: por IP, header, cookie, ASN, etc. Desde un Worker también existe el binding `ratelimits`.
- Leaked credentials detection; upload content scanning.
- **DDoS**: automático e incluido en todos los planes para L3/4/7; overrides de sensibilidad en los managed rulesets. Modo "Under Attack" para emergencias.

## 7. Bots, Challenges y Turnstile
- Bot Fight Mode (Free), Super Bot Fight Mode (Pro/Business), Bot Management (Enterprise, `cf.bot_management.score` 1–99, verified bots, JA3/JA4).
- **Turnstile** (alternativa a CAPTCHA, gratis):
  - Cliente: `<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>` y `<div class="cf-turnstile" data-sitekey="SITE_KEY"></div>` (se envía como `cf-turnstile-response`).
  - **Servidor (obligatorio)**: `POST https://challenges.cloudflare.com/turnstile/v0/siteverify` con `secret`, `response` y opcionalmente `remoteip`; revisa `success` (y `action`/`hostname` si aplica). Un token sirve una sola vez y expira a los 300 s.
  - Existen claves de prueba oficiales para desarrollo (ver la doc de Turnstile).

## 8. API Shield
Descubrimiento de endpoints, validación de esquema (OpenAPI), validación de JWT, mTLS, detección de abuso secuencial y volumétrico, y protección BOLA.

## 9. Cloudflare One (Zero Trust)
- **Access** (ZTNA): proteger apps self-hosted, SaaS e infraestructura (SSH, RDP) por identidad (IdP: Google, Entra ID, Okta, GitHub, OTP), postura del dispositivo, país, etc. La app recibe el JWT en el header `Cf-Access-Jwt-Assertion` y la cookie `CF_Authorization`. **Valídalo en el origen** contra `https://<team>.cloudflareaccess.com/cdn-cgi/access/certs` comprobando el AUD tag. Service tokens para máquina a máquina (`CF-Access-Client-Id` / `CF-Access-Client-Secret`). Se puede proteger un Worker, sus previews o todos los Workers de la cuenta con Access.
- **Gateway**: filtrado DNS, HTTP (SWG con inspección TLS) y de red; políticas por identidad.
- **WARP** (cliente de dispositivo), CASB, DLP, Remote Browser Isolation, Email Security, DEX, MCP server portals y AI controls.
- Patrones de migración desde VPN, SWG o SASE de otros proveedores (existe la skill oficial `cloudflare-one-migrations`).

## 10. Cloudflare Tunnel (`cloudflared`)
Conexión solo de salida, sin abrir puertos ni necesitar IP pública:
```sh
cloudflared tunnel login
cloudflared tunnel create my-tunnel
cloudflared tunnel route dns my-tunnel app.example.com
cloudflared tunnel run my-tunnel        # o con un token remoto gestionado desde el dashboard
```
Ingress en `config.yml` (hostname → `http://localhost:8080`, con un catch-all `http_status:404` al final). Combinado con Access protege apps internas; también sirve para redes privadas (WARP-to-Tunnel) y para Hyperdrive hacia bases privadas. Quick tunnels (`*.trycloudflare.com`) solo para pruebas. Wrangler tiene comandos `wrangler tunnel`.

## 11. Load Balancing, Spectrum y red L3
- Load Balancing: pools de orígenes, monitores (health checks), steering (failover, random, geo, dinámico por latencia, proximidad) y session affinity.
- Waiting Room para picos de tráfico. Argo Smart Routing para menor latencia.
- Spectrum: proxy y protección DDoS para TCP/UDP arbitrario (juegos, SSH, MQTT).
- Magic Transit (protección L3 de rangos IP propios vía BGP), Cloudflare WAN (antes Magic WAN), Network Firewall, BYOIP y Network Interconnect (CNI).

## 12. API, tokens e IaC
- REST: `https://api.cloudflare.com/client/v4/...` con `Authorization: Bearer <API_TOKEN>`. Prefiere API tokens con permisos mínimos y alcance por cuenta o zona; la Global API Key es legacy.
- Respuestas con `{ success, errors, messages, result, result_info }`; la paginación usa `page`/`per_page` o cursor según el endpoint.
- GraphQL Analytics API: `https://api.cloudflare.com/client/v4/graphql`.
- SDKs oficiales: TypeScript (`cloudflare`), Python, Go.
- Terraform (`cloudflare/cloudflare`; la v5 cambió muchos recursos, verifica la versión del usuario), Pulumi y `cf-terraforming` para importar recursos existentes.
- La CLI `cf` cubre toda la API pública (ver `workers-plataforma.md`). El MCP con Code Mode (`https://mcp.cloudflare.com/mcp`) permite que un agente opere la API.

## 13. Troubleshooting por códigos de error
| Código | Significado típico |
|---|---|
| 520 | El origen devolvió una respuesta vacía o inesperada |
| 521 | El origen rechazó la conexión (servidor caído o firewall bloqueando las IPs de Cloudflare) |
| 522 | Timeout de conexión TCP al origen |
| 523 | Origen inalcanzable (DNS o ruteo) |
| 524 | El origen tardó más de 100 s en responder (usa colas/Workflows, polling o subir el timeout en Enterprise) |
| 525 / 526 | Handshake SSL fallido / certificado de origen inválido (en modo Full strict) |
| 1000s | Errores de configuración de Cloudflare: 1001 error de resolución DNS, 1016 error de DNS del origen, 1020 bloqueado por una regla, 1101 excepción del Worker, 1102 límites del Worker, 1027 límite diario de Workers Free |
| ERR_TOO_MANY_REDIRECTS | Normalmente SSL en modo Flexible con un origen que redirige a HTTPS → usar Full (strict) |

Diagnóstico: header `cf-ray` (ID de la request), `cf-cache-status`, Trace (simulador de reglas en el dashboard), Security Events, Log Explorer y Logpush.
