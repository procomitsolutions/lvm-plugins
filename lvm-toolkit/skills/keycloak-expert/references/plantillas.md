# Plantillas listas para copiar

Reemplaza `auth.ejemplo.com`, `demo`, nombres de cliente y secretos. Fija siempre la versión de imagen.

## Contenido
1. docker-compose de desarrollo (Keycloak + Postgres + import)
2. docker-compose de producción con NGINX (re-encrypt)
3. Configuración NGINX
4. keycloak.conf de producción (VM)
5. Unidad systemd
6. Realm JSON mínimo (SPA + API + servicio)
7. Script kcadm de bootstrap
8. Probar Authorization Code + PKCE con curl
9. Middleware Express que valida JWT y roles
10. Spring Boot resource server con roles de Keycloak

## 1. Desarrollo

```yaml
# compose.dev.yaml
services:
  postgres:
    image: postgres:17
    environment:
      POSTGRES_DB: keycloak
      POSTGRES_USER: keycloak
      POSTGRES_PASSWORD: keycloak
    volumes: [ "pgdata:/var/lib/postgresql/data" ]
  keycloak:
    image: quay.io/keycloak/keycloak:26.8.0
    command: ["start-dev", "--import-realm"]
    environment:
      KC_DB: postgres
      KC_DB_URL_HOST: postgres
      KC_DB_USERNAME: keycloak
      KC_DB_PASSWORD: keycloak
      KC_BOOTSTRAP_ADMIN_USERNAME: admin
      KC_BOOTSTRAP_ADMIN_PASSWORD: admin
      KC_HEALTH_ENABLED: "true"
    ports: [ "127.0.0.1:8080:8080", "127.0.0.1:9000:9000" ]
    volumes: [ "./realms:/opt/keycloak/data/import:ro", "./themes:/opt/keycloak/themes:ro" ]
    depends_on: [ postgres ]
volumes: { pgdata: {} }
```

## 2. Producción con NGINX (re-encrypt)

```dockerfile
# Containerfile
FROM quay.io/keycloak/keycloak:26.8.0 AS builder
ENV KC_DB=postgres KC_HEALTH_ENABLED=true KC_METRICS_ENABLED=true
RUN /opt/keycloak/bin/kc.sh build
FROM quay.io/keycloak/keycloak:26.8.0
COPY --from=builder /opt/keycloak/ /opt/keycloak/
ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
```

```yaml
# compose.prod.yaml (un nodo; para HA, réplicas en hosts distintos con 7800/57800 abiertos entre ellos)
services:
  keycloak:
    build: { context: ., dockerfile: Containerfile }
    image: mi-keycloak:26.8.0
    command: ["start", "--optimized"]
    environment:
      KC_HOSTNAME: https://auth.ejemplo.com
      KC_PROXY_HEADERS: xforwarded
      KC_PROXY_TRUSTED_ADDRESSES: 172.16.0.0/12
      KC_HTTPS_CERTIFICATE_FILE: /certs/internal.crt
      KC_HTTPS_CERTIFICATE_KEY_FILE: /certs/internal.key
      KC_DB_URL: jdbc:postgresql://db.interno:5432/keycloak
      KC_DB_USERNAME: keycloak
      KC_DB_TLS_MODE: verify-server
      KC_DB_TLS_TRUST_STORE_FILE: /certs/db-ca.pem
      KC_LOG_CONSOLE_OUTPUT: json
      KC_HTTP_MAX_QUEUED_REQUESTS: "1000"
    env_file: [ ./secrets.env ]          # KCRAW_DB_PASSWORD=..., KC_BOOTSTRAP_ADMIN_* solo la primera vez
    volumes: [ "./certs:/certs:ro" ]
    deploy: { resources: { limits: { memory: 2g } } }
    expose: [ "8443", "9000" ]
    healthcheck:
      test: ["CMD-SHELL", "exec 3<>/dev/tcp/127.0.0.1/9000 && printf 'GET /health/ready HTTP/1.1\\r\\nHost: localhost\\r\\nConnection: close\\r\\n\\r\\n' >&3 && grep -q '\"UP\"' <&3"]
      interval: 15s
      retries: 10
    restart: unless-stopped
  nginx:
    image: nginx:1.27
    ports: [ "443:443" ]
    volumes: [ "./nginx.conf:/etc/nginx/conf.d/keycloak.conf:ro", "./certs:/certs:ro" ]
    depends_on: [ keycloak ]
```
(La imagen no tiene `curl`; el healthcheck usa `/dev/tcp`. Si el management usa HTTPS, haz el chequeo desde el proxy o un sidecar.)

## 3. NGINX

```nginx
upstream keycloak { server keycloak:8443; keepalive 32; }

server {
  listen 443 ssl;
  http2 on;
  server_name auth.ejemplo.com;
  ssl_certificate     /certs/public.crt;
  ssl_certificate_key /certs/public.key;

  proxy_ssl_server_name on;
  proxy_ssl_verify on;
  proxy_ssl_trusted_certificate /certs/internal-ca.pem;
  proxy_ssl_name keycloak;
  proxy_http_version 1.1;
  proxy_set_header Connection "";

  # Sobrescribir (no anexar) headers de proxy y limpiar los peligrosos
  proxy_set_header Host               $host;
  proxy_set_header X-Forwarded-For    $remote_addr;
  proxy_set_header X-Forwarded-Proto  $scheme;
  proxy_set_header X-Forwarded-Host   $host;
  proxy_set_header X-Forwarded-Port   443;
  proxy_set_header X-Real-IP          "";
  proxy_set_header X-Original-URL     "";
  proxy_set_header traceparent        "";
  proxy_set_header tracestate         "";
  proxy_set_header baggage            "";
  proxy_buffer_size 128k;              # tokens/cookies grandes
  proxy_buffers 4 256k;

  location /realms/master/ { allow 10.0.0.0/8; deny all; proxy_pass https://keycloak; }
  location /admin/         { allow 10.0.0.0/8; deny all; proxy_pass https://keycloak; }
  location /realms/        { proxy_pass https://keycloak; }
  location /resources/     { proxy_pass https://keycloak; }
  location /.well-known/   { proxy_pass https://keycloak; }
  location /               { return 404; }
}
```

## 4. keycloak.conf (VM)

```properties
db=postgres
db-url-host=db.interno
db-username=keycloak
db-password=${KC_DB_PASSWORD}
db-tls-mode=verify-server
db-tls-trust-store-file=/etc/keycloak/db-ca.pem
hostname=https://auth.ejemplo.com
hostname-admin=https://kc-admin.interno.ejemplo.com
proxy-headers=xforwarded
proxy-trusted-addresses=10.0.1.10,10.0.1.11
https-certificate-file=/etc/keycloak/tls.crt
https-certificate-key-file=/etc/keycloak/tls.key
health-enabled=true
metrics-enabled=true
cache-embedded-node-name=kc-node-1
log=console,file
log-console-output=json
log-file=/var/log/keycloak/keycloak.log
http-max-queued-requests=1000
```
Luego: `bin/kc.sh build && bin/kc.sh start --optimized`.

## 5. systemd

```ini
# /etc/systemd/system/keycloak.service
[Unit]
Description=Keycloak
After=network-online.target
[Service]
User=keycloak
Group=keycloak
EnvironmentFile=/etc/keycloak/keycloak.env
Environment=JAVA_OPTS_APPEND=-Djava.net.preferIPv4Stack=true
ExecStart=/opt/keycloak/bin/kc.sh start --optimized
LimitNOFILE=102642
TimeoutStopSec=30
Restart=on-failure
[Install]
WantedBy=multi-user.target
```

## 6. Realm JSON mínimo

```json
{
  "realm": "demo",
  "enabled": true,
  "sslRequired": "external",
  "registrationAllowed": false,
  "loginWithEmailAllowed": true,
  "bruteForceProtected": true,
  "passwordPolicy": "length(12) and notUsername and notEmail",
  "accessTokenLifespan": 300,
  "roles": { "realm": [ { "name": "user" }, { "name": "admin" } ] },
  "clientScopes": [
    {
      "name": "orders-api-audience",
      "protocol": "openid-connect",
      "attributes": { "include.in.token.scope": "false" },
      "protocolMappers": [{
        "name": "aud-orders-api",
        "protocol": "openid-connect",
        "protocolMapper": "oidc-audience-mapper",
        "config": { "included.client.audience": "orders-api", "access.token.claim": "true", "id.token.claim": "false" }
      }]
    }
  ],
  "clients": [
    {
      "clientId": "web",
      "publicClient": true,
      "standardFlowEnabled": true,
      "directAccessGrantsEnabled": false,
      "implicitFlowEnabled": false,
      "redirectUris": [ "https://app.ejemplo.com/*" ],
      "webOrigins": [ "+" ],
      "attributes": {
        "pkce.code.challenge.method": "S256",
        "post.logout.redirect.uris": "+"
      },
      "defaultClientScopes": [ "basic", "profile", "email", "roles", "web-origins", "acr", "orders-api-audience" ]
    },
    {
      "clientId": "orders-api",
      "publicClient": false,
      "bearerOnly": false,
      "standardFlowEnabled": false,
      "directAccessGrantsEnabled": false,
      "serviceAccountsEnabled": false
    },
    {
      "clientId": "billing-job",
      "publicClient": false,
      "secret": "${BILLING_JOB_SECRET}",
      "standardFlowEnabled": false,
      "serviceAccountsEnabled": true,
      "defaultClientScopes": [ "basic", "roles", "orders-api-audience" ]
    }
  ],
  "users": [
    {
      "username": "ana",
      "email": "ana@ejemplo.com",
      "firstName": "Ana",
      "lastName": "Pérez",
      "enabled": true,
      "emailVerified": true,
      "realmRoles": [ "user", "default-roles-demo" ],
      "credentials": [ { "type": "password", "value": "${ANA_PASSWORD}", "temporary": true } ]
    }
  ]
}
```
Nota: "rutas URI" con `/*` son prefijos; en producción preferir rutas exactas de callback.

## 7. Bootstrap con kcadm

```bash
#!/usr/bin/env bash
set -euo pipefail
KCADM=/opt/keycloak/bin/kcadm.sh
$KCADM config credentials --server "$KC_URL" --realm master --user "$ADMIN_USER" --password "$ADMIN_PASS"

$KCADM get realms/demo >/dev/null 2>&1 || $KCADM create realms -s realm=demo -s enabled=true
$KCADM update realms/demo -s sslRequired=external -s bruteForceProtected=true -s loginWithEmailAllowed=true

if [ -z "$($KCADM get clients -r demo -q clientId=web --fields id --format csv --noquotes)" ]; then
  $KCADM create clients -r demo -s clientId=web -s publicClient=true -s directAccessGrantsEnabled=false \
    -s 'redirectUris=["https://app.ejemplo.com/callback"]' -s 'webOrigins=["https://app.ejemplo.com"]' \
    -s 'attributes."pkce.code.challenge.method"=S256'
fi

# Admin permanente con rol realm-admin del realm demo
$KCADM create users -r demo -s username=ops -s enabled=true || true
$KCADM set-password -r demo --username ops --new-password "$OPS_PASS" --temporary
$KCADM add-roles -r demo --uusername ops --cclientid realm-management --rolename realm-admin
```

## 8. Probar Authorization Code + PKCE (manual)

```bash
KC=https://auth.ejemplo.com/realms/demo
VERIFIER=$(openssl rand -base64 60 | tr -d '\n=+/' | cut -c1-64)
CHALLENGE=$(printf %s "$VERIFIER" | openssl dgst -sha256 -binary | openssl base64 | tr '+/' '-_' | tr -d '=')
echo "$KC/protocol/openid-connect/auth?client_id=web&response_type=code&scope=openid&redirect_uri=https://app.ejemplo.com/callback&code_challenge=$CHALLENGE&code_challenge_method=S256&state=xyz"
# Abrir la URL, loguearse, copiar ?code=... de la redirección:
curl -s -X POST "$KC/protocol/openid-connect/token" \
  -d grant_type=authorization_code -d client_id=web -d code="$CODE" \
  -d redirect_uri=https://app.ejemplo.com/callback -d code_verifier="$VERIFIER" | jq .
```
Decodificar un token: `cut -d. -f2 <<<"$AT" | tr '_-' '/+' | base64 -d 2>/dev/null | jq .`

## 9. Express: validar JWT y roles

```js
import express from 'express';
import { createRemoteJWKSet, jwtVerify } from 'jose';

const ISSUER = process.env.KC_ISSUER; // https://auth.ejemplo.com/realms/demo
const JWKS = createRemoteJWKSet(new URL(`${ISSUER}/protocol/openid-connect/certs`));

function requireAuth({ audience, realmRoles = [], clientRoles = {} } = {}) {
  return async (req, res, next) => {
    const auth = req.headers.authorization ?? '';
    if (!auth.startsWith('Bearer ')) return res.status(401).json({ error: 'missing_token' });
    try {
      const { payload } = await jwtVerify(auth.slice(7), JWKS, { issuer: ISSUER, audience });
      const rr = payload.realm_access?.roles ?? [];
      const okRealm = realmRoles.every(r => rr.includes(r));
      const okClient = Object.entries(clientRoles).every(([c, roles]) =>
        roles.every(r => payload.resource_access?.[c]?.roles?.includes(r)));
      if (!okRealm || !okClient) return res.status(403).json({ error: 'insufficient_role' });
      req.user = payload;
      next();
    } catch (e) {
      res.status(401).json({ error: 'invalid_token' });
    }
  };
}

const app = express();
app.get('/orders', requireAuth({ audience: 'orders-api', realmRoles: ['user'] }), (req, res) =>
  res.json({ sub: req.user.sub, user: req.user.preferred_username }));
app.listen(3000);
```

## 10. Spring Boot 3 resource server

```yaml
# application.yml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: https://auth.ejemplo.com/realms/demo
          audiences: orders-api        # Spring Boot 3.2+
```
```java
@Configuration
@EnableMethodSecurity
class SecurityConfig {
  @Bean SecurityFilterChain api(HttpSecurity http) throws Exception {
    http.authorizeHttpRequests(a -> a.anyRequest().authenticated())
        .oauth2ResourceServer(o -> o.jwt(j -> j.jwtAuthenticationConverter(keycloakRoles())));
    return http.build();
  }
  Converter<Jwt, AbstractAuthenticationToken> keycloakRoles() {
    return jwt -> {
      Map<String, Object> ra = jwt.getClaimAsMap("realm_access");
      Collection<String> roles = ra == null ? List.of() : (Collection<String>) ra.getOrDefault("roles", List.of());
      var auths = roles.stream().map(r -> new SimpleGrantedAuthority("ROLE_" + r)).toList();
      return new JwtAuthenticationToken(jwt, auths, jwt.getClaimAsString("preferred_username"));
    };
  }
}
// @PreAuthorize("hasRole('admin')") en los métodos
```
