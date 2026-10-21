# Catálogo de documentación de Keycloak (26.8.0)

Mapa de toda la documentación oficial para ubicar rápido la fuente correcta. URL base de guías: `https://www.keycloak.org/`. Los "docs" largos (server_admin, server_development, authorization_services, upgrading, release_notes) viven en `https://www.keycloak.org/docs/latest/<guía>/index.html` (o `/docs/26.8.0/...` para fijar versión). Archivo de versiones viejas: `https://www.keycloak.org/documentation-archive.html`. Nightly: anteponer `/nightly/` a la ruta de una guía.

## Contenido
1. Guías por categoría
2. Documentación extensa (docs)
3. APIs
4. Features: nombres, estado y cómo habilitarlas
5. Integraciones externas documentadas

## 1. Guías por categoría

### Getting started
| Guía | URL |
|---|---|
| OpenJDK (zip) | /getting-started/getting-started-zip |
| Docker | /getting-started/getting-started-docker |
| Podman | /getting-started/getting-started-podman |
| Kubernetes | /getting-started/getting-started-kube |
| OpenShift | /getting-started/getting-started-openshift |
| Escalado y tuning (sizing CPU/memoria) | /getting-started/getting-started-scaling-and-tuning |

### Server
| Guía | URL |
|---|---|
| Configuring Keycloak (fuentes, formatos, build/optimized) | /server/configuration |
| Supported configurations (Java, BD, plataformas) | /server/supported-configurations |
| Configuring for production | /server/configuration-production |
| Bootstrapping and recovering an admin account | /server/bootstrap-admin-recovery |
| Directory structure | /server/directory-structure |
| Running in a container | /server/containers |
| Configuring TLS | /server/enabletls |
| Configuring the hostname (v2) | /server/hostname |
| Configuring a reverse proxy (+ blueprints HAProxy/Traefik) | /server/reverseproxy, /server/haproxy-passthrough, /server/haproxy-reencrypt, /server/traefik-passthrough, /server/traefik-reencrypt |
| Configuring the database | /server/db |
| Configuring distributed caches | /server/caching |
| Outgoing HTTP requests | /server/outgoinghttp |
| Trusted certificates (truststore) | /server/keycloak-truststore |
| mTLS para clientes | /server/mutual-tls |
| Enabling and disabling features | /server/features |
| Configuring providers | /server/configuration-provider |
| Logging (console, file, syslog, access log) | /server/logging |
| FIPS 140-2 | /server/fips |
| Management interface (puerto 9000) | /server/management-interface |
| Importing and exporting realms | /server/importExport |
| Vault | /server/vault |
| All configuration | /server/all-config |
| All provider configuration | /server/all-provider-config |
| Rolling updates compatibility check | /server/update-compatibility |
| Windows service | /server/windows-service |

### Operator
| Guía | URL |
|---|---|
| Installation (OLM, kubectl/kustomize, Helm experimental) | /operator/installation |
| Basic deployment | /operator/basic-deployment |
| Automating a realm import | /operator/realm-import |
| Managing clients (KeycloakOIDCClient/KeycloakSAMLClient, preview) | /operator/managing-clients |
| Advanced configuration | /operator/advanced-configuration |
| Rolling updates | /operator/rolling-updates |
| Custom images | /operator/customizing-keycloak |

### Observability
| Guía | URL |
|---|---|
| OpenTelemetry (logs, métricas, trazas) | /observability/telemetry |
| Health checks | /observability/health |
| Metrics | /observability/configuration-metrics |
| Event metrics | /observability/event-metrics |
| SLIs/SLOs | /observability/keycloak-service-level-indicators |
| Troubleshooting con métricas | /observability/metrics-for-troubleshooting |
| Tracing | /observability/tracing |
| Grafana dashboards | /observability/grafana-dashboards |
| Exemplars | /observability/exemplars |
| Thread dumps / JFR | /observability/thread-dumps, /observability/jfr |

### Securing applications
| Guía | URL |
|---|---|
| Planning (conceptos) | /securing-apps/overview |
| OpenID Connect (endpoints, grants, FAPI, OAuth 2.1, recomendaciones) | /securing-apps/oidc-layers |
| JavaScript adapter (keycloak-js) | /securing-apps/javascript-adapter |
| Node.js adapter | /securing-apps/nodejs-adapter |
| mod_auth_openidc (Apache) | /securing-apps/mod-auth-openidc |
| SAML Galleon feature pack (WildFly/EAP) | /securing-apps/saml-galleon-layers |
| mod_auth_mellon (Apache SAML) | /securing-apps/mod-auth-mellon |
| Docker Distribution Registry | /securing-apps/distribution-registry |
| Client registration service | /securing-apps/client-registration |
| Client registration CLI (kcreg) | /securing-apps/client-registration-cli |
| MCP authorization server | /securing-apps/mcp-authz-server |
| Token exchange (V2, delegación, V1 legacy) | /securing-apps/token-exchange |
| JWT Authorization Grant (RFC 7523) | /securing-apps/jwt-authorization-grant |
| Identity Assertion JWT Authorization Grant (ID-JAG) | /securing-apps/identity-assertion-jwt-authorization-grant |
| Identity & Authorization Chaining across domains | /securing-apps/oauth-identity-authorization-chaining-across-domains |
| DPoP | /securing-apps/dpop |
| AuthZEN (PDP) | /securing-apps/authzen-authorization |
| Especificaciones implementadas | /securing-apps/specifications |
| Shared Signals Framework (SSF) | /securing-apps/ssf-support |
| Admin client (Java) | /securing-apps/admin-client |
| Authorization client (Java) | /securing-apps/authz-client |
| Policy enforcer (Java) | /securing-apps/policy-enforcer |
| Upgrading client libraries | /securing-apps/upgrading |
| Externas: Apache APISIX, KrakenD, Quarkus, Traefik Hub, WildFly | enlaces desde /guides#securing-apps |

### High availability
| Guía | URL |
|---|---|
| Overview | /high-availability/introduction |
| Single-cluster (multi-AZ) | /high-availability/single-cluster/introduction |
| CloudNativePG multi-AZ | /high-availability/single-cluster/deploy-cnpg |
| Multi-cluster v1 (deprecado) | /high-availability/multi-cluster/introduction |
| Multi-cluster v2 (supported, `stateless`) | /high-availability/multi-cluster-v2/introduction |
| Migrar v1 → v2 | /high-availability/multi-cluster-v2/migrate-from-v1-to-v2 |

### UI Customization
| Guía | URL |
|---|---|
| Introduction | /ui-customization/introduction |
| Working with themes | /ui-customization/themes |
| Quick Theme | /ui-customization/quick-theme |
| Localization | /ui-customization/localization |
| Avatars | /ui-customization/avatars |
| Welcome theme | /ui-customization/welcome-theme |
| Crear tu propia consola | /ui-customization/creating-your-own-console |
| Paquetes npm de UI | /ui-customization/themes-react |

### Admin API
| Guía | URL |
|---|---|
| Protocol mappers (todos los built-in) | /admin-api/protocol-mappers |
| Admin API v2 reference (preview) | /admin-api/admin-api-v2 |
| Admin API v2 filtering & projection | /admin-api/querying |

### Migration
| Guía | URL |
|---|---|
| Migrar de WildFly a la distribución Quarkus | /migration/migrating-to-quarkus |

## 2. Documentación extensa (docs)

| Doc | Para qué | Temas clave |
|---|---|---|
| Server Administration Guide | Configuración funcional en la Admin Console | realms, usuarios, user profile, sesiones, credenciales, OTP/WebAuthn/passkeys, recovery codes, LDAP/Kerberos, brokering, SSO/logout, clients OIDC/SAML, client scopes, mappers, roles/grupos, authentication flows, required actions, step-up/ACR, client policies, FGAP, organizations, workflows, SCIM, eventos, vault, CIBA, device flow, OID4VCI, export/import parcial, seguridad (brute force, headers, clickjacking) |
| Server Developer Guide | Extender Keycloak | Admin REST API, temas, SPI/providers, autenticadores, required actions, event listeners, user storage SPI, vault SPI, identity brokering APIs, action tokens |
| Authorization Services Guide | Autorización fina | resource server, recursos, scopes, políticas, permisos, evaluación, UMA 2.0, entitlement, policy enforcer |
| Upgrading Guide | Migrar entre versiones | cambios incompatibles por versión, migración de BD, adaptadores |
| Release Notes | Novedades | qué se promovió/deprecó/eliminó |

## 3. APIs

- Admin REST API v1 (OpenAPI/HTML): `https://www.keycloak.org/docs-api/latest/rest-api/index.html`
- JavaDoc: `https://www.keycloak.org/docs-api/latest/javadocs/index.html`
- Admin API v2 (clients, preview): `/admin-api/admin-api-v2`; con `client-admin-api:v2` se expone el OpenAPI en la interfaz de management.
- Account REST API (usada por la Account Console): `/realms/{realm}/account`.

## 4. Features: nombres, estado y habilitación

Se habilitan con `--features=a,b` y se deshabilitan con `--features-disabled=x` (build options: en imágenes optimizadas van en el `build`). `--features=preview` habilita todas las preview. Se puede fijar versión: `--features=token-exchange-standard:v2`. Lista completa con estado: `https://www.keycloak.org/server/features` (verificar ahí; el estado cambia en cada versión menor).

Estado a 26.8 de las más consultadas:

| Feature | Estado | Nota |
|---|---|---|
| `organization` | supported, por defecto | activar por realm en Realm settings |
| `persistent-user-sessions` | supported, por defecto | sesiones en BD; modo volátil deprecado en 26.8 |
| `token-exchange-standard:v2` | supported, por defecto | activar switch por cliente |
| `token-exchange` (v1) | preview, **deprecated** | requiere FGAP v1 |
| `token-exchange-delegation` | preview | requiere `parameterized-scopes` + FGAP v2 |
| `parameterized-scopes` | preview | antes "dynamic scopes" |
| `admin-fine-grained-authz:v2` | supported | activar por realm |
| `dpop` | supported | |
| `passkeys` | supported | |
| `recovery-codes` | supported | |
| `step-up-authentication-saml` | supported (26.7) | |
| `jwt-authorization-grant` | supported (26.6) | alternativa a external→internal TE v1 |
| `client-auth-federated`, `kubernetes-service-accounts` | supported (26.6) | `spiffe` sigue preview |
| `workflows` | supported (26.6) | definidos en YAML |
| `scim-api` | supported (26.8) | |
| `client-secret-rotation` | supported (26.8) | |
| `stateless` | supported (26.8) | base de multi-cluster v2 |
| `multi-site` | **deprecated** | migrar a `stateless` |
| `client-admin-api:v2` | preview (26.8) | + CRs `KeycloakOIDCClient`/`KeycloakSAMLClient` |
| `identity-brokering-api:v2` | supported, deshabilitada por defecto | v1 deprecada pero habilitada |
| `oid4vc-vci` | preview (26.8) | `oid4vc-vp`, `oid4vc-mdoc`, `oid4vc-vci-preauth-code`, `client-auth-abca` experimentales |
| `cimd` | experimental | MCP 2025-11-25+ |
| `resource-indicators` | experimental | RFC 8707 (MCP) |
| `ssf` | experimental | Shared Signals Framework |
| `authzen` | experimental | |
| `identity-assertion-jwt` | experimental | ID-JAG |
| `http-client:v2` | experimental | cliente saliente Vert.x |
| `http-optimized-serializers` | preview | ~5 % más throughput |
| `log-mdc` | supported (26.5) | |
| `opentelemetry`, `opentelemetry-logs`, `opentelemetry-metrics` | ver guía telemetry | |
| `login-failures:v1` | deprecated | desde 26.8 los login failures van a BD |
| `scripts` | preview | JS en flows/mappers/políticas, desplegado como JAR |
| `fips` | supported | requiere BCFIPS |
| `hostname:v1` | **eliminado** (26.0) | solo hostname v2 |

## 5. Integraciones externas documentadas desde keycloak.org

Apache APISIX, KrakenD, Quarkus (`quarkus-oidc`, authorization), Traefik Hub, WildFly Elytron OIDC. Para Spring Boot: Spring Security OAuth2 Client / Resource Server (no hay adaptador oficial). Ecosistema comunitario frecuente: Terraform provider `keycloak/keycloak`, keycloak-config-cli (adorsys), Keycloakify (temas en React), `@keycloak/keycloak-admin-client` (npm), python-keycloak, gocloak (Go).
