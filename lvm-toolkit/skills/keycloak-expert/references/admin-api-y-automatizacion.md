# Automatización: Admin REST API, kcadm, import/export y configuración como código

## Contenido
1. Obtener un token de administración
2. Admin REST API v1: rutas más usadas
3. Admin API v2 (clients, preview)
4. kcadm.sh
5. Admin clients por lenguaje
6. Import/export de realms
7. Terraform, keycloak-config-cli y GitOps
8. Patrones y trampas

## 1. Token de administración

Opción recomendada para automatización: **cliente confidencial con service account** en el realm a administrar (o en master para varios realms), con roles de cliente `realm-management` mínimos (`manage-users`, `view-clients`…) o FGAP v2.

```bash
KC=https://auth.ejemplo.com
TOKEN=$(curl -s -X POST "$KC/realms/demo/protocol/openid-connect/token" \
  -d grant_type=client_credentials -d client_id=automation -d client_secret="$SECRET" | jq -r .access_token)
```
Interactivo/legacy: usuario admin de `master` con el cliente `admin-cli` y password grant (`-d grant_type=password -d client_id=admin-cli -d username=... -d password=...`). Los tokens del Admin API pueden ser *lightweight* (26.0): no asumas claims en ellos.

Crear un admin vía bootstrap para scripts: `bin/kc.sh bootstrap-admin service --client-id=tmp-admin` (crea cliente temporal con secreto).

## 2. Admin REST API v1

Base: `$KC/admin/realms`. Referencia completa: `https://www.keycloak.org/docs-api/latest/rest-api/index.html`. Header `Authorization: Bearer $TOKEN`, JSON. Las creaciones devuelven `201` con header `Location` (el ID está al final).

| Operación | Método y ruta |
|---|---|
| Listar / crear realm | `GET/POST /admin/realms` |
| Obtener/actualizar realm | `GET/PUT /admin/realms/{realm}` |
| Partial import (upsert masivo) | `POST /admin/realms/{realm}/partialImport` (`ifResourceExists`: FAIL/SKIP/OVERWRITE) |
| Partial export | `POST /admin/realms/{realm}/partial-export?exportClients=true&exportGroupsAndRoles=true` (secretos enmascarados) |
| Usuarios: buscar | `GET /admin/realms/{realm}/users?username=x&exact=true` (`search`, `email`, `q=attr:valor`, `first`, `max`, `briefRepresentation`) |
| Contar | `GET /admin/realms/{realm}/users/count` |
| Crear usuario | `POST /admin/realms/{realm}/users` |
| Actualizar | `PUT /admin/realms/{realm}/users/{id}` (envía la representación completa; actualización parcial de atributos ya no se soporta desde 24.0.4) |
| Reset password | `PUT /admin/realms/{realm}/users/{id}/reset-password` `{"type":"password","value":"...","temporary":true}` |
| Email de acciones | `PUT /admin/realms/{realm}/users/{id}/execute-actions-email?client_id=..&redirect_uri=..&lifespan=..` body `["UPDATE_PASSWORD","VERIFY_EMAIL"]` |
| Logout usuario | `POST /admin/realms/{realm}/users/{id}/logout` |
| Grupos del usuario | `GET/PUT/DELETE /admin/realms/{realm}/users/{id}/groups/{groupId}` |
| Roles de realm del usuario | `GET/POST/DELETE /admin/realms/{realm}/users/{id}/role-mappings/realm` (body: array de RoleRepresentation con `id` y `name`) |
| Roles de cliente del usuario | `/admin/realms/{realm}/users/{id}/role-mappings/clients/{clientUuid}` |
| Clientes | `GET /admin/realms/{realm}/clients?clientId=web` (devuelve `id` UUID ≠ `clientId`), `POST`, `PUT/DELETE /clients/{uuid}` |
| Secreto del cliente | `GET/POST /admin/realms/{realm}/clients/{uuid}/client-secret` |
| Service account user | `GET /admin/realms/{realm}/clients/{uuid}/service-account-user` |
| Roles | `GET/POST /admin/realms/{realm}/roles`, `/roles/{name}`, `/clients/{uuid}/roles` |
| Grupos | `GET/POST /admin/realms/{realm}/groups`, subgrupos `POST /groups/{id}/children`, miembros `/groups/{id}/members` |
| Client scopes | `/admin/realms/{realm}/client-scopes`, asignar `PUT /clients/{uuid}/default-client-scopes/{scopeId}` |
| Mappers | `/clients/{uuid}/protocol-mappers/models`, `/client-scopes/{id}/protocol-mappers/models` |
| Identity providers | `/admin/realms/{realm}/identity-provider/instances` (+ `/{alias}/mappers`) |
| Componentes (LDAP, keys) | `/admin/realms/{realm}/components?type=org.keycloak.storage.UserStorageProvider`; sync LDAP `POST /user-storage/{id}/sync?action=triggerFullSync` |
| Flows | `/admin/realms/{realm}/authentication/flows`, `/flows/{alias}/copy`, `/flows/{alias}/executions` |
| Eventos | `GET /admin/realms/{realm}/events`, `/admin-events` |
| Sesiones de cliente | `GET /admin/realms/{realm}/clients/{uuid}/user-sessions` |
| Organizations | `/admin/realms/{realm}/organizations` (+ `/members`, `/identity-providers`, `/groups`) |
| Info del servidor | `GET /admin/serverinfo` |

Ejemplo crear usuario y asignar rol de realm:
```bash
curl -s -X POST "$KC/admin/realms/demo/users" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{
  "username":"ana","email":"ana@ejemplo.com","firstName":"Ana","lastName":"Pérez","enabled":true,"emailVerified":true,
  "credentials":[{"type":"password","value":"Cambiar.123","temporary":true}],
  "groups":["/ventas"]}'
UID=$(curl -s "$KC/admin/realms/demo/users?username=ana&exact=true" -H "Authorization: Bearer $TOKEN" | jq -r '.[0].id')
ROLE=$(curl -s "$KC/admin/realms/demo/roles/editor" -H "Authorization: Bearer $TOKEN")
curl -s -X POST "$KC/admin/realms/demo/users/$UID/role-mappings/realm" -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' -d "[$ROLE]"
```

## 3. Admin API v2 (preview, 26.8)

- Habilitar: `--features=client-admin-api:v2` (o `preview`). Primer recurso: **clients** OIDC y SAML, con validación estricta, configuración declarativa y especificación OpenAPI precisa (expuesta en la interfaz de management; la CLI la usa para adaptarse a la versión).
- Clientes: Java client, cliente JavaScript autogenerado, CLI; el Operator lo usa para `KeycloakOIDCClient`/`KeycloakSAMLClient`.
- Filtros y proyección con su sintaxis de query (`/admin-api/querying`).
- Rutas y payloads exactos: consultar `/admin-api/admin-api-v2` (no inventar; aún puede cambiar).

## 4. kcadm.sh

Incluido en `bin/` (o `docker exec kc /opt/keycloak/bin/kcadm.sh`). Config en `~/.keycloak/kcadm.config`.

```bash
kcadm.sh config credentials --server https://auth.ejemplo.com --realm master --user admin   # pide password
# o con service account: --realm demo --client automation --secret "$SECRET"
kcadm.sh create realms -s realm=demo -s enabled=true
kcadm.sh update realms/demo -s sslRequired=external -s bruteForceProtected=true -s loginWithEmailAllowed=true
kcadm.sh create clients -r demo -s clientId=web -s publicClient=true -s standardFlowEnabled=true \
  -s directAccessGrantsEnabled=false -s 'redirectUris=["https://app.ejemplo.com/*"]' -s 'webOrigins=["+"]' \
  -s 'attributes."pkce.code.challenge.method"=S256'
kcadm.sh create clients -r demo -s clientId=svc-a -s publicClient=false -s serviceAccountsEnabled=true -s standardFlowEnabled=false
kcadm.sh get clients -r demo -q clientId=web --fields id,clientId
kcadm.sh create roles -r demo -s name=editor
kcadm.sh create users -r demo -s username=ana -s email=ana@ejemplo.com -s enabled=true
kcadm.sh set-password -r demo --username ana --new-password 'Cambiar.123' --temporary
kcadm.sh add-roles -r demo --uusername ana --rolename editor
kcadm.sh add-roles -r demo --uusername service-account-svc-a --cclientid realm-management --rolename view-users
kcadm.sh create groups -r demo -s name=ventas
kcadm.sh get users -r demo -q username=ana --fields id,username,email
kcadm.sh delete users/<id> -r demo
```
- `-s` setea campos (`attributes.x=y`), `-f archivo.json` o `-f -` desde stdin, `--fields`, `-q` filtros, `-o` para imprimir el resultado. `kcadm.sh get-roles`, `remove-roles`, `get serverinfo`.
- `kcreg.sh` es la CLI de *client registration* (no requiere admin).

## 5. Admin clients por lenguaje

- Java: `org.keycloak:keycloak-admin-client` (`KeycloakBuilder.builder().serverUrl(..).realm("master").clientId("admin-cli")...build()`); versión con ciclo propio compatible con servidores soportados (`/securing-apps/admin-client`).
- JavaScript/TypeScript: `@keycloak/keycloak-admin-client` (`new KcAdminClient({ baseUrl, realmName })`, `await kc.auth({ grantType: 'client_credentials', clientId, clientSecret })`, `kc.users.create(...)`).
- Python: `python-keycloak` (`KeycloakAdmin`). Go: `gocloak`. (Comunitarios: verificar compatibilidad.)

## 6. Import / export

**Al arrancar** (idempotente: si el realm existe se omite):
```bash
bin/kc.sh start --import-realm          # lee data/import/*.json
```
**Comandos dedicados** (preferible con el servidor detenido o en una instancia aparte apuntando a la misma BD; verificar en la guía si tu versión permite hacerlo en caliente):
```bash
bin/kc.sh export --dir /tmp/export --realm demo --users different_files --users-per-file 500
bin/kc.sh export --file /tmp/demo.json --realm demo --users realm_file
bin/kc.sh import --dir /tmp/export --override false   # --override true reemplaza realms existentes
```
`--users`: `skip`, `realm_file`, `same_file`, `different_files`. El export incluye secretos y hashes: trátalo como sensible. Variables en JSON: `${ENV_VAR}` / `${ENV_VAR:default}` se resuelven al importar.

**Desde la consola**: Realm settings → Action → Partial export / Partial import (sin usuarios en el export parcial; secretos enmascarados).

**Operator**: `KeycloakRealmImport` (solo creación).

## 7. Configuración como código

- **Terraform**: provider `keycloak/keycloak` (antes `mrparkers/keycloak`; ahora mantenido bajo la organización keycloak). Recursos `keycloak_realm`, `keycloak_openid_client`, `keycloak_openid_client_scope`, `keycloak_role`, `keycloak_group`, `keycloak_user`, `keycloak_ldap_user_federation`, `keycloak_oidc_identity_provider`, `keycloak_authentication_flow`… Autentica con un cliente service account (`client_id`/`client_secret`, `realm`). Verificar versión del provider compatible.
- **keycloak-config-cli** (adorsys): aplica JSON/YAML de realm de forma idempotente (crea/actualiza/borra con `import.remote-state`), ideal como Job en CI/K8s.
- **Operator**: `KeycloakOIDCClient`/`KeycloakSAMLClient` (preview).
- Evita mezclar herramientas sobre los mismos objetos (pelean entre sí). Define qué es "código" y qué se edita en consola.

## 8. Patrones y trampas

- Distingue `id` (UUID interno) de `clientId`/`username`/`alias`. Casi todas las rutas usan el UUID.
- `PUT` reemplaza la representación: lee (`GET`), modifica y envía completa (especialmente usuarios con atributos).
- Paginación: `first`/`max` (por defecto `max=100` en muchos listados). Usa `briefRepresentation=true` para listas grandes.
- Atributos de usuario deben existir en el User Profile o serán rechazados/ignorados.
- Los roles en role-mappings se envían como objetos (`id`+`name`), no como strings.
- Errores 409 = ya existe; 400 con `errorMessage` describe validación (User Profile). 403 = faltan roles `realm-management`.
- No uses el realm `master` para usuarios finales ni el cliente `admin-cli` con usuarios humanos en CI.
