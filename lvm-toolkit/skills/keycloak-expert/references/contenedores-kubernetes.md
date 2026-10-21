# Contenedores, Kubernetes, Operator y alta disponibilidad

## Contenido
1. Imagen oficial y modo desarrollo
2. Imagen optimizada (Containerfile)
3. Docker/Podman en producción
4. Keycloak Operator: instalación y CRs
5. Realm import y clientes declarativos
6. Rolling updates y upgrades
7. Alta disponibilidad (single-cluster y multi-cluster v2)
8. Kubernetes sin Operator (Helm/manifiestos)

## 1. Imagen oficial

- Registro: `quay.io/keycloak/keycloak:<versión>` (fija versión exacta, p. ej. `26.8.0`; evita `latest` en producción). Base UBI9-micro: sin `dnf`/`rpm`/`curl`; usa `ADD` para descargar y builds multi-stage para paquetes.
- Arquitecturas: amd64, arm64, ppc64le (26.5).
- Dev rápido:
```bash
docker run --name kc -p 127.0.0.1:8080:8080 \
  -e KC_BOOTSTRAP_ADMIN_USERNAME=admin -e KC_BOOTSTRAP_ADMIN_PASSWORD=admin \
  quay.io/keycloak/keycloak:26.8.0 start-dev
```
- Importar realms al arrancar: montar JSON en `/opt/keycloak/data/import` + `--import-realm` (si el realm ya existe, se omite).
- Memoria: `-XX:MaxRAMPercentage=70 -XX:InitialRAMPercentage=50` sobre el límite del contenedor ⇒ **fija siempre el límite** (`-m 2g`, `resources.limits.memory`). Override con `JAVA_OPTS_KC_HEAP`; extras con `JAVA_OPTS_APPEND`.

## 2. Imagen optimizada

```dockerfile
FROM quay.io/keycloak/keycloak:26.8.0 AS builder
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true
ENV KC_DB=postgres
# ENV KC_FEATURES=token-exchange-delegation,parameterized-scopes
# Providers y temas ANTES del build:
# ADD --chown=keycloak:keycloak --chmod=644 https://.../mi-provider.jar /opt/keycloak/providers/
# COPY --chown=keycloak:keycloak themes/mitema /opt/keycloak/themes/mitema
# RUN touch -m --date=@1743465600 /opt/keycloak/providers/*   # si Docker altera timestamps
RUN /opt/keycloak/bin/kc.sh build

FROM quay.io/keycloak/keycloak:26.8.0
COPY --from=builder /opt/keycloak/ /opt/keycloak/
ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
CMD ["start", "--optimized"]
```

- Certificados CA propios: stage `registry.access.redhat.com/ubi9` con `update-ca-trust` y `COPY --from=... /etc/pki /etc/pki`, o mejor `--truststore-paths`.
- Paquetes RPM extra: instalar con `dnf --installroot /mnt/rootfs` en stage UBI9 y copiar `/mnt/rootfs` (aumenta superficie de ataque).
- Entrypoint propio: terminar con `exec /opt/keycloak/bin/kc.sh start "$@"`. Log de apagado correcto: `Keycloak stopped in ...`.
- Para el Operator la imagen **debe** estar optimizada (todas las build options fijadas) y se indica en `spec.image` (+ `spec.startOptimized: true` si aplica; verificar en customizing-keycloak).

## 3. Docker/Podman en producción

Arranque típico:
```bash
docker run -d --name kc -p 8443:8443 -p 127.0.0.1:9000:9000 -m 2g \
  -e KC_DB_URL=jdbc:postgresql://db:5432/keycloak \
  -e KC_DB_USERNAME=keycloak -e KCRAW_DB_PASSWORD='s3cr$t' \
  -e KC_HOSTNAME=https://auth.ejemplo.com \
  -e KC_PROXY_HEADERS=xforwarded -e KC_HTTP_ENABLED=true \
  -e KC_BOOTSTRAP_ADMIN_USERNAME=tmpadmin -e KC_BOOTSTRAP_ADMIN_PASSWORD=change_me \
  mi-keycloak:26.8.0 start --optimized
```
Con `--hostname` en un puerto no estándar, usa URL completa (`--hostname=https://localhost:3000`). Ver `plantillas.md` para docker-compose completo.

## 4. Keycloak Operator

Instalación: OLM/OperatorHub (OpenShift), `kubectl apply` de los manifiestos/CRDs de la versión (`https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/<versión>/kubernetes/...`), **kustomize** (26.7) o Helm chart (experimental, 26.8). Modo cluster-wide (`AllNamespaces`) en preview (26.7). Ver `/operator/installation`.

El Operator **no** gestiona la base de datos. Crea Deployment/StatefulSet, Service (`<cr>-service`, configurable con `spec.http.serviceName`), Ingress opcional, NetworkPolicy, ServiceMonitor (si existe la CRD de Prometheus) y el secret de admin inicial `<cr>-initial-admin`.

CR básico (**apiVersion `k8s.keycloak.org/v2beta1`**; muchos ejemplos viejos usan `v2alpha1`):

```yaml
apiVersion: k8s.keycloak.org/v2beta1
kind: Keycloak
metadata:
  name: kc
spec:
  instances: 3
  image: registry.ejemplo.com/mi-keycloak:26.8.0   # opcional (optimizada)
  db:
    vendor: postgres
    host: postgres-rw
    database: keycloak
    usernameSecret: { name: keycloak-db-secret, key: username }
    passwordSecret: { name: keycloak-db-secret, key: password }
  http:
    tlsSecret: kc-tls          # kubernetes.io/tls
  hostname:
    hostname: auth.ejemplo.com
  proxy:
    headers: xforwarded        # si no se pone, cae a comportamiento legacy deprecado
  ingress:
    enabled: true
    className: nginx
  networkPolicy:
    enabled: true
  resources:
    requests: { cpu: "1", memory: 1500Mi }
    limits:   { memory: 2Gi }
  additionalOptions:
    - name: log-console-output
      value: json
    - name: db-password-extra   # ejemplo con secreto
      secret: { name: otro-secret, key: valor }
  features:
    enabled: [ "token-exchange-delegation", "parameterized-scopes" ]
  update:
    strategy: Auto             # rolling update cuando sea compatible
```

Campos útiles adicionales (verificar en advanced-configuration): `spec.cache.configMapFile`, `spec.truststores`, `spec.scheduling` (afinidad, tolerations, topologySpreadConstraints), `spec.unsupported.podTemplate` (no soportado), `spec.telemetry`, `spec.serviceMonitor`, `spec.bootstrapAdmin`, `spec.http.serviceHttpsPort`, `spec.ingress.tlsSecret` (re-encrypt/edge), `spec.startOptimized`.

Estado: `kubectl get keycloaks/kc -o jsonpath='{.status.conditions}'` (condiciones `Ready`, `HasErrors`, `RollingUpdate`). Credenciales iniciales:
```bash
kubectl get secret kc-initial-admin -o jsonpath='{.data.username}' | base64 -d
kubectl get secret kc-initial-admin -o jsonpath='{.data.password}' | base64 -d
```

Terminación TLS con Ingress: passthrough (`http.tlsSecret` sin `ingress.tlsSecret`; sin IP real del cliente), edge (`http.httpEnabled: true` + `proxy.headers`), re-encrypt (anotación del Route/Ingress). Con edge/re-encrypt activa `networkPolicy` para que solo el ingress controller llegue a Keycloak.

Seguridad: quien pueda editar CRs del Operator debe ser admin del namespace (puede cambiar la imagen y leer secrets).

## 5. Realm import y clientes declarativos

`KeycloakRealmImport` (Job que importa un realm completo; **solo crea**: si el realm existe, no lo actualiza; soporta placeholders `${...}` desde secrets/env):
```yaml
apiVersion: k8s.keycloak.org/v2beta1
kind: KeycloakRealmImport
metadata: { name: demo-import }
spec:
  keycloakCRName: kc
  realm:
    realm: demo
    enabled: true
    clients:
      - clientId: web
        publicClient: true
        redirectUris: ["https://app.ejemplo.com/*"]
        webOrigins: ["https://app.ejemplo.com"]
        attributes: { pkce.code.challenge.method: S256 }
  placeholders:
    SMTP_PASS: { secret: { name: smtp, key: password } }
```
Para gestión continua usa: CRs `KeycloakOIDCClient`/`KeycloakSAMLClient` (preview, requieren `client-admin-api:v2`), Terraform o keycloak-config-cli.

## 6. Rolling updates y upgrades

- Cambios de config/temas/providers en imágenes optimizadas y **patch releases** dentro del mismo `major.minor` pueden hacerse sin downtime (supported y por defecto desde 26.6). Con Operator: `spec.update.strategy: Auto` (el Operator ejecuta el chequeo de compatibilidad) o `Explicit` con `revision`.
- Manual: `bin/kc.sh update-compatibility metadata --file=old.json` en la versión vieja y `update-compatibility check --file=old.json` en la nueva ⇒ indica si se puede hacer rolling o requiere recreate.
- Upgrades de versión menor/mayor: normalmente **recreate** (apagar todos, migrar BD, levantar). Backup de BD antes. Lee el upgrading guide de cada versión intermedia (puedes saltar versiones; la migración de esquema es acumulativa).

## 7. Alta disponibilidad

- **Single-cluster** (supported): varios pods en un cluster K8s, opcionalmente repartidos en AZs (topologySpreadConstraints) + BD multi-AZ (p. ej. Aurora o CloudNativePG con réplicas síncronas). Clustering automático por `jdbc-ping`.
- **Multi-cluster v2** (supported 26.8): dos+ clusters independientes (K8s o bare metal) con `--features=stateless`, `--cache-embedded-cluster-name` distinto por cluster, misma BD replicada **síncronamente** entre sitios, invalidación vía outbox en BD, balanceador global que chequea `/lb-check`. No requiere Infinispan externo ni fencing.
- **Multi-cluster v1** (`multi-site`, deprecado): Infinispan externo con cross-site replication. Migrar con la guía `migrate-from-v1-to-v2`.
- Sizing (guía scaling-and-tuning, orientativo, verificar): CPU proporcional a logins/s (hash de contraseñas es lo más caro: argon2/pbkdf2) y a refresh/s; memoria base ~1,25 GB por pod + sesiones cacheadas.

## 8. Kubernetes sin Operator

- Imagen optimizada como Deployment/StatefulSet ≥2 réplicas, Service headless no necesario con `jdbc-ping`.
- Probes en puerto 9000 (`/health/started|live|ready`), `terminationGracePeriodSeconds` > `shutdown-delay`+`shutdown-timeout`.
- `KC_CACHE_EMBEDDED_NODE_NAME` desde la downward API (`metadata.name`).
- Abrir 7800/57800 entre pods (NetworkPolicy). Charts comunitarios (p. ej. Bitnami/codecentric "keycloakx") existen pero no son oficiales: revisa que usen la distribución Quarkus y opciones actuales.
