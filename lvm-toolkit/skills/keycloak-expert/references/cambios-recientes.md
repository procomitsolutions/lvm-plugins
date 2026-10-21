# Cambios recientes, eliminaciones y trampas por versión

Fuente: release notes 26.0 → 26.8 y notas previas relevantes. Antes de responder sobre un upgrade concreto, lee además el Upgrading Guide (`/docs/latest/upgrading/`), que lista los cambios incompatibles por versión.

## Tabla de "esto ya no es así"

| Lo viejo (tutoriales/entrenamiento) | Lo actual |
|---|---|
| Distribución WildFly, `standalone.xml`, `jboss-cli` | Distribución Quarkus (`kc.sh`, `keycloak.conf`) desde 17; WildFly eliminada en 20 |
| URLs con `/auth/realms/...` | `/realms/...`; legacy con `--http-relative-path=/auth` |
| `KEYCLOAK_ADMIN` / `KEYCLOAK_ADMIN_PASSWORD` | `KC_BOOTSTRAP_ADMIN_USERNAME` / `KC_BOOTSTRAP_ADMIN_PASSWORD` (26.0), admin temporal; `kc.sh bootstrap-admin` |
| `--proxy=edge|reencrypt|passthrough` | **Eliminado** (26.0). `--proxy-headers=xforwarded|forwarded`, `--proxy-trusted-addresses`, `--proxy-protocol-enabled` |
| `--hostname-url`, `--hostname-admin-url`, `--hostname-port`, `--hostname-path`, `--hostname-strict-https`, `--hostname-strict-backchannel` | **Eliminados** (hostname v1, 26.0). Hostname v2: `--hostname` (URL), `--hostname-admin`, `--hostname-backchannel-dynamic`, `--hostname-strict` |
| Adaptadores Java Keycloak (Spring Boot, Tomcat, Jetty, Undertow, Fuse) | Eliminados (25). Spring Security / Quarkus OIDC / Elytron OIDC |
| `keycloak.js` servido desde `/js/keycloak.js` | npm `keycloak-js` standalone (26.0), ciclo de release propio (26.1), PKCE por defecto, solo Promises nativas, requiere `new` |
| Account Console v1/v2 | Account Console v3 (React) |
| Admin Console vieja (AngularJS) | Nueva Admin Console (eliminada la vieja en 21) |
| Login theme `keycloak` (PF4) por defecto | `keycloak.v2` (PF5) por defecto (26.0) |
| `--cache-stack=kubernetes` (DNS_PING), UDP multicast | `jdbc-ping` por defecto (26.1); los demás stacks deprecados |
| Sesiones de usuario en memoria (se pierden al reiniciar) | Persistentes en BD por defecto (26.0); modo volátil deprecado (26.8) |
| Login failures (brute force) en caché | En BD por defecto (26.8); `login-failures:v1` deprecado |
| Sticky sessions recomendadas | Ya no aportan (26.6); opciones deprecadas en 26.8 |
| Token exchange `--features=token-exchange` + FGAP | Standard token exchange V2 habilitado por defecto (26.2); V1 deprecado |
| Fine-grained admin permissions v1 (permisos en cada objeto) | FGAP v2 supported (26.2), sección central *Permissions* |
| Multi-site con Infinispan externo | Multi-cluster v2 `stateless` supported (26.8); `multi-site` deprecado |
| GELF logging | Eliminado (26.0) → syslog/JSON/OTel |
| Hashicorp Vault provider | Eliminado (21); vault `file`/`keystore` o Vault SPI propio |
| Upload de scripts JS por la consola | Eliminado (18); JS empaquetado como JAR |
| Map Storage | Eliminado (23) |
| Operator legacy (`keycloak.org/v1alpha1`, `KeycloakRealm`, `KeycloakClient`, `KeycloakUser`) | Nuevo Operator `k8s.keycloak.org/v2beta1` (`Keycloak`, `KeycloakRealmImport`, `KeycloakOIDCClient`, `KeycloakSAMLClient`) |
| CR con `apiVersion: k8s.keycloak.org/v2alpha1` | Docs actuales usan `v2beta1` (algunos ejemplos aún muestran v2alpha1; preferir v2beta1) |
| Opciones SPI `--spi-x-y-z` con guion simple | Separador `--` entre spi, provider y propiedad (`--spi-x--y--z`) |
| Java 11/17 | OpenJDK 21 o 25 (25 desde 26.6). Imagen oficial con 21 (por FIPS) |
| Identity providers dentro de la representación del realm | Ya no están en `RealmRepresentation` vía Admin API (26.0): usar endpoints de identity providers |
| `UserRepresentation.origin` | Deprecado (26.0) |
| Actualización parcial de atributos de usuario vía PUT | No soportada desde 24.0.4: enviar todos los atributos |
| Búsqueda por atributo case-insensitive | Case-sensitive desde 25 |
| `Require Discoverable Credential` (WebAuthn) | `Discoverable credential: required/preferred/discouraged` (26.7) |
| Introspección con `Accept: application/jwt` | Deprecado → usar token exchange |
| Identity Brokering API v1 (rol `broker.read-token`) | v2 (26.7 supported, deshabilitada por defecto): POST, cliente confidencial, *Allow retrieve external tokens* |
| `robots.txt` servido por Keycloak | Eliminado (26.1) |
| OpenShift v3 identity broker | Eliminado (26.1) |

## Novedades por versión (resumen)

- **26.0**: Organizations supported; sesiones persistentes por defecto; nuevo login theme; multi-site HA; bootstrap admin/recovery; JS adapter standalone; hostname v1 eliminado; `--proxy` eliminado; `proxy-trusted-addresses`, `proxy-protocol-enabled`; lightweight tokens en Admin API; Protostream; varias instancias de un mismo social provider.
- **26.1**: `jdbc-ping` por defecto; virtual threads en Infinispan/JGroups; OpenTelemetry tracing supported; `prompt=create`; minimum ACR por cliente; DPoP binding del code; nuevos conditional authenticators; dependencias entre provider factories; NetworkPolicy en Operator.
- **26.2**: Standard Token Exchange supported; FGAP v2 supported; guías de métricas/Grafana; mTLS automático entre nodos; rolling updates para imágenes optimizadas; métricas de eventos; logs ECS; selección dinámica de flow por client policy; SMTP XOAUTH2.
- **26.3**: recuperación de cuenta 2FA; import/export más rápidos; passkeys en formularios por defecto; brokering con OAuth2 genérico; trusted email en brokering OIDC; logging asíncrono; rolling updates de patch (preview).
- **26.4**: Passkeys, FAPI 2 Final y DPoP supported; EdDSA en FIPS; management por HTTP; health en puerto principal; access log HTTP; ServiceMonitor automático; `tlsSecret` en ingress del CR; datasources adicionales supported; email domain opcional en organizations.
- **26.5**: Workflows (preview); JWT Authorization Grant (preview); guía MCP; mejoras CORS; página de confirmación de logout; ocultar scopes del discovery; evento `USER_SESSION_DELETED`; OTel métricas/logs; MDC logging supported; `--features` unificado; Windows service; ppc64le.
- **26.6**: JWT Authorization Grant, federated client auth, Workflows, zero-downtime patch releases y Test Framework **supported**; Identity Brokering API v2 preview; CIMD experimental; grupos de organización; secretos de cliente vía Vault; Java 25; opciones DB TLS/timeouts; graceful shutdown; prefijo `KCRAW_`; truststore automático en K8s; cert lookup Traefik/Envoy; rotación de logs configurable; access log en archivo propio.
- **26.7**: SCIM (preview); multi-cluster v2 (preview); guías HAProxy/Traefik; step-up SAML supported; Identity Brokering API v2 supported; Admin API v2 experimental; FGAP para organizations; roles en grupos de organización; WebAuthn discoverable credential; SSF, AuthZEN, ID-JAG y TE delegation experimentales; Operator con kustomize y modo cluster-wide (preview).
- **26.8** (actual): OID4VCI preview (+ OID4VP experimental); SSF RISC; parameterized scopes preview; **TE delegation preview** (`delegation:client:<id>`, claim `act`); claim `act` en impersonación; executor `secure-client-node-hostname` (anti-SSRF, opt-in); Admin API v2 clients preview + CRs de clientes preview; Client Secret Rotation supported; workflow `invite-user`; allow-list de protocol mappers; SCIM supported; multi-cluster v2 supported y v1 deprecado; PEM cifrado para TLS; login failures en BD; `--cache-embedded-cluster-name`/`--cache-embedded-node-name`; índices no bloqueantes automáticos; cliente HTTP saliente Vert.x experimental; Helm chart del Operator experimental; IdPs compartidos entre organizaciones (nuevos links por defecto *Unmanaged*); botones de IdP rediseñados en el login (revisar temas custom).

## Procedimiento de upgrade (resumen)

1. Leer upgrading guide de cada versión saltada y release notes.
2. Backup de BD (y export si se quiere).
3. Revisar opciones eliminadas/deprecadas en la config (warnings al arrancar), temas custom (`.ftl` sobrescritos) y providers (recompilar contra la nueva versión).
4. Probar en staging con copia de BD de producción (la migración puede tardar con tablas grandes; ver `transaction-setup-timeout`).
5. Patch releases: rolling update; minor/major: recreate salvo que `update-compatibility check` diga lo contrario.
6. Actualizar librerías cliente (`keycloak-js`, admin client) según su matriz de compatibilidad.
