# Administración funcional (Server Administration Guide)

## Contenido
1. Realms y el realm master
2. Usuarios, User Profile y credenciales
3. Roles, grupos y composites
4. Clients, client scopes y protocol mappers
5. Sesiones y tokens (timeouts)
6. Authentication flows, required actions y MFA
7. Passkeys/WebAuthn, OTP, recovery codes, step-up (ACR/LoA)
8. User Federation: LDAP/AD y Kerberos
9. Identity Brokering (social, OIDC, SAML)
10. Organizations (B2B/multi-tenant)
11. Client Policies
12. Fine-Grained Admin Permissions (FGAP v2) y roles de admin
13. Authorization Services (UMA y políticas)
14. Workflows, SCIM y automatización del ciclo de vida
15. Eventos y auditoría
16. Seguridad del realm (brute force, contraseñas, headers)
17. Email, temas e i18n por realm
18. OID4VCI (credenciales verificables)

## 1. Realms

- `master` es solo para administrar Keycloak; crea un realm por dominio de negocio. Cada realm tiene usuarios, clientes, claves, flows y temas propios.
- Admin Console: `https://<host>/admin/` (consola del realm master) o `/admin/<realm>/console/` para admins de un realm (usuarios con roles de cliente `realm-management`).
- Claves: Realm settings → Keys (providers `rsa-generated`, `ecdsa-generated`, `eddsa-generated`, `hmac-generated`, `aes-generated`, `java-keystore`, `rsa` importado). Rotación: agrega una clave nueva con prioridad mayor, deja la vieja *passive* hasta que expiren los tokens, luego desactívala/bórrala.
- Realm settings → General: *Frontend URL*, *Require SSL* (`external` por defecto, `all` en prod, `none` nunca), *User-managed access*, *Organizations*, *Admin permissions*.
- Display name (búsqueda por display name desde 26.7).

## 2. Usuarios y User Profile

- **User Profile declarativo** siempre activo (Realm settings → User profile): define atributos, validaciones, permisos (quién ve/edita: user/admin), anotaciones de UI, grupos de atributos y *progressive profiling* (atributos requeridos por scope). Atributos no declarados son rechazados salvo *Unmanaged attributes* (Enabled/Admin edit/Admin view).
- Campos base: `username`, `email`, `firstName`, `lastName`. *Login with email*, *Duplicate emails*, *Email as username*, *Verify email*, *Edit username* en Realm settings → Login.
- Credenciales: password (hash **argon2** por defecto en no-FIPS desde 25; pbkdf2-sha512 en FIPS), OTP, WebAuthn, recovery codes, X.509, Kerberos.
- Acciones admin: *Credentials → Reset password* (temporal ⇒ required action), *Send email / execute actions*, *Impersonate* (rol `impersonation`), *Sessions*, *Consents*, *Identity provider links*.
- Usuarios temporales (transient, feature `transient-users`) para brokering sin persistir.
- Búsqueda por atributo: case-sensitive desde 25.

## 3. Roles y grupos

- Realm roles (claim `realm_access.roles`) y client roles (`resource_access.<client>.roles`). Composites para agrupar. *Default roles* (`default-roles-<realm>`) se asignan a todos los usuarios nuevos.
- Grupos jerárquicos con atributos y role mappings heredados por los miembros; preferir grupos para asignar roles a escala.
- *Client scope → Scope* (Full scope allowed OFF) para limitar qué roles entran en el token del cliente (principio de mínimo privilegio y tokens más chicos).

## 4. Clients, client scopes y mappers

- Client scopes compartidos (Client scopes) con mappers y role scope; asignados a clientes como **Default** (siempre) u **Optional** (si se piden en `scope`). Tipo de protocolo OIDC o SAML.
- Mappers frecuentes: Audience, User Attribute, User Property, Hardcoded claim/role, Group Membership, User Realm/Client Role, User Session Note, Pairwise subject, Allowed Web Origins, Organization Membership, Organization Group Membership, Parameterized Scope User Property. Catálogo completo: `/admin-api/protocol-mappers`. Restringir qué tipos se pueden crear vía API: executor `allowed-protocol-mappers` (26.8).
- **Parameterized scopes** (preview, antes "dynamic scopes"): `project:12345`; tipos de parámetro `string`, `integer`, `boolean`, `username`, `custom` (regex).
- Client types (feature `client-types`), client templates vía scopes.
- Evaluate: Clients → *client* → Client scopes → Evaluate para ver el token resultante para un usuario.
- Consent: *Consent required* en el cliente; textos por scope (*Consent screen text*).

## 5. Sesiones y tokens (Realm settings → Sessions / Tokens)

| Parámetro | Default | Nota |
|---|---|---|
| SSO Session Idle | 30 min | inactividad (refresh/login) |
| SSO Session Max | 10 h | vida máxima |
| Remember me idle/max | (=SSO si 0) | requiere *Remember me* activado |
| Client session idle/max | 0 (=SSO) | por cliente en Advanced |
| Offline session idle | 30 días | *Offline session max limited* opcional |
| Access token lifespan | 5 min | override por cliente |
| Access token lifespan for implicit | 15 min | no usar implicit |
| Login timeout / Login action timeout | 30 min / 5 min | |
| Revoke refresh token | OFF | rotación de refresh tokens (reuse count) |
| User/admin-initiated action lifespan | 5 min / 12 h | links de email |

Sesiones persistentes en BD (sobreviven reinicios). Límites de sesiones por usuario: authenticator *User session count limiter* en el flow.

## 6. Authentication flows y required actions

- Authentication → Flows: `browser`, `direct grant`, `registration`, `reset credentials`, `clients`, `first broker login`, `docker auth`. **Duplica** un flow para editarlo y asígnalo en *Bind flow* (realm) o override por cliente (Advanced → Authentication flow overrides) o dinámicamente con Client Policies (26.2).
- Requisitos: REQUIRED, ALTERNATIVE, DISABLED, CONDITIONAL (sub-flow con condiciones: *Condition - user role*, *user configured*, *user attribute*, *sub-flow executed*, *client scope*, *credential*, *level of authentication*).
- Authenticators comunes: Cookie, Identity Provider Redirector (`kc_idp_hint`), Username Password Form, Username Form + Password Form, OTP Form, WebAuthn (passwordless), Passkeys conditional UI, Recovery Authentication Code Form, X509/Validate Username, Kerberos, Conditional OTP, Deny access, Allow access, User session count limiter, Organization identity-first login.
- Required actions (Authentication → Required actions): Verify Email, Update Password, Configure OTP, Update Profile, Terms and Conditions, WebAuthn Register (y Passwordless), Recovery codes, Delete credential, Update Email (supported), Verify Profile. **AIA** (application-initiated action): la app redirige al login con `kc_action=UPDATE_PASSWORD` (o `CONFIGURE_TOTP`, `webauthn-register`, `delete_credential:<id>`…).
- Parámetros útiles del endpoint auth: `kc_idp_hint`, `login_hint`, `prompt=login|none|consent|create`, `max_age`, `acr_values`, `ui_locales`, `kc_locale`.

## 7. MFA, passkeys y step-up

- OTP: Authentication → Policies → OTP policy (TOTP/HOTP, algoritmo, dígitos, periodo). Forzar: required action *Configure OTP* o flow con OTP REQUIRED.
- **Passkeys** (supported 26.4): integradas en los formularios de usuario/contraseña por defecto (conditional UI). WebAuthn Policy / WebAuthn Passwordless Policy: RP ID, atestación, *Discoverable credential* = `required|preferred|discouraged` (26.7; *Require discoverable credential* deprecado), user verification.
- Recovery codes (supported) y obligarlos tras configurar OTP (26.4). Recuperar cuenta si se pierden credenciales 2FA (26.3).
- **Step-up / LoA**: Realm settings → *ACR to LoA mapping*; flow con *Condition - level of authentication* por nivel; el cliente pide `acr_values` o `claims` (essential acr); *Minimum ACR value* por cliente (26.1). También para SAML (26.7).

## 8. User Federation: LDAP / Active Directory

- User federation → Add LDAP providers: Vendor (Active Directory, Red Hat DS, Other), Connection URL (`ldaps://`), Bind DN/credential (`${vault.ldap_bind}`), Users DN, Username/RDN/UUID LDAP attribute (AD: `sAMAccountName`/`cn`/`objectGUID`), filtro de usuarios, Search scope (subtree).
- **Edit mode**: `READ_ONLY` (cambios bloqueados), `WRITABLE` (sincroniza a LDAP), `UNSYNCED` (cambios solo en Keycloak).
- *Import users* ON (copia local, más rápido) u OFF (consulta en vivo). Sync periódico completo/cambiados. *Trust email*. *Use truststore SPI*. Connection pooling configurable (26.0).
- Mappers: user-attribute, full-name, group-ldap-mapper (grupos LDAP → grupos KC), role-ldap-mapper, msad-user-account-control-mapper (AD: estado/expiración de contraseña), hardcoded-role, certificate-ldap-mapper.
- Política de contraseñas LDAP: *Enable LDAP password policy* fuerza cambio si LDAP lo indica (26.6).
- **Kerberos/SPNEGO**: provider Kerberos o *Allow Kerberos authentication* en LDAP; keytab, principal `HTTP/host@REALM`, authenticator Kerberos ALTERNATIVE en browser flow. En contenedor basta con `/etc/krb5.conf` (no hace falta `krb5-libs`).
- Custom: User Storage SPI (ver `extensiones-y-temas.md`).

## 9. Identity Brokering

- Identity providers → Social (Google, GitHub, Microsoft, Facebook, Apple vía OIDC genérico, LinkedIn OpenID, GitLab, Bitbucket, Instagram/Twitter por feature) o genéricos **OpenID Connect v1.0**, **OAuth v2** (26.3), **SAML v2.0**, Keycloak OIDC, JWT Authorization Grant. Varias instancias del mismo social por realm (26.0).
- Redirect URI a registrar en el IdP externo: `https://<host>/realms/<realm>/broker/<alias>/endpoint`.
- Opciones: *Trust email* (o verificación confiable de email OIDC, 26.3), *Sync mode* (`IMPORT`, `LEGACY`, `FORCE`), *Store tokens* (para API de brokering), *Hide on login page* / ocultar en Account Console, *First login flow* (`first broker login`: revisar perfil, crear usuario o vincular cuenta existente con re-autenticación), *Post login flow*, PKCE hacia el IdP, *Client authentication* `private_key_jwt`.
- Mappers de IdP: Attribute Importer, Hardcoded Role/Attribute/Group, Claim to Role, Advanced Claim to Role, SAML Attribute to Role, Username Template Importer, organization group mappers.
- `kc_idp_hint=<alias>` para saltar la pantalla de login. Account linking iniciado por cliente: required action / AIA `idp_link:<alias>` (26.3).
- Recuperar tokens del IdP externo: Identity Brokering API v2 (`--features=identity-brokering-api:v2`, cliente confidencial con *Allow retrieve external tokens*).

## 10. Organizations

- Activar: Realm settings → Organizations ON (feature supported y habilitada por defecto desde 26.0). Representa clientes/partners B2B dentro de un realm.
- Elementos: miembros (managed vía IdP o unmanaged), dominios (email domain opcional desde 26.4), identity providers vinculados (un IdP puede compartirse entre organizaciones, 26.8; routing por dominio con auto-redirect y gate de dominio), invitaciones (gestión 26.5), **grupos de organización** aislados (26.6) con roles heredados en el token (26.7), atributos.
- Login identity-first: el usuario escribe su email y se redirige al IdP de su organización.
- Token: scope `organization` (claim `organization`; `organization:*` o `organization:<alias>`), mapper *Organization Membership* / *Organization Group Membership*.
- Admin delegada: roles `manage-organizations`, `view-organizations`, `query-organizations` (26.7) y FGAP v2 por organización.

## 11. Client Policies

Realm settings → Client policies. **Profiles** = conjunto de *executors* (qué exigir/hacer); **Policies** = *conditions* (a qué clientes/peticiones) + perfiles asociados. Executors frecuentes: `pkce-enforcer`, `secure-redirect-uris-enforcer`, `secure-client-authenticator`, `holder-of-key-enforcer`, `dpop-bind-enforcer`, `secure-request-object`, `secure-signature-algorithm`, `confidential-client`, `consent-required`, `reject-implicit-grant`, `client-secret-rotation`, `downscope-assertion-grant-enforcer`, `allowed-protocol-mappers`, `may-act`, `secure-client-node-hostname` (26.8, anti-SSRF del registro de nodos legacy), `client-id-metadata-document`, `authentication-flow-selector`. Condiciones: `client-roles`, `client-access-type`, `client-scope`, `client-updater-source-host/roles/groups`, `any-client`, `grant-type`, `client-attribute`, `client-id-uri`. Perfiles globales FAPI/OAuth 2.1 incluidos.

## 12. Permisos de administración

- Roles de cliente `realm-management` (por realm): `manage-users`, `view-users`, `query-users`, `manage-clients`, `view-clients`, `query-clients`, `manage-realm`, `view-realm`, `manage-events`, `view-events`, `manage-identity-providers`, `manage-authorization`, `impersonation`, `create-client`, `query-groups`, `manage-organizations`… y composite `realm-admin`. En master, roles `<realm>-realm` client y `admin`/`create-realm`.
- **FGAP v2** (supported desde 26.2): Realm settings → Admin permissions ON → menú *Permissions*. Recursos: Users, Groups, Clients, Roles, Organizations (26.7); scopes como `view`, `manage`, `map-roles`, `impersonate`, `manage-group-membership`, `manage-membership`, `manage-membership-of-members` (26.6), `view-members`, `manage-members`, `delegate`, `delegate-members`. Políticas (user, group, role, client…). Evaluación con la pestaña *Evaluation*. Úsalo para "el admin del equipo X solo gestiona usuarios del grupo X".
- FGAP v1 solo para legacy token exchange.

## 13. Authorization Services

Para autorización centralizada fina (feature `authorization`, supported).
- Cliente confidencial con *Authorization* ON ⇒ pestaña Authorization: **Resources** (URI, tipo, owner, scopes, atributos), **Authorization scopes** (`view`, `edit`…), **Policies** (role, user, group, client, client scope, time, regex, aggregated, JavaScript desplegado como JAR), **Permissions** (resource-based o scope-based) con *Decision strategy* (`UNANIMOUS`, `AFFIRMATIVE`, `CONSENSUS`), *Policy enforcement mode* (`ENFORCING`, `PERMISSIVE`, `DISABLED`), *Evaluate* para probar.
- Obtener permisos (RPT / decisión):
```bash
curl -X POST https://auth.ejemplo.com/realms/demo/protocol/openid-connect/token \
  -H "Authorization: Bearer $AT" \
  -d grant_type=urn:ietf:params:oauth:grant-type:uma-ticket \
  -d audience=orders-api \
  -d permission="Order Resource#view" \
  -d response_mode=decision     # o permissions / RPT por defecto
```
- UMA 2.0: recursos propiedad del usuario, compartir desde Account Console (*User-managed access*), Protection API (`/authz/protection/resource_set`, permission tickets).
- Enforcers: Java policy enforcer (`/securing-apps/policy-enforcer`), `quarkus-keycloak-authorization`, authz client Java. Alternativa estándar: **AuthZEN** (experimental, Keycloak como PDP).

## 14. Workflows y SCIM

- **Workflows** (supported 26.6): automatizan ciclo de vida de usuarios/clientes en YAML (Realm → Workflows): disparadores por evento (p. ej. usuario creado, login), condiciones y pasos (enviar email, deshabilitar tras inactividad, borrar, asignar rol/grupo, `invite-user` 26.8 que envía email con required actions) con programación (`after`). Útil para IGA básico (joiner/mover/leaver, cuentas inactivas).
- **SCIM API** (supported 26.8, feature `scim-api`): CRUD/PATCH de Users y Groups, filtros, paginación, Enterprise User extension, respeta User Profile y FGAP. Para integrarse con Entra ID, Okta, HR/IGA. Ver Server Admin Guide → *Managing users and groups through SCIM* para la URL base y la autenticación (verificar).
- Shared Signals Framework (experimental): emitir eventos CAEP/RISC a receptores.

## 15. Eventos

- Realm settings → Events: *User events* (LOGIN, LOGIN_ERROR, REGISTER, LOGOUT, CODE_TO_TOKEN, REFRESH_TOKEN, UPDATE_PASSWORD, USER_SESSION_DELETED 26.5…) y *Admin events* (con *Include representation* opcional). Guardar en BD con expiración (¡configurarla!) y/o listeners (`jboss-logging`, `email`, custom SPI para enviar a Kafka/SIEM).
- Consultar: Events en la consola o `GET /admin/realms/{realm}/events` y `/admin-events` (filtros por tipo, usuario, cliente, fechas, `direction`).
- Métricas agregadas de eventos: `--event-metrics-user-enabled`.

## 16. Seguridad del realm

- **Brute force detection** (Realm settings → Security defenses): Lockout temporal/permanente, max failures, wait increment, quick login check. Desde 26.8 los fallos se guardan en BD (persisten entre reinicios).
- **Password policy** (Authentication → Policies): length, digits, uppercase, special chars, not username/email, password history, expire password, hashing algorithm/iterations, password blacklist (archivo en `data/password-blacklists`, recarga automática 26.6), max auth age.
- Headers: X-Frame-Options, CSP (`frame-ancestors`), HSTS, X-Content-Type-Options, Referrer-Policy (Security defenses → Headers).
- CORS por cliente (Web origins). Hidden scopes en discovery (26.5).
- Ocultar `master` del público (proxy). Admin con MFA. Usar *Require SSL = all external*.

## 17. Email, temas e i18n

- Realm settings → Email: host, puerto, TLS/StartTLS, from, autenticación password o **XOAUTH2** (26.2). Botón *Test connection*.
- Realm settings → Themes: login, account, admin, email; temas por cliente (Advanced → Login theme).
- Localization: Internationalization ON, idiomas soportados, overrides de mensajes por realm (Realm overrides) sin tocar el tema. Traducciones gestionadas en Weblate.

## 18. OID4VCI / OID4VP

Keycloak como emisor de credenciales verificables (SD-JWT VC, mdoc experimental) — preview en 26.8 (`--features=oid4vc-vci`): client scopes de tipo credencial, claves de firma SD-JWT, ofertas de credenciales, AIA para emitir, revocación al revocar refresh tokens, perfil HAIP. Verificador OID4VP experimental (`oid4vc-vp`). Ver Server Admin Guide (sección OID4VCI) antes de responder detalles.
