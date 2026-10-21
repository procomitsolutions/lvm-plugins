# Extender Kubernetes y empaquetar aplicaciones

## Contenido
1. Puntos de extensión (mapa)
2. CustomResourceDefinitions
3. Patrón operador
4. Aggregation layer
5. Kustomize
6. Helm
7. Acceso programático (client libraries, desde un pod)

---

## 1. Mapa de puntos de extensión

| Quiero… | Usar |
|---|---|
| Un nuevo tipo de objeto | CRD (+ controlador) |
| Automatizar operación de una app con estado | Operador (CRD + controlador) |
| Una API con almacenamiento/lógica propia | Aggregation layer (APIService) |
| Validar/mutar objetos al crearlos | ValidatingAdmissionPolicy/MutatingAdmissionPolicy (CEL) o webhooks |
| Autenticación/autorización externa | Webhook token / OIDC / authorization webhook |
| Red, almacenamiento, dispositivos | CNI, CSI, device plugins, drivers DRA |
| Cambiar cómo se programa | Scheduler framework (plugins), perfiles, múltiples schedulers |
| Nuevos comandos de kubectl | Plugins de kubectl |
| Runtimes alternativos | CRI + RuntimeClass |

## 2. CRDs (`apiextensions.k8s.io/v1`)

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: backups.ops.example.com          # <plural>.<grupo>
spec:
  group: ops.example.com
  scope: Namespaced
  names:
    plural: backups
    singular: backup
    kind: Backup
    shortNames: [bk]
  versions:
  - name: v1
    served: true
    storage: true
    subresources:
      status: {}
    additionalPrinterColumns:
    - name: Schedule
      type: string
      jsonPath: .spec.schedule
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            required: [schedule]
            properties:
              schedule: {type: string}
              retentionDays: {type: integer, minimum: 1, default: 7}
            x-kubernetes-validations:
            - rule: "self.retentionDays <= 365"
              message: "retentionDays no puede superar 365"
          status:
            type: object
            x-kubernetes-preserve-unknown-fields: true
```
- Schema **estructural** obligatorio; `default`, validación OpenAPI y **reglas CEL** (`x-kubernetes-validations`, incluso reglas de transición con `oldSelf`).
- Subrecursos `status` y `scale`.
- **Versionado**: varias versiones `served`, una sola `storage`; conversión `None` o por webhook. Para cambiar la versión de almacenamiento, migrar objetos (StorageVersionMigration) y luego quitar la vieja de `status.storedVersions`.
- Selectable fields para filtrar con `--field-selector`.
- Borrar una CRD borra **todos** sus objetos.

## 3. Operadores

Controlador que reconcilia CRs y codifica conocimiento operativo (backups, upgrades, failover). Principios: reconciliación idempotente basada en nivel (no en eventos), `status` con `conditions` y `observedGeneration`, finalizers para limpieza externa, ownerReferences para GC, leader election, permisos RBAC mínimos.
Frameworks: Kubebuilder y controller-runtime (Go), Operator SDK, Metacontroller, kopf (Python), Java Operator SDK. Muchos operadores listos en OperatorHub/Artifact Hub (bases de datos, Kafka, Prometheus, cert-manager…).

## 4. Aggregation layer

El apiserver delega rutas `/apis/<grupo>/<versión>` a un servicio extensión registrado con un `APIService` (así funciona metrics-server con `metrics.k8s.io`). Requiere configurar front-proxy (`--requestheader-*`, kubeadm lo hace). Un APIService con `Available=False` puede romper el descubrimiento y bloquear el borrado de namespaces.

## 5. Kustomize (integrado en kubectl)

```
base/
  kustomization.yaml
  deployment.yaml
  service.yaml
overlays/prod/
  kustomization.yaml
  patch-replicas.yaml
```
```yaml
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources: [deployment.yaml, service.yaml]
labels:
- pairs: {app.kubernetes.io/name: web}
  includeSelectors: true
configMapGenerator:
- name: web-config
  literals: [LOG_LEVEL=info]
---
# overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: prod
resources: [../../base]
images:
- name: registry.example.com/web
  newTag: "1.5.0"
patches:
- path: patch-replicas.yaml
- target: {kind: Deployment, name: web}
  patch: |-
    - op: replace
      path: /spec/template/spec/containers/0/resources/limits/memory
      value: 512Mi
```
- `kubectl apply -k overlays/prod` / `kubectl kustomize overlays/prod`.
- Generators agregan sufijo hash al nombre → cambio de config = rollout automático.
- `secretGenerator` existe, pero no metas secretos reales en el repo.
- `commonLabels` está deprecado: usa `labels` (cuidado: incluir en selectores cambia selectores inmutables).
- La versión de Kustomize embebida en kubectl puede ir detrás del binario independiente.

## 6. Helm (proyecto CNCF, no parte de la doc de Kubernetes)

- Chart = plantillas Go + `values.yaml`; release = instancia instalada con historial.
- `helm repo add`, `helm search repo`, `helm show values`, `helm install <rel> <chart> -n <ns> --create-namespace -f values.yaml`, `helm upgrade --install`, `helm rollback`, `helm uninstall`, `helm template` (renderizar), `helm diff` (plugin), `helm lint`.
- Charts OCI: `helm install x oci://registry.example.com/charts/x --version 1.2.3`.
- Fija versiones del chart; revisa los valores por defecto (a menudo no traen requests ni securityContext estrictos).
- Helm vs Kustomize: Helm para distribuir software parametrizable a terceros; Kustomize para variaciones por entorno de manifiestos propios. Se combinan (renderizar con Helm y post-procesar con Kustomize).
- GitOps: Argo CD o Flux aplican Helm/Kustomize desde Git de forma continua.

## 7. Acceso programático

- Desde un pod: usa el ServiceAccount montado; client libraries detectan la configuración "in-cluster" automáticamente. A mano:
```bash
SA=/var/run/secrets/kubernetes.io/serviceaccount
curl --cacert $SA/ca.crt -H "Authorization: Bearer $(cat $SA/token)" \
  https://kubernetes.default.svc/api/v1/namespaces/$(cat $SA/namespace)/pods
```
- Fuera del cluster: `kubectl proxy` o client libraries con kubeconfig.
- Client libraries oficiales: Go (`k8s.io/client-go`, y controller-runtime para controladores), Python (`kubernetes`), Java, JavaScript/TypeScript, C#/dotnet, Haskell.
- Patrones correctos: informers/watch en vez de polling; Server-Side Apply con un `fieldManager` propio; respetar `resourceVersion` para evitar sobrescrituras; backoff ante 429 (APF).
