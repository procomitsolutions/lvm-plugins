# Servidor: configuración, red, BD, clustering y producción

## Contenido
1. Comandos y modos
2. Fuentes y formatos de configuración
3. Build options vs runtime (`--optimized`)
4. Hostname v2
5. Reverse proxy y TLS
6. Base de datos
7. Caché, clustering y sesiones
8. Interfaz de management, health y métricas
9. Logging y observabilidad
10. Otras opciones útiles
11. Checklist de producción
12. Troubleshooting rápido

## 1. Comandos y modos

`bin/kc.sh` (`kc.bat` en Windows). Subcomandos: `start-dev`, `start`, `build`, `import`, `export`, `bootstrap-admin`, `show-config`, `tools`, `update-compatibility`. `--help` en cada uno lista sus opciones.

| | `start-dev` | `start` |
|---|---|---|
| HTTP | habilitado | deshabilitado (requiere TLS) |
| Hostname | no estricto | obligatorio `--hostname` (o `--hostname-strict=false`) |
| Caché | `local` | `ispn` (cluster automático) |
| Temas | sin caché | con caché |
| BD por defecto | `dev-file` | `dev-file` (deprecado en prod: define `--db`) |

Puertos por defecto: `8080` (HTTP), `8443` (HTTPS), `9000` (management: health/metrics), `7800` y `57800` (JGroups entre nodos).

Admin inicial: `KC_BOOTSTRAP_ADMIN_USERNAME` y `KC_BOOTSTRAP_ADMIN_PASSWORD` (también se puede crear desde `localhost` en la UI). Crea un admin **temporal** en `master`; después crea uno permanente (idealmente con MFA) y borra el temporal. Si se pierde el acceso: `bin/kc.sh bootstrap-admin user` (o `service` para un cliente con service account) con la misma config de BD, sin necesidad de levantar el servidor completo.

## 2. Fuentes y formatos de configuración

Prioridad (gana la primera): **CLI → variables de entorno → `conf/keycloak.conf` (o `--config-file`) → KeyStore de config**.

| Fuente | Formato |
|---|---|
| CLI | `--db-url-host=valor` |
| Env | `KC_DB_URL_HOST=valor` (o `KCRAW_...` para literales con `$`) |
| keycloak.conf | `db-url-host=valor` (soporta `${ENV_VAR:default}`) |
| KeyStore PKCS12 | alias `kc.db-password` (`--config-keystore`, `--config-keystore-password`) |

- Escapa `$` con `\` en valores (`my\$\$password`) o usa `KCRAW_`. No pueden coexistir `KC_X` y `KCRAW_X`.
- Claves con caracteres especiales en env: par `KC_<ID>=valor` + `KCKEY_<ID>=clave-original`.
- Opciones de primera clase vs de segunda clase (Quarkus/SPI): usa siempre las de primera clase; `conf/quarkus.properties` no está soportado.
- Opciones SPI: `--spi-<spi-id>--<provider-id>--<propiedad>` (doble guion). Env: `KC_SPI_<SPI>__<PROVIDER>__<PROP>` (doble guion bajo).
- Variables de sistema en la config del realm: solo las listadas en `--spi-admin--allowed-system-variables` (capacidad a eliminar).

## 3. Build options vs runtime

Keycloak usa re-augmentación de Quarkus. `start` hace un `build` implícito si detecta cambios (lento). Para producción/contenedores:

```bash
bin/kc.sh build --db=postgres --health-enabled=true --metrics-enabled=true --features=...
bin/kc.sh start --optimized --hostname=https://auth.ejemplo.com ...
```

- Build options (icono de herramienta en all-config): `db`, `features`, `features-disabled`, `health-enabled`, `metrics-enabled`, `http-relative-path`, `cache`-tipo, `transaction-xa-enabled`, `spi-*--provider` (selección de provider), providers instalados, etc. Lista: `https://www.keycloak.org/server/all-config?f=build`.
- Con `--optimized`, una build option con valor distinto al del build ⇒ error. Re-ejecuta `build`.
- Las build options se persisten en texto plano: nada sensible ahí.
- `bin/kc.sh show-config` muestra la configuración efectiva y su fuente.

## 4. Hostname v2

Keycloak no resuelve URLs dinámicamente por defecto (evita que un atacante altere links de emails, issuer, etc.).

| Escenario | Opciones |
|---|---|
| URL pública fija (recomendado) | `--hostname=https://auth.ejemplo.com` |
| Con context path en el proxy | `--hostname=https://ejemplo.com/auth` o `--http-relative-path=/auth` o `xforwarded` + `X-Forwarded-Prefix` |
| Solo nombre (esquema/puerto/path dinámicos) | `--hostname=auth.ejemplo.com --proxy-headers=xforwarded` |
| Backchannel por red interna | `--hostname=https://auth.ejemplo.com --hostname-backchannel-dynamic=true` (hostname debe ser URL completa) |
| Consola admin en otro host | `--hostname-admin=https://admin.ejemplo.com:8443` (requiere `hostname` como URL; no bloquea la Admin API en el host público: hazlo en el proxy) |
| Totalmente dinámico (con cuidado) | `--hostname-strict=false --proxy-headers=forwarded` |
| Por realm | Realm settings → General → Frontend URL |

Reglas: en `start` debe haber `--hostname` o `--hostname-strict=false`. Si no hay `--hostname`, `hostname-backchannel-dynamic` y `hostname-strict` deben ser `false`. Las opciones no cambian los puertos de escucha (`--http-port`, `--https-port`). Depurar: `--hostname-debug=true` → `/realms/<realm>/hostname-debug`.

Eliminadas en 26.0 (hostname v1): `hostname-url`, `hostname-admin-url`, `hostname-port`, `hostname-path`, `hostname-strict-https`, `hostname-strict-backchannel`.

## 5. Reverse proxy y TLS

### Modos
| Modo | Proxy ↔ Keycloak | Opciones Keycloak |
|---|---|---|
| Re-encrypt (recomendado) | TLS | `--proxy-headers=xforwarded|forwarded`, `--proxy-trusted-addresses=IPs/CIDR`, certificado propio en Keycloak |
| Edge | HTTP | `--http-enabled=true --proxy-headers=...` |
| Passthrough | TLS de punta a punta | **sin** `--proxy-headers`; `--proxy-protocol-enabled=true`; `--shutdown-delay` 10–30 s; ideal para mTLS/X.509 |

Seguridad: Keycloak solo debe aceptar conexiones del proxy (firewall/NetworkPolicy). El proxy debe **sobrescribir** `Forwarded`/`X-Forwarded-*` y **eliminar** `X-Real-IP`, `X-Original-URL`, `X-Original-Forwarded-For`, `X-Forwarded-Access-Token` y headers de tracing (`traceparent`, `baggage`, `b3`…) entrantes.

Rutas a exponer: `/realms/`, `/resources/`, `/.well-known/` (RFC 8414; mapear sin prefijo si usas `http-relative-path`), `/lb-check` (solo con `stateless`/`multi-site`). No exponer: `/`, `/admin/`, `/realms/master/`, `/metrics`, `/health`, puerto 9000.

Sticky sessions: desde 26.6 ya no aportan beneficio relevante; reparte carga de forma pareja. Las opciones `spi-sticky-session-encoder--*--should-attach-route` están deprecadas (26.8).

Client certificate lookup (X.509 detrás de proxy con terminación): build `--spi-x509cert-lookup--provider=<apache|haproxy|nginx|traefik|envoy|rfc9440>` y runtime `--spi-x509cert-lookup--<provider>--ssl-client-cert=<HEADER>` (+ `ssl-cert-chain`/`ssl-cert-chain-prefix`, `certificate-chain-length`). Riesgo alto si el proxy no sobrescribe el header; prefiere passthrough.

Graceful shutdown: `--shutdown-delay` (def. 1s; readiness pasa a DOWN) y `--shutdown-timeout` (def. 10s). En K8s, `terminationGracePeriodSeconds` > suma de ambos. Si usas un entrypoint propio, arranca con `exec` para recibir SIGTERM.

### TLS
- PEM: `--https-certificate-file=cert.pem --https-certificate-key-file=key.pem` (clave PKCS#8 cifrada: `--https-certificate-key-file-password`, 26.8).
- Keystore: `--https-key-store-file=server.keystore --https-key-store-password=...` (por defecto busca `conf/server.keystore`).
- Recarga de certificados sin reinicio: `--https-certificates-reload-period` (verificar nombre en all-config).
- Protocolos/cifrados: `--https-protocols` (TLSv1.3 por defecto), `--https-cipher-suites`.
- mTLS de clientes: `--https-client-auth=request|required` + truststore (`/server/mutual-tls`).
- Truststore saliente (LDAP, IdPs, SMTP, BD): `--truststore-paths=/ruta/ca.pem,/ruta/dir` o archivos en `conf/truststores/`; en K8s los CA del service account se añaden automáticamente (`--truststore-kubernetes-enabled`). `--tls-hostname-verifier` controla la verificación.

## 6. Base de datos

| BD | `--db` | Versiones soportadas (26.8) |
|---|---|---|
| PostgreSQL | `postgres` | 14–18 (EDB 17–18, Aurora PG 15–17) |
| MySQL | `mysql` | 8.0, 8.4 |
| MariaDB | `mariadb` | 10.6, 10.11, 11.4, 11.8 (LTS) |
| SQL Server | `mssql` | 2019, 2022, Azure SQL / MI |
| Oracle | `oracle` | 19c (19.3+), 23.x; RAC con misma versión. Driver NO incluido: `ojdbc17` + `orai18n` en `providers/` |
| TiDB | `tidb` | feature `db-tidb` (verificar estado) |

Opciones: `--db`, `--db-url-host`, `--db-url-port`, `--db-url-database`, `--db-url-properties`, `--db-url` (JDBC completo), `--db-username`, `--db-password`, `--db-schema`, `--db-pool-min-size`, `--db-pool-max-size` (def. 100), `--db-pool-initial-size`, `--db-pool-max-lifetime`, `--db-connect-timeout` (def. 10s), `--transaction-default-timeout` (def. 5m), `--transaction-setup-timeout` (def. 30m, migraciones/import), `--db-log-slow-queries-threshold`.

TLS a la BD (unificado): `--db-tls-mode=verify-server --db-tls-trust-store-file=/ruta/ca.pem` (+ `db-mtls-key-store-*` para mTLS). Postgres: truststore PEM, keystore PKCS#12 con alias `user`. MySQL: rutas con `file://`.

Notas por motor:
- **Postgres**: Keycloak fija `targetServerType=primary`. Dar `SELECT` en `pg_class`/`pg_namespace` para upgrades eficientes. Commits asíncronos en tablas efímeras (desactivar: `--spi-connections-jpa--quarkus--async-commit=false`).
- **Aurora**: AWS JDBC wrapper en `providers/`, `--db-url=jdbc:aws-wrapper:postgresql://...`, `--db-driver=software.amazon.jdbc.Driver`, plugin `failover`.
- **MySQL/MariaDB**: `utf8mb4`; charset/collation consistentes antes de migrar; `sql_generate_invisible_primary_key=OFF`; `db-pool-max-lifetime` < `wait_timeout`; con `stateless` usa READ COMMITTED (requiere `binlog_format` ROW o MIXED). Galera no soportado.
- **MSSQL**: `ALTER DATABASE kc SET READ_COMMITTED_SNAPSHOT ON;` (con todos los nodos apagados); opcional `DELAYED_DURABILITY = ALLOWED`.
- **Oracle**: `AL32UTF8`.

Migración de esquema: automática al arrancar (`update`). Control manual: `--spi-connections-jpa--quarkus--migration-strategy=manual` (+ `--spi-connections-jpa--quarkus--migration-export=/ruta/file.sql`). Desde 26.8 los índices omitidos en tablas grandes se crean en background (no bloqueante).

Datasources adicionales (para extensiones): `--db-kind-<ds>=postgres`, `--db-username-<ds>`, … + `META-INF/persistence.xml` con `transaction-type="JTA"` y `jakarta.persistence.jtaDataSource`. Excluir del health: `--db-health-exclude-<ds>=true`.

Cifrado en reposo: TDE del motor o cifrado de disco, incluyendo WAL/redo y backups.

## 7. Caché, clustering y sesiones

- `start` ⇒ `--cache=ispn` (Infinispan embebido) y descubrimiento automático vía **`jdbc-ping`** (usa la BD; TCP; TLS 1.3 automático con certificados autogenerados y rotados cada 30 días). Abre `7800/tcp` y `57800/tcp` entre nodos. Los stacks `kubernetes`, `tcp`, `udp`, `ec2`, `azure`, `google`, `jdbc-ping-udp` están deprecados.
- Cachés locales (realms, users, authorization: 10 000 entradas; keys: 1 000, expiran 1 h) invalidadas vía caché replicada `work`. Distribuidas: `authenticationSessions`, `sessions`, `clientSessions`, `offlineSessions`, `offlineClientSessions`, `actionTokens`.
- **Sesiones persistentes en BD** (por defecto desde 26.0): sobreviven a reinicios; las cachés solo aceleran (10 000 por nodo, `--cache-embedded-sessions-max-count`…). Desactivar caché de sesiones: `--spi-user-sessions--infinispan--use-caches=false`. Modo volátil deprecado (26.8).
- **Login failures (brute force) en BD** por defecto desde 26.8.
- Tamaños: `--cache-embedded-<cache>-max-count` (`realms`, `users`, `authorization`, `keys`, `crl`, `sessions`, `client-sessions`, `offline-sessions`, `offline-client-sessions`).
- Identificación: `--cache-embedded-cluster-name` (solo con `stateless` si hay varios clusters en la misma BD), `--cache-embedded-node-name` (estable para observabilidad; el Operator usa el nombre del pod).
- Topología: `--spi-cache-embedded--default--site-name|rack-name|machine-name`.
- Red: `--cache-embedded-network-bind-address` (`SITE_LOCAL` por defecto; `match-interface:eth.*`…), `--cache-embedded-network-bind-port`, `--cache-embedded-network-external-address|port`.
- Service mesh (Istio): permitir mTLS directo en el puerto 7800 (`PeerAuthentication` PERMISSIVE) o `--cache-embedded-mtls-enabled=false` y que la malla cifre.
- Infinispan externo (`--cache-remote-host`, `-port` 11222, `-username`, `-password`, `-tls-enabled`) solo con `multi-site` (deprecado) o `clusterless`.
- Verificar cluster: log `ISPN000094` (vista del cluster), métrica `vendor_cluster_size`, Admin Console → master → Provider info → connectionsInfinispan.
- XML propio: `--cache-config-file` (modificar cachés por defecto no está soportado; `--cache-config-mutate=true` para silenciar el aviso).

Multi-cluster v2: `--features=stateless`, BD replicada sincrónicamente, invalidación entre clusters por tabla outbox, `/lb-check` para el balanceador. Ver `contenedores-kubernetes.md`.

## 8. Management interface, health y métricas

- Puerto `9000` (`--http-management-port`), mismo esquema TLS que el principal (o certificado propio `--https-management-certificate-file`…; desde 26.4 puede ir por HTTP con `--http-management-scheme=http`, verificar). Health también en el puerto principal si se configura (26.4, verificar opción).
- Build options: `--health-enabled=true`, `--metrics-enabled=true`.
- Endpoints: `/health`, `/health/started`, `/health/live`, `/health/ready` (incluye BD; readiness DOWN durante bootstrap y shutdown), `/metrics` (Prometheus).
- Probes K8s: startup → `/health/started`, liveness → `/health/live`, readiness → `/health/ready`. Durante migraciones de BD, startup/liveness devuelven UP (26.6) gracias a `--server-async-bootstrap` (por defecto); `--server-async-bootstrap=false` abre puertos solo al terminar.
- Métricas de eventos de usuario: `--event-metrics-user-enabled=true` (+ `--event-metrics-user-events`, `--event-metrics-user-tags`). Histogramas HTTP: `--http-metrics-histograms-enabled`, SLOs `--http-metrics-slos`. Caché: `--cache-metrics-histograms-enabled`.
- Dashboards Grafana oficiales (guía grafana-dashboards). Trazas OpenTelemetry: `--tracing-enabled=true --tracing-endpoint=http://otel:4317` (`--telemetry-*` comunes; logs/métricas OTel vía features `opentelemetry-logs`/`opentelemetry-metrics`).

## 9. Logging

- `--log=console,file,syslog`; nivel `--log-level=INFO,org.keycloak.events:debug,org.hibernate:warn` o por categoría `--log-level-org.keycloak=debug`.
- Formato: `--log-console-output=json` (`--log-console-json-format=ecs`), `--log-file=/ruta/keycloak.log`, rotación `--log-file-rotation-enabled=false` (26.6). `--log-service-name`, `--log-service-environment` en JSON.
- Async: `--log-async=true` (26.3). MDC: `--log-mdc-enabled=true` (realm/client/usuario en logs).
- Access log HTTP: `--http-access-log-enabled=true` (oculta tokens/cookies sensibles; archivo dedicado desde 26.6).
- GELF fue eliminado (26.0): usa syslog, JSON a stdout u OTel.
- Eventos de login/admin en logs: listener `jboss-logging` (habilitado por defecto) a nivel `debug` para éxitos y `warn` para errores; ajustar con `--spi-events-listener--jboss-logging--success-level=info`.

## 10. Otras opciones útiles

- `--http-max-queued-requests=N` (load shedding: 503 al superar).
- `--http-pool-max-threads` (verificar), `--http-port`, `--https-port`, `--http-host`.
- Vault: `--vault=file --vault-dir=/run/secrets` (secretos como `${vault.<clave>}` en SMTP, LDAP bind, IdP secret, client secrets desde 26.6) o `--vault=keystore --vault-file=... --vault-pass=...`.
- Salidas HTTP (IdPs, webhooks): proxy saliente `--spi-connections-http-client--default--proxy-mappings`, timeouts y reintentos (guía outgoinghttp).
- FIPS: `--features=fips --fips-mode=strict|non-strict` + BCFIPS en `providers/`; la imagen oficial sigue con OpenJDK 21 por FIPS.
- IPv4 only: `JAVA_OPTS_APPEND="-Djava.net.preferIPv4Stack=true"`. Heap en contenedor: `JAVA_OPTS_KC_HEAP`.
- Mejora preview: `--features=http-optimized-serializers` (~5 % throughput).

## 11. Checklist de producción

1. `start --optimized` sobre imagen/instalación construida; OpenJDK 21/25 soportado.
2. `--hostname` como URL pública; `--hostname-admin` opcional; proxy en re-encrypt con `--proxy-headers` + `--proxy-trusted-addresses`, o passthrough con PROXY protocol.
3. TLS válido; truststore para dependencias salientes; BD con `--db-tls-mode=verify-server`.
4. BD soportada, UTF-8, backups cifrados, pool dimensionado (pool ≈ hilos esperados; no más que lo que la BD tolera).
5. ≥2 nodos, puertos 7800/57800 entre nodos, nombres de nodo estables, anti-afinidad.
6. Health/metrics en 9000 solo internos; probes configuradas; alertas en dashboards.
7. Proxy bloquea `/admin` y `/realms/master` desde internet; admin con MFA; borra admin bootstrap temporal.
8. Realms de negocio ≠ `master`. Brute force detection activada. Políticas de contraseña. SMTP configurado (verificación email/reset).
9. Clients: PKCE, redirect URIs exactas, sin Implicit/Password grant, tokens de corta vida, `Consent`/audiencias correctos.
10. Límite de memoria del contenedor (≥ 2 GB prod chica) y CPU según guía de sizing; `--http-max-queued-requests`.
11. Logs JSON centralizados, eventos de login/admin habilitados con expiración.
12. Plan de upgrade: leer upgrading guide; `kc.sh update-compatibility check` para saber si se puede hacer rolling update.

## 12. Troubleshooting rápido

| Síntoma | Causa probable | Solución |
|---|---|---|
| No arranca en `start`: "hostname not configured" | Falta hostname | `--hostname=...` |
| "HTTPS required" al acceder por HTTP | Realm `master` exige SSL para IPs externas | Usa HTTPS; o (solo dev) `kcadm.sh update realms/master -s sslRequired=NONE` desde localhost |
| Discovery muestra `http://` o puerto interno | Proxy sin headers | `--proxy-headers` + proxy que sobrescriba `X-Forwarded-Proto/Host/Port`, o hostname URL completa |
| `403` en login vía proxy | Chequeo de origen sin `--proxy-headers` | Configura `--proxy-headers` |
| `Invalid parameter: redirect_uri` | URI no registrada exactamente | Agrega la URI exacta (esquema, host, puerto, path) en Valid redirect URIs |
| CORS bloqueado desde SPA | `Web origins` vacío | Agrega el origen o `+` |
| `invalid_grant: Code not valid` | Código reutilizado / nodo sin cluster / reloj | Revisa clustering (`ISPN000094`), relojes NTP, que no se reintente el canje |
| Token rechazado por API: `iss` distinto | Frontend vs backchannel con distinto host | `--hostname` fijo; si backend usa red interna, `--hostname-backchannel-dynamic=true`; valida `iss` público |
| Nodos no forman cluster | Puertos 7800/57800 cerrados, bind address, cluster-name distinto, service mesh | Abrir puertos, `--cache-embedded-network-bind-address`, revisar Istio |
| `start --optimized` falla "build option changed" | Cambiaste build option | Re-ejecuta `kc.sh build` |
| Provider JAR "changed" en Docker | Timestamps alterados | `touch -m --date=@<epoch>` antes del build |
| Contenedor consume mucha RAM | Sin límite de memoria | Fija `-m`/limits; ajusta `JAVA_OPTS_KC_HEAP` |
| Migración MySQL "Multiple primary key defined (1068)" | GIPK activado | `sql_generate_invisible_primary_key=OFF` |
| Deadlocks MSSQL | Aislamiento por defecto | `READ_COMMITTED_SNAPSHOT ON` |
