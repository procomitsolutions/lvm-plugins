# Configuración y seguridad

## Contenido
1. ConfigMaps
2. Secrets y buenas prácticas
3. kubeconfig y acceso a la API (authn → authz → admission)
4. RBAC
5. ServiceAccounts y tokens
6. Pod Security Standards y Pod Security Admission
7. securityContext, seccomp, AppArmor, SELinux, capabilities
8. Admission control: webhooks, ValidatingAdmissionPolicy, MutatingAdmissionPolicy
9. Cifrado en reposo, auditoría, hardening y checklist
10. Multi-tenancy

---

## 1. ConfigMaps

- Pares clave/valor no confidenciales; límite 1 MiB.
- Consumo: `env.valueFrom.configMapKeyRef`, `envFrom.configMapRef` (todas las claves), volumen (cada clave = archivo), argumentos de comando vía `$(VAR)`.
- Variables de entorno **no se actualizan** en pods en ejecución; los volúmenes sí (con retraso del sync del kubelet, y nunca con `subPath`).
- `immutable: true`: protege de cambios accidentales y reduce carga del apiserver; para cambiar, crear uno nuevo (patrón: nombre con hash, como hace Kustomize con `configMapGenerator`).
- Crear: `kubectl create configmap app-config --from-file=config/ --from-literal=LOG_LEVEL=info --dry-run=client -o yaml`.

## 2. Secrets

Tipos: `Opaque`, `kubernetes.io/tls` (`tls.crt`, `tls.key`), `kubernetes.io/dockerconfigjson` (credenciales de registry), `kubernetes.io/basic-auth`, `kubernetes.io/ssh-auth`, `kubernetes.io/service-account-token` (legado), `bootstrap.kubernetes.io/token`.

- `data` va en base64; `stringData` acepta texto plano (se convierte al guardar).
- **No son cifrado**: cualquiera con `get` sobre secrets en el namespace (o que pueda crear pods allí) los lee.
- Buenas prácticas oficiales ("Good practices for Kubernetes Secrets"):
  - Cifrado en reposo en etcd (EncryptionConfiguration, idealmente con proveedor **KMS v2**).
  - RBAC de mínimo privilegio: evitar `list`/`watch` sobre secrets (list devuelve el contenido).
  - Montar como volumen antes que como variables de entorno (las env se filtran en logs, `/proc`, crash dumps).
  - `immutable: true` cuando aplique.
  - Gestores externos: External Secrets Operator, Secrets Store CSI Driver, Sealed Secrets, SOPS. Nunca commitear Secrets en claro.
- Pull de imágenes privadas: `kubectl create secret docker-registry regcred --docker-server=... --docker-username=... --docker-password=...` y `spec.imagePullSecrets` (o asociarlo al ServiceAccount). Alternativa sin secrets: kubelet image credential provider.

## 3. Acceso a la API

Flujo de cada request: **Autenticación → Autorización → Admission (mutating → validación de schema → validating) → etcd**.

**Autenticación**: certificados X.509 de cliente (CN = usuario, O = grupos), tokens de ServiceAccount (JWT con audiencia), OIDC (recomendado para humanos; también configuración estructurada `AuthenticationConfiguration` con varios emisores), webhook token, proxy de autenticación, bootstrap tokens. Kubernetes **no tiene objetos User**: los usuarios son externos.

**Autorización**: modos `Node`, `RBAC`, `Webhook`, `ABAC` (legado), `AlwaysAllow` (nunca en producción). kubeadm usa `Node,RBAC`.

**kubeconfig**: `clusters` + `users` + `contexts` (cluster+usuario+namespace). Ruta por `KUBECONFIG` (varias separadas por `:` se fusionan) o `~/.kube/config`.
```bash
kubectl config get-contexts
kubectl config use-context prod
kubectl config set-context --current --namespace=app
kubectl auth whoami
```

**Impersonation**: `kubectl --as=jane --as-group=devs get pods` (requiere verbo `impersonate`); muy útil para probar RBAC.

## 4. RBAC

- `Role` (namespaced) / `ClusterRole` (cluster-wide o reutilizable).
- `RoleBinding` (otorga en un namespace; puede referenciar un ClusterRole para reutilizarlo) / `ClusterRoleBinding` (en todo el cluster).
- Reglas: `apiGroups` (`""` = core), `resources` (y subrecursos: `pods/log`, `pods/exec`, `deployments/scale`), `verbs` (`get`, `list`, `watch`, `create`, `update`, `patch`, `delete`, `deletecollection`), `resourceNames`.
- ClusterRoles por defecto para usuarios: `cluster-admin`, `admin`, `edit`, `view`. **Agregación** con `aggregationRule` y labels `rbac.authorization.k8s.io/aggregate-to-*`.
- El `roleRef` de un binding es **inmutable**: hay que borrar y recrear.
- RBAC solo suma permisos; no hay "deny".

Verificar:
```bash
kubectl auth can-i create deployments -n app
kubectl auth can-i --list --as=system:serviceaccount:app:builder -n app
kubectl auth can-i get secrets --as=jane -n prod
```

**Buenas prácticas ("RBAC Good Practices")** — permisos peligrosos aunque parezcan inocentes:
- `list`/`watch` sobre secrets (exponen contenido).
- `create` sobre pods o workloads en un namespace = acceso a todo lo que pueda montar ese namespace (secrets, ServiceAccounts).
- `escalate`, `bind`, `impersonate`, `nodes/proxy`, `create` sobre `serviceaccounts/token`, `certificatesigningrequests/approval`, modificar webhooks.
- Evitar comodines `*`; no agregar usuarios a `system:masters` (salta toda autorización y no se puede revocar vía RBAC).
- Revisar periódicamente bindings a `cluster-admin`.

## 5. ServiceAccounts

- Identidad para procesos en pods. Cada namespace tiene `default`. Asignar con `spec.serviceAccountName`.
- Tokens modernos: **proyectados, con expiración y audiencia** (TokenRequest API), montados en `/var/run/secrets/kubernetes.io/serviceaccount/`. Ya no se crean Secrets de token de larga duración automáticamente (desde 1.24); si hace falta uno (evitar), Secret tipo `kubernetes.io/service-account-token` con la anotación del SA.
- Token manual de corta duración: `kubectl create token <sa> --duration=1h --audience=...`.
- `automountServiceAccountToken: false` (en el SA o el pod) si la app no usa la API.
- Para acceso a la nube: workload identity del proveedor (IRSA/EKS Pod Identity, GKE Workload Identity, Azure Workload Identity) federado con el token proyectado.

## 6. Pod Security Standards (PSS) y Pod Security Admission (PSA)

PodSecurityPolicy se **eliminó en 1.25**. Su reemplazo integrado es PSA, que aplica tres perfiles:

| Perfil | Para qué | Restringe |
|---|---|---|
| `privileged` | Componentes de sistema confiables | Nada |
| `baseline` | Default razonable; evita escaladas conocidas | hostNetwork/hostPID/hostIPC, privileged, hostPath, hostPorts, capabilities fuera de la lista por defecto, AppArmor/SELinux/seccomp inseguros, sysctls no seguros, `/proc` sin máscara |
| `restricted` | Endurecido, buenas prácticas | Lo anterior + `runAsNonRoot: true`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]` (solo se puede añadir `NET_BIND_SERVICE`), `seccompProfile` RuntimeDefault o Localhost, tipos de volumen limitados |

Modos por namespace (labels): `enforce` (rechaza), `audit` (anota en el log de auditoría), `warn` (avisa al cliente). Con versión opcional.

```yaml
metadata:
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/audit: restricted
```

Probar sin romper: `kubectl label --dry-run=server --overwrite ns app pod-security.kubernetes.io/enforce=restricted` (muestra qué pods violarían). Defaults a nivel cluster y exenciones: `AdmissionConfiguration` con `PodSecurity` en el apiserver. PSA evalúa los pods; los controladores (Deployment) solo reciben warnings, por eso un Deployment puede "aplicarse" bien y luego no crear pods (ver eventos del ReplicaSet).

## 7. securityContext

A nivel pod (`spec.securityContext`) y contenedor (`containers[].securityContext`, tiene precedencia):

```yaml
securityContext:              # pod
  runAsNonRoot: true
  runAsUser: 10001
  runAsGroup: 10001
  fsGroup: 10001
  fsGroupChangePolicy: OnRootMismatch
  seccompProfile:
    type: RuntimeDefault
containers:
- name: app
  securityContext:            # contenedor
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop: ["ALL"]
```

- **seccomp**: `RuntimeDefault` filtra syscalls peligrosas; `Localhost` con perfil propio en el nodo. El kubelet puede aplicar RuntimeDefault por defecto (`seccompDefault`).
- **AppArmor**: campo `securityContext.appArmorProfile` (las anotaciones viejas están deprecadas).
- **SELinux**: `seLinuxOptions`; `seLinuxChangePolicy` (`MountOption` vs `Recursive`).
- `readOnlyRootFilesystem` + `emptyDir` para `/tmp` y directorios de caché.
- `privileged: true` = acceso total al host; casi nunca justificado fuera de CNI/CSI.
- `procMount`, `sysctls` seguros vs no seguros, `supplementalGroupsPolicy`.
- **User namespaces** (`hostUsers: false`) aíslan aún más: root del contenedor no es root del host.

## 8. Admission control

- Controladores integrados importantes (activos por defecto en kubeadm): NamespaceLifecycle, LimitRanger, ServiceAccount, DefaultStorageClass, DefaultTolerationSeconds, ResourceQuota, PodSecurity, MutatingAdmissionWebhook, ValidatingAdmissionWebhook, ValidatingAdmissionPolicy, NodeRestriction, Priority, RuntimeClass, StorageObjectInUseProtection, TaintNodesByCondition.
- **Webhooks** (Mutating/ValidatingWebhookConfiguration): servicios HTTPS externos (Kyverno, OPA Gatekeeper, cert-manager, service meshes…). Buenas prácticas oficiales: `failurePolicy` pensado (Fail puede bloquear el cluster si el webhook cae), `timeoutSeconds` bajo, excluir `kube-system` con `namespaceSelector`, `matchConditions` en CEL para filtrar, idempotencia en mutaciones, alta disponibilidad del webhook.
- **ValidatingAdmissionPolicy** (GA): validaciones en CEL dentro del apiserver, sin webhook externo. Se compone de `ValidatingAdmissionPolicy` + `ValidatingAdmissionPolicyBinding` (con `validationActions: [Deny|Warn|Audit]`) y parámetros opcionales (`paramKind`).
- **MutatingAdmissionPolicy**: mutaciones declarativas en CEL (apply configuration o JSON Patch). Verifica su estado en tu versión.
- **Manifest-based admission control**: cargar políticas/webhooks desde archivos en disco del apiserver (Beta en 1.37).

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: require-resources
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups: ["apps"]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["deployments"]
  validations:
  - expression: >-
      object.spec.template.spec.containers.all(c,
        has(c.resources) && has(c.resources.requests) &&
        has(c.resources.requests.memory) && has(c.resources.requests.cpu))
    message: "Todos los contenedores deben declarar requests de CPU y memoria"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: require-resources-binding
spec:
  policyName: require-resources
  validationActions: [Deny]
  matchResources:
    namespaceSelector:
      matchLabels:
        policy.example.com/enforce: "true"
```

## 9. Cifrado, auditoría y hardening

**Cifrado en reposo** (`--encryption-provider-config` en el apiserver):
```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources: [secrets]
  providers:
  - kms:
      apiVersion: v2
      name: my-kms
      endpoint: unix:///var/run/kms/socket.sock
  - identity: {}          # permite leer datos aún no cifrados
```
Tras habilitarlo, reescribir los secrets existentes para cifrarlos: `kubectl get secrets -A -o json | kubectl replace -f -`. `aescbc`/`aesgcm`/`secretbox` locales son mejores que nada, pero la clave queda en el nodo; KMS v2 es lo recomendado.

**Auditoría**: `--audit-policy-file` + backend de log o webhook. Niveles: `None`, `Metadata`, `Request`, `RequestResponse`. Registra al menos `Metadata` para secrets (nunca `RequestResponse`, expondría su contenido).

**Checklist de seguridad (resumen de la oficial)**:
- Autenticación: sin tokens estáticos ni acceso anónimo innecesario; OIDC para humanos; `system:masters` solo break-glass.
- Red: NetworkPolicies default-deny; apiserver/etcd/kubelet no expuestos a internet; acceso a metadata del cloud bloqueado para pods.
- Pods: PSS `restricted` donde se pueda (al menos `baseline`); sin privileged ni hostPath; límites de recursos.
- Imágenes: registros confiables, escaneo de vulnerabilidades, firmas (Sigstore/cosign), digests, imágenes mínimas/distroless.
- Secrets: cifrado en reposo, RBAC estricto, montados como archivos.
- Nodos: kubelet con `--anonymous-auth=false` y autorización `Webhook`; NodeRestriction; SO mínimo y parcheado.
- etcd: TLS mutuo, acceso solo del apiserver, backups cifrados.
- Logs y auditoría habilitados; mantener el cluster en versiones soportadas; seguir el CVE feed oficial.
- Riesgos de "API Server Bypass": acceso directo a etcd, al kubelet (`/exec`, `/run`), a static pod manifests o al runtime equivale a cluster-admin.

## 10. Multi-tenancy

Combinar: un namespace por equipo/tenant + RBAC + ResourceQuota + LimitRange + NetworkPolicy default-deny + PSA. Para aislamiento fuerte (tenants no confiables): nodos dedicados (taints + afinidad), sandboxes (gVisor, Kata vía RuntimeClass), virtual control planes (vCluster) o clusters separados. Ver `assets/namespace-multitenant.yaml`.
