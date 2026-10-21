# Asegurar aplicaciones: OIDC, OAuth 2, SAML y flujos avanzados

## Contenido
1. Endpoints OIDC del realm
2. Tipos de cliente y configuración recomendada
3. Grants: cuál usar
4. Estructura de los tokens y claims
5. Validar tokens en APIs (ejemplos por lenguaje)
6. SPAs con keycloak-js
7. Frameworks backend (Spring, Quarkus, Node, .NET, Python, proxies)
8. Logout y sesiones
9. SAML
10. Token exchange V2 y delegación
11. JWT Authorization Grant, federated client auth, ID-JAG
12. DPoP, PAR, mTLS, FAPI, OAuth 2.1
13. Device flow, CIBA, offline tokens
14. MCP (Model Context Protocol)
15. Client registration dinámico
16. Errores comunes

## 1. Endpoints (base `https://<host>/realms/<realm>`)

| Uso | Ruta |
|---|---|
| Discovery OIDC | `/.well-known/openid-configuration` |
| Metadata OAuth (RFC 8414) | `https://<host>/.well-known/oauth-authorization-server/realms/<realm>` (inserción de path; por eso el proxy debe exponer `/.well-known/` en la raíz) y `/realms/<realm>/.well-known/oauth-authorization-server` |
| Authorization | `/protocol/openid-connect/auth` |
| Token | `/protocol/openid-connect/token` |
| UserInfo | `/protocol/openid-connect/userinfo` |
| JWKS | `/protocol/openid-connect/certs` |
| Introspection (solo confidenciales) | `/protocol/openid-connect/token/introspect` |
| Revocación (RFC 7009) | `/protocol/openid-connect/revoke` |
| Logout (RP-initiated) | `/protocol/openid-connect/logout` |
| PAR | `/protocol/openid-connect/ext/par/request` |
| Device authorization | `/protocol/openid-connect/auth/device` |
| CIBA | `/protocol/openid-connect/ext/ciba/auth` |
| Registro dinámico | `/clients-registrations/openid-connect` |
| SAML (IdP) | `/protocol/saml` ; descriptor `/protocol/saml/descriptor` |
| Account Console | `/account` |
| Issuer (`iss`) | `https://<host>/realms/<realm>` (sin `/auth` desde KC 17) |

## 2. Tipos de cliente (Admin Console → Clients → Create client)

| Tipo de app | Client authentication | Flows | Extra |
|---|---|---|---|
| SPA / móvil / desktop / CLI | OFF (público) | Standard flow | PKCE S256 (Advanced → *Proof Key for Code Exchange Code Challenge Method*), redirect URIs exactas, Web origins |
| Web server-side / BFF | ON (confidencial) | Standard flow | PKCE recomendado; secret o `private_key_jwt` |
| API (resource server) que solo valida tokens | puede ni ser cliente; si se crea: ON, sin flows | — | Se usa como audiencia (`aud`) |
| Servicio a servicio | ON | Service accounts roles | Asignar roles al service account |
| Dispositivo sin navegador | ON u OFF | OAuth 2.0 Device Authorization Grant | |

Buenas prácticas: deshabilitar *Direct access grants* e *Implicit flow*; redirect URIs sin `*` amplio (en producción solo `https`; para apps nativas `http://127.0.0.1` con cualquier puerto); `Front channel logout`/`Backchannel logout URL` si la app mantiene sesión; *Client secret rotation* vía client policy (supported 26.8); *Lightweight access token* si los tokens son grandes.

Autenticación de clientes confidenciales: `client_secret_basic`/`post`, `client_secret_jwt`, `private_key_jwt` (JWKS URL o certificado), `tls_client_auth` (X.509), federada (JWT de K8s service account u OIDC externo, supported 26.6). Secretos en vault: `${vault.key}` (26.6).

## 3. Grants: cuál usar

| Grant | Uso | Estado |
|---|---|---|
| Authorization Code + PKCE | Todo login interactivo | Recomendado |
| Client Credentials | Máquina a máquina | Recomendado |
| Refresh Token | Renovar | Rotación configurable (Realm settings → Tokens → *Revoke refresh token*) |
| Device Authorization (RFC 8628) | TVs, CLIs | Supported |
| CIBA | Autenticación desacoplada (banca) | Supported (feature `ciba`) |
| Token Exchange (RFC 8693) | Propagar/reducir tokens | V2 supported |
| JWT Authorization Grant (RFC 7523) | Aserciones JWT externas → token | Supported (26.6) |
| Password (Direct Access Grants) | Solo legacy/tests | **No usar** (RFC 9700) |
| Implicit | — | **No usar** |

Ejemplo client credentials:
```bash
curl -s -X POST "https://auth.ejemplo.com/realms/demo/protocol/openid-connect/token" \
  -d grant_type=client_credentials -d client_id=svc-a -d client_secret="$SECRET"
```

## 4. Tokens y claims

Access token (JWT RS256 por defecto; algoritmo configurable por realm/cliente, también ES256, PS256, EdDSA). Claims típicos: `iss`, `sub` (ID del usuario), `aud`, `azp` (cliente), `exp`, `iat`, `jti`, `sid`, `scope`, `typ` (`Bearer`), `preferred_username`, `email`, `email_verified`, `name`, `realm_access.roles`, `resource_access.<clientId>.roles`, `acr`, `allowed-origins`.

- **Audiencia**: por defecto `aud` incluye clientes cuyos roles aparecen en el token (*audience resolve*). Para que una API reciba su `aud`, crea un client scope o mapper **Audience** (Included Client Audience = id de la API). Sin `aud` correcto, las librerías estándar rechazan el token.
- **Roles en otro formato** (p. ej. `roles` plano para Spring): mapper *User Realm Role* / *User Client Role* con *Token Claim Name* `roles`, multivalued.
- **Grupos**: mapper *Group Membership* (claim `groups`, *Full group path* opcional).
- **Atributos**: *User Attribute* mapper (atributo debe existir en el User Profile).
- **Client scopes por defecto**: `openid` implícito, `profile`, `email`, `roles`, `web-origins`, `acr`, `basic` (sub, auth_time), opcionales `offline_access`, `address`, `phone`, `microprofile-jwt`, `organization`. Probar en Clients → *client* → Client scopes → **Evaluate** (genera access/ID token/userinfo de ejemplo).
- Vida útil por defecto: access token 5 min; SSO Session Idle 30 min; SSO Session Max 10 h (Realm settings → Sessions/Tokens; overridable por cliente en Advanced).
- Lightweight access token: `always use lightweight access token` en el cliente; mappers marcan *Add to lightweight access token*.

## 5. Validar tokens en APIs

Valida localmente: firma con JWKS (cachea por `kid`, refresca ante `kid` desconocido), `iss` exacto, `exp`/`nbf` con pequeño skew, `aud` contiene tu API, y opcionalmente `azp`, `scope`, roles. Usa introspección (cliente confidencial) solo si necesitas revocación inmediata o tokens opacos.

**Node.js (jose)**:
```js
import { createRemoteJWKSet, jwtVerify } from 'jose';
const ISSUER = 'https://auth.ejemplo.com/realms/demo';
const JWKS = createRemoteJWKSet(new URL(`${ISSUER}/protocol/openid-connect/certs`));
export async function verify(token) {
  const { payload } = await jwtVerify(token, JWKS, { issuer: ISSUER, audience: 'orders-api' });
  return payload; // payload.realm_access?.roles
}
```

**Python (PyJWT)**:
```python
import jwt
from jwt import PyJWKClient
ISSUER = "https://auth.ejemplo.com/realms/demo"
jwks = PyJWKClient(f"{ISSUER}/protocol/openid-connect/certs")
def verify(token: str) -> dict:
    key = jwks.get_signing_key_from_jwt(token).key
    return jwt.decode(token, key, algorithms=["RS256"], audience="orders-api", issuer=ISSUER)
```

**Introspección**:
```bash
curl -s -u orders-api:$SECRET -d "token=$AT" \
  https://auth.ejemplo.com/realms/demo/protocol/openid-connect/token/introspect
```

## 6. SPAs con keycloak-js

Paquete npm `keycloak-js` (ciclo de release propio desde 26.x; ya no se sirve desde el servidor; compatible con servidores soportados). Requiere `new`, API con Promises, PKCE S256 por defecto.

```js
import Keycloak from 'keycloak-js';
const keycloak = new Keycloak({ url: 'https://auth.ejemplo.com', realm: 'demo', clientId: 'web' });

const authenticated = await keycloak.init({
  onLoad: 'check-sso',                       // o 'login-required'
  silentCheckSsoRedirectUri: `${location.origin}/silent-check-sso.html`,
  pkceMethod: 'S256',
});

async function api(url) {
  await keycloak.updateToken(30);            // refresca si expira en <30 s
  return fetch(url, { headers: { Authorization: `Bearer ${keycloak.token}` } });
}
keycloak.onTokenExpired = () => keycloak.updateToken(30);
// keycloak.login(), keycloak.logout({ redirectUri }), keycloak.register(), keycloak.accountManagement()
// keycloak.hasRealmRole('admin'), keycloak.hasResourceRole('editor', 'web'), keycloak.tokenParsed
```
`silent-check-sso.html`: `<html><body><script>parent.postMessage(location.href, location.origin)</script></body></html>`. Las cookies de terceros bloqueadas pueden romper el check-sso silencioso en iframe; alternativa: `onLoad: 'check-sso'` sin silent (redirige) o patrón BFF. Para alta seguridad prefiere BFF (tokens fuera del navegador). Alternativas: `oidc-client-ts`, `react-oidc-context`, `angular-auth-oidc-client`.

## 7. Frameworks backend

- **Spring Boot 3 (resource server)**: `spring.security.oauth2.resourceserver.jwt.issuer-uri=https://auth.ejemplo.com/realms/demo` (+ validador de audiencia propio y `JwtAuthenticationConverter` que lea `realm_access.roles`). **Login web**: `spring.security.oauth2.client.provider.keycloak.issuer-uri` + `registration.keycloak.client-id/secret/scope=openid`. No existe adaptador Keycloak para Spring (eliminado).
- **Quarkus**: `quarkus-oidc` (`quarkus.oidc.auth-server-url=https://auth.ejemplo.com/realms/demo`, `quarkus.oidc.client-id`, `application-type=service|web-app|hybrid`); `quarkus-keycloak-authorization` para Authorization Services; Dev Services levanta Keycloak automáticamente.
- **Node.js**: `openid-client` (login), `jose` (validar), `express-openid-connect`; el adaptador `keycloak-connect` sigue documentado (`/securing-apps/nodejs-adapter`).
- **.NET**: `Microsoft.AspNetCore.Authentication.JwtBearer` (`Authority` = issuer, `Audience`) y `OpenIdConnect` para web.
- **Python**: Authlib, `python-keycloak`, `fastapi` + PyJWT.
- **Go**: `coreos/go-oidc`.
- **WildFly/EAP**: Elytron OIDC (`oidc.json`); SAML con Galleon feature pack de Keycloak.
- **Proxies/gateways**: oauth2-proxy, Apache `mod_auth_openidc`, NGINX (njs/Plus), Traefik (forward auth/Hub), Envoy (jwt_authn), Kong, APISIX, KrakenD.

## 8. Logout y sesiones

- **RP-initiated logout**: redirigir a `/protocol/openid-connect/logout?id_token_hint=<id_token>&post_logout_redirect_uri=<uri registrada>` (o `client_id` en vez de `id_token_hint`). La URI debe estar en *Valid post logout redirect URIs* (`+` = mismas que redirect URIs). Sin parámetros, Keycloak muestra página de confirmación.
- **Backchannel logout** (recomendado): configurar *Backchannel logout URL* en el cliente; Keycloak envía un `logout_token` firmado (claim `sid`).
- **Front-channel logout**: iframes; frágil con bloqueo de cookies.
- Invalidar todo: Admin Console → Sessions, o `POST /admin/realms/{realm}/users/{id}/logout`. *Not before* (revocation) en Realm/Clients.
- Error `temporarily_unavailable` + `authentication_expired`: la sesión de autenticación de esa pestaña expiró; reintenta el login (SSO lo resolverá).

## 9. SAML

- Keycloak como IdP: crear cliente SAML con `Client ID` = Entity ID del SP; *Master SAML Processing URL* o ACS por binding; firmar documentos/aserciones; *Name ID format*; mappers (role list, user attribute, X500). Importar metadata del SP (Create client → import). Metadata del IdP: `/realms/<realm>/protocol/saml/descriptor`.
- Keycloak como SP de otro IdP SAML: Identity Providers → SAML v2.0 (importar metadata URL; gestión automática de certificados desde 24/26.4).
- Step-up authentication SAML (supported 26.7) vía AuthnContextClassRef ↔ ACR.
- Clientes: `mod_auth_mellon`, Galleon feature pack para WildFly/EAP, Spring Security SAML2, SimpleSAMLphp.

## 10. Token exchange V2 (RFC 8693) y delegación

Requisitos: cliente que pide = **confidencial** con switch *Standard token exchange* ON; el `subject_token` debe tener a ese cliente en `aud` (o haber sido emitido a él).

```bash
curl -s -u gateway:$SECRET -X POST https://auth.ejemplo.com/realms/demo/protocol/openid-connect/token \
  -d grant_type=urn:ietf:params:oauth:grant-type:token-exchange \
  -d subject_token="$AT" \
  -d subject_token_type=urn:ietf:params:oauth:token-type:access_token \
  -d requested_token_type=urn:ietf:params:oauth:token-type:access_token \
  -d audience=orders-api
```
- `scope` = agrega optional scopes del cliente que pide (upscoping); `audience` (repetible) = filtra/downscopea audiencias y roles. Para forzar solo downscoping: executor `downscope-assertion-grant-enforcer` en una client policy.
- `requested_token_type=...:refresh_token` solo si *Allow refresh token in Standard Token Exchange* ≠ No. ID token también posible.
- No soporta clientes públicos, ni parámetro `resource`, ni impersonación de otro sujeto (eso solo en V1, deprecado). Nunca crea sesión de usuario nueva. Revocar el token original revoca la cadena de refresh tokens intercambiados (no los access tokens).
- **Delegación** (preview, `--features=token-exchange-delegation,parameterized-scopes`): el usuario consiente `scope=openid delegation:client:<actor>` (o `delegation:user:<admin>`); el token lleva `may_act`; el actor (confidencial, service account, TE habilitado) hace el exchange enviando `subject_token` + `actor_token` y recibe un token con claim `act` (sesión transitoria, sin refresh). Autorización exclusivamente con FGAP v2 (scope `delegate` en Users o `delegate-members` en Groups). El cliente que pide el scope necesita *Consent required*. Executor `may-act` para revalidar. Caso de uso: agentes de IA actuando por el usuario.
- Impersonación por admin: tokens con claim `act` (26.8) y eventos con `impersonator`.
- Interno → externo (token de un IdP federado): usar **Identity Brokering API v2** (endpoint POST, cliente confidencial con *Allow retrieve external tokens*), no TE v1.

## 11. JWT Authorization Grant y relacionados

- **JWT Authorization Grant (RFC 7523, supported 26.6)**: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=<JWT externo>`; confianza configurada en un IdP OIDC (sección dedicada) o el IdP tipo *JWT Authorization Grant*. Reemplaza external→internal TE v1. Combinado con TE V2 implementa *Identity & Authorization Chaining across domains*.
- **Federated client authentication** (supported 26.6): el cliente se autentica con una aserción de un emisor de confianza (IdP OIDC o tokens de service account de Kubernetes) — sin client secrets en Keycloak. SPIFFE sigue en preview.
- **ID-JAG** (experimental `identity-assertion-jwt`): solo rol de AS receptor.

## 12. DPoP, PAR, mTLS, FAPI, OAuth 2.1

- **DPoP** (supported 26.4): el cliente envía header `DPoP` (JWT de prueba); tokens con `cnf.jkt`. Forzar por cliente: Advanced → *Require DPoP bound tokens*, o executor `dpop-bind-enforcer`. Recomendado para clientes públicos.
- **PAR**: `POST /protocol/openid-connect/ext/par/request` → `request_uri`; forzar con *Pushed authorization request required*.
- **mTLS certificate-bound tokens**: Advanced → *OAuth 2.0 Mutual TLS Certificate Bound Access Tokens Enabled* (requiere TLS cliente hasta Keycloak: passthrough o lookup de certificado).
- **Client Policies**: perfiles globales `fapi-1-baseline`, `fapi-1-advanced`, `fapi-ciba`, `fapi-2-security-profile`, `fapi-2-dpop-security-profile`, `fapi-2-message-signing`, `fapi-2-dpop-message-signing`, `oauth-2-1-for-confidential-client`, `oauth-2-1-for-public-client`. Se asignan con políticas (condiciones: client-roles, client-access-type, any-client, client-scope, grant-type, client-attribute…).

## 13. Device flow, CIBA, offline tokens

- Device: `POST /protocol/openid-connect/auth/device` (`client_id`) → `device_code`, `user_code`, `verification_uri_complete`; luego polling `grant_type=urn:ietf:params:oauth:grant-type:device_code`. Habilitar *OAuth 2.0 Device Authorization Grant* en el cliente.
- CIBA: requiere authenticator externo (HTTP binding) configurado en Realm → Authentication → Policies → CIBA.
- Offline tokens: `scope=offline_access` (rol `offline_access`); sesiones offline persistidas en BD; *Offline Session Max Limited* para caducidad.

## 14. MCP (Model Context Protocol)

Keycloak como Authorization Server de servidores MCP:
- MCP 2025-03-26: supported sin configuración especial.
- 2025-06-18, 2025-11-25 y 2026-07-28: experimental. Requieren audiencia ligada al servidor MCP:
  - Sin `resource-indicators`: client scopes opcionales (`mcp:tools`, `mcp:prompts`, `mcp:resources`) con *Audience mapper* (*Included Custom Audience* = URL del servidor MCP, igual al parámetro `resource`).
  - Con `--features=resource-indicators` (RFC 8707): configurar atributo `resource_url` en el cliente del servidor MCP; `aud` = valor de `resource`; error `invalid_target` si no coincide.
- Registro de clientes: **CIMD** (`--features=cimd`, Client ID Metadata Document) con client policy: condición `client-id-uri` (scheme `https`, dominios de confianza) + perfil con executor `client-id-metadata-document` (Trusted domains, Restrict same domain, Only allow confidential, Accept public client with confidential-only grant types, Resource indicator allow list). También DCR (RFC 7591) o pre-registro.
- Recetas oficiales: VS Code (dominios `vscode.dev`, `127.0.0.1`, `code.visualstudio.com`; Restrict same domain OFF), Claude Code (`claude.ai`, `localhost`, `127.0.0.1`; Restrict same domain OFF), Claude Desktop (`claude.ai`; Restrict same domain ON; Accept public client with confidential-only grant types ON). Si usas Claude Code y Desktop a la vez, un solo perfil combinado. ChatGPT no es compatible (usa `token_endpoint_auth_methods_supported`).
- MCP Inspector: Client Registration → anonymous access policies (Allowed client scopes, Allowed registration web origins, Trusted hosts).
- Ajustes SPI de CIMD: `--spi-client-policy-executor--client-id-metadata-document--min-cache-time|max-cache-time|upper-limit-metadata-bytes`.

## 15. Client registration

- OIDC DCR: `POST /realms/<realm>/clients-registrations/openid-connect` con *Initial Access Token* (Clients → Initial access token) o anónimo según *Client registration policies* (Trusted hosts, Allowed scopes, Max clients…). Respuesta incluye `registration_access_token` para actualizar.
- CLI `kcreg.sh` para automatizar registro (`/securing-apps/client-registration-cli`).

## 16. Errores comunes

| Error | Causa | Arreglo |
|---|---|---|
| `invalid_redirect_uri` / "Invalid parameter: redirect_uri" | URI no registrada | Registrar URI exacta |
| `unauthorized_client` "Client not enabled to retrieve service account" | Service accounts OFF | Activar en el cliente |
| `invalid_client` | Secret/método de autenticación incorrecto | Revisar Credentials → Client authenticator |
| `invalid_grant` "Code not valid" | Código reusado/expirado, redirect_uri distinto entre auth y token | Un solo canje, mismo redirect_uri |
| `invalid_grant` "Session not active" | Refresh tras expirar SSO Session Idle/Max | Ajustar timeouts o re-login |
| `invalid_scope` | Scope no asignado al cliente / delegación sin consent required | Asignar como default/optional |
| API devuelve 401 "invalid audience" | Falta Audience mapper | Agregar mapper Audience |
| `iss` no coincide | Front vs back URL | `--hostname` URL fija; validar con issuer público |
| PKCE "Missing parameter: code_challenge_method" | Cliente exige PKCE | Enviar `code_challenge` S256 |
| CORS | Web origins | Agregar origen o `+` |
| `access_denied` en token exchange | Cliente no está en `aud` del subject token | Audience mapper hacia el cliente que intercambia |
