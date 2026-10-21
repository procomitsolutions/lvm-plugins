# Arquitectura, API, objetos y versiones

## Contenido
1. Componentes del cluster
2. Modelo de objetos (spec/status, metadata, labels, annotations, finalizers, owners)
3. La API: grupos, versiones, Server-Side Apply, CEL
4. Versiones, soporte y version skew
5. APIs eliminadas (tabla de migración)
6. Novedades relevantes de 1.35–1.37

---

## 1. Componentes del cluster

**Control plane**
- `kube-apiserver`: front-end de la API (REST). Es el único componente que habla con etcd. Escala horizontalmente.
- `etcd`: almacén clave-valor consistente con todo el estado del cluster. **Si pierdes etcd sin backup, pierdes el cluster.** Usa número impar de miembros (3 o 5).
- `kube-scheduler`: asigna Pods sin nodo a un nodo (filtrado → puntuación). Considera requests, afinidad, taints, topología, prioridad.
- `kube-controller-manager`: ejecuta los bucles de control (Deployment, ReplicaSet, Node, Job, EndpointSlice, ServiceAccount, Namespace, GC…).
- `cloud-controller-manager` (opcional): integra con el proveedor cloud (LoadBalancers, rutas, ciclo de vida de nodos).

**Nodo**
- `kubelet`: agente que garantiza que los contenedores de los Pods asignados estén corriendo; reporta estado del nodo; ejecuta probes.
- `kube-proxy` (opcional según CNI): implementa los Services en el nodo (modos iptables, ipvs o nftables). Algunos CNI (p. ej. Cilium) lo reemplazan.
- Container runtime compatible con CRI: containerd o CRI-O. **dockershim se eliminó en v1.24**; Docker Engine solo vía cri-dockerd.

**Addons habituales**: DNS del cluster (CoreDNS), CNI, metrics-server (necesario para `kubectl top` y HPA por CPU/memoria), Ingress controller / implementación de Gateway API, dashboard, logging/monitoring.

**Patrón de controlador**: cada controlador observa el estado deseado (`spec`) y lo reconcilia con el estado real (`status`) en un bucle. Por eso Kubernetes es "declarativo" y auto-sanable.

**Leases** (`coordination.k8s.io`): heartbeats de nodos (namespace `kube-node-lease`) y elección de líder de componentes.

## 2. Modelo de objetos

Todo objeto tiene `apiVersion`, `kind`, `metadata` y normalmente `spec` (deseado) y `status` (observado, lo escribe el sistema).

**Nombres e IDs**: `metadata.name` único por tipo y namespace; la mayoría exige nombre DNS-1123 (minúsculas, dígitos, `-`, `.`; ≤253 chars; labels de Service ≤63). `metadata.uid` es único en la vida del cluster.

**Namespaces**: aislamiento lógico de nombres, RBAC, cuotas y políticas. Iniciales: `default`, `kube-system`, `kube-public`, `kube-node-lease`. Objetos cluster-scoped (Node, PV, StorageClass, ClusterRole, Namespace, CRD…) no pertenecen a namespaces: ver con `kubectl api-resources --namespaced=false`. DNS de Service: `<svc>.<ns>.svc.cluster.local`.

**Labels y selectores**: pares clave/valor para identificar y agrupar. Selectores por igualdad (`app=web,tier!=db`) o por conjunto (`env in (prod,qa)`, `!canary`). Prefijos `kubernetes.io/` y `k8s.io/` están reservados.

**Labels recomendadas** (`app.kubernetes.io/*`): `name`, `instance`, `version`, `component`, `part-of`, `managed-by`.

**Annotations**: metadatos no identificadores (no sirven para seleccionar); los usan herramientas y controladores (p. ej. `kubectl.kubernetes.io/last-applied-configuration`, anotaciones de ingress controllers).

**Field selectors**: filtrar por campos (`kubectl get pods --field-selector status.phase=Running,spec.nodeName=node1`). Soporte limitado por tipo.

**Finalizers**: claves en `metadata.finalizers` que bloquean el borrado hasta que un controlador hace limpieza. Un objeto "atascado en Terminating" suele tener un finalizer cuyo controlador no existe o falla. Quitarlo a mano (`kubectl patch ... -p '{"metadata":{"finalizers":null}}' --type=merge`) es último recurso: puede dejar recursos huérfanos externos.

**Owners and dependents**: `metadata.ownerReferences` (p. ej. ReplicaSet → Pods). El garbage collector borra dependientes en cascada. `kubectl delete --cascade=background|foreground|orphan`.

**Gestión de objetos** (tres técnicas, no mezclarlas sobre el mismo objeto):
- Imperativa por comandos: `kubectl create deployment ...` (rápido, sin historial).
- Imperativa por archivos: `kubectl create/replace -f`.
- **Declarativa** (recomendada): `kubectl apply -f dir/` (+ `kubectl diff`). Con **Server-Side Apply** (`--server-side`) el API server rastrea qué "field manager" es dueño de cada campo y detecta conflictos.

## 3. La API

- Descubrimiento: `kubectl api-resources`, `kubectl api-versions`, `kubectl explain <recurso>.<campo> --recursive`.
- Rutas REST: `/api/v1` (grupo core) y `/apis/<grupo>/<versión>`. Ej.: `/apis/apps/v1/namespaces/default/deployments`.
- Niveles: **alpha** (desactivado por defecto, puede romper/desaparecer), **beta** (APIs beta nuevas no se habilitan por defecto desde 1.24; features beta sí suelen estarlo), **GA/stable** (`v1`, compatibilidad garantizada).
- Concurrencia optimista con `metadata.resourceVersion`; `watch` para streams de cambios; listas paginadas (`limit`/`continue`).
- `dryRun=All` (server-side dry run) valida contra admission sin persistir.
- **CEL (Common Expression Language)** se usa en: reglas de validación de CRDs (`x-kubernetes-validations`), ValidatingAdmissionPolicy, MutatingAdmissionPolicy, matchConditions de webhooks, selectores de DRA y autorización estructurada.
- Health endpoints del API server: `/livez`, `/readyz` (`?verbose` muestra cada check). `/healthz` está deprecado.
- **API Priority and Fairness** (`flowcontrol.apiserver.k8s.io/v1`): FlowSchema + PriorityLevelConfiguration limitan la concurrencia por tipo de cliente para evitar que uno sature el API server.
- Client libraries oficiales: Go (client-go), Python, Java, JavaScript, C#, Haskell; hay muchas comunitarias.
- **KYAML**: subconjunto de YAML más seguro (sin ambigüedades tipo "Norway problem"), salida con `kubectl get -o kyaml`. Stable en 1.37.

## 4. Versiones, soporte y version skew

- Formato `x.y.z` (semver). Se mantienen las **3 últimas minors**; cada una recibe ~**1 año** de parches (desde 1.19).
- A 6-10-2026: 1.37 (EOL 2027-10-28), 1.36 (EOL 2027-06-28), 1.35 (EOL 2027-02-28), 1.34 (EOL 2026-10-27). 1.33 y anteriores: sin soporte.
- **Version skew policy** (resumen; verifica la página oficial):
  - kube-apiserver en HA: instancias con diferencia de como mucho 1 minor.
  - kubelet / kube-proxy: hasta **3 minors por debajo** del apiserver; nunca más nuevos que él.
  - kube-controller-manager, kube-scheduler, cloud-controller-manager: no más nuevos que el apiserver; hasta 1 minor más viejos.
  - kubectl: ±1 minor respecto del apiserver.
- **Upgrade**: siempre de a una minor (1.35 → 1.36 → 1.37), control plane primero, luego nodos. Revisa notas de la release y APIs eliminadas antes.
- **Compatibility version** (`--emulated-version`): permite a componentes del control plane emular la minor anterior para hacer upgrades más seguros (ver "Compatibility Version For Kubernetes Control Plane Components").

## 5. APIs eliminadas (tabla de migración)

Cuando un manifiesto falla con `no matches for kind "X" in version "Y"`, casi siempre es esto.

| Eliminada en | Recurso | apiVersion vieja | Usar |
|---|---|---|---|
| 1.32 | FlowSchema, PriorityLevelConfiguration | flowcontrol.apiserver.k8s.io/v1beta3 | flowcontrol.apiserver.k8s.io/v1 |
| 1.29 | FlowSchema, PriorityLevelConfiguration | flowcontrol.apiserver.k8s.io/v1beta2 | flowcontrol.apiserver.k8s.io/v1 |
| 1.27 | CSIStorageCapacity | storage.k8s.io/v1beta1 | storage.k8s.io/v1 |
| 1.26 | HorizontalPodAutoscaler | autoscaling/v2beta2 | autoscaling/v2 |
| 1.25 | CronJob | batch/v1beta1 | batch/v1 |
| 1.25 | EndpointSlice | discovery.k8s.io/v1beta1 | discovery.k8s.io/v1 |
| 1.25 | Event | events.k8s.io/v1beta1 | events.k8s.io/v1 |
| 1.25 | HorizontalPodAutoscaler | autoscaling/v2beta1 | autoscaling/v2 |
| 1.25 | PodDisruptionBudget | policy/v1beta1 | policy/v1 |
| 1.25 | PodSecurityPolicy | policy/v1beta1 | **Eliminada sin reemplazo directo** → Pod Security Admission o políticas (Kyverno, Gatekeeper, ValidatingAdmissionPolicy) |
| 1.25 | RuntimeClass | node.k8s.io/v1beta1 | node.k8s.io/v1 |
| 1.22 | Mutating/ValidatingWebhookConfiguration | admissionregistration.k8s.io/v1beta1 | admissionregistration.k8s.io/v1 |
| 1.22 | CustomResourceDefinition | apiextensions.k8s.io/v1beta1 | apiextensions.k8s.io/v1 |
| 1.22 | APIService | apiregistration.k8s.io/v1beta1 | apiregistration.k8s.io/v1 |
| 1.22 | Ingress / IngressClass | extensions/v1beta1, networking.k8s.io/v1beta1 | networking.k8s.io/v1 |
| 1.22 | CertificateSigningRequest | certificates.k8s.io/v1beta1 | certificates.k8s.io/v1 |
| 1.22 | Lease | coordination.k8s.io/v1beta1 | coordination.k8s.io/v1 |
| 1.22 | TokenReview, SubjectAccessReview & co. | authentication/authorization .k8s.io/v1beta1 | …/v1 |
| 1.22 | RBAC (Role, ClusterRole, bindings) | rbac.authorization.k8s.io/v1beta1 | rbac.authorization.k8s.io/v1 |
| 1.16 | Deployment, DaemonSet, ReplicaSet, StatefulSet | extensions/v1beta1, apps/v1beta1, apps/v1beta2 | apps/v1 |
| 1.16 | NetworkPolicy | extensions/v1beta1 | networking.k8s.io/v1 |

**Cambios de campos notables al migrar**:
- `autoscaling/v2`: `targetAverageUtilization` → `target: {type: Utilization, averageUtilization: N}`.
- `policy/v1` PDB: `spec.selector: {}` selecciona **todos** los pods del namespace (en v1beta1 no seleccionaba ninguno).
- `networking.k8s.io/v1` Ingress: `backend.serviceName/servicePort` → `backend.service.name` / `backend.service.port.number|name`; `pathType` obligatorio; `spec.ingressClassName` reemplaza la anotación `kubernetes.io/ingress.class`.
- `apiextensions.k8s.io/v1` CRD: `spec.versions[*].schema.openAPIV3Schema` obligatorio y estructural; `scope` explícito; `x-kubernetes-preserve-unknown-fields` dentro del schema.
- `admissionregistration.k8s.io/v1` webhooks: `failurePolicy` por defecto `Fail`, `timeoutSeconds` por defecto 10, `sideEffects` y `admissionReviewVersions` obligatorios.
- `apps/v1`: `spec.selector` obligatorio e inmutable.

**Cómo encontrar usos de APIs deprecadas**: métrica `apiserver_requested_deprecated_apis` del API server, warnings que muestra kubectl, anotaciones de audit `k8s.io/deprecated`, y herramientas como `kubent` (kube-no-trouble) o `pluto`. Para convertir manifiestos: plugin `kubectl convert`. Probar con APIs deprecadas deshabilitadas: `--runtime-config=<grupo>/<versión>=false` en el apiserver.

## 6. Novedades relevantes de 1.35–1.37 (verificar estado exacto en feature-gates)

Kubernetes v1.37 "Garhwal" (26-08-2026): 67 mejoras (16 a Stable, 23 a Beta, 27 Alpha). Destacados:
- Inicialización resiliente del watch cache del apiserver: completada (protege etcd al arrancar/recuperar).
- **HPA scale-to-zero**: Beta (no aplica a métricas de CPU/memoria; requiere métricas externas/objeto).
- **Manifest-based admission control**: políticas y webhooks cargados desde disco (útil para políticas que deben existir antes de que el apiserver acepte requests).
- Checkpoint/restore a nivel de Pod: Alpha (nuevas RPC en CRI).
- **KYAML**: Stable.
- **`metrics.k8s.io`**: Stable (tras ~9 años en beta).
- **SELinuxMount / SELinuxChangePolicy**: Stable y habilitados por defecto → los volúmenes se montan con la etiqueta SELinux correcta en vez de reetiquetar recursivamente; puede afectar pods que comparten volúmenes con distintos contextos SELinux (revisar `spec.securityContext.seLinuxChangePolicy`).
- DRA: `ResourceClaim.status.devices`, extended resources vía DRA, device taints/tolerations y atributo estándar `resource.kubernetes.io/numaNode` a Stable.
- Node declared features: Stable.

Otras features maduras en versiones recientes que conviene conocer (comprueba estado en tu versión): sidecar containers nativos (`initContainers` con `restartPolicy: Always`), redimensionado in-place de CPU/memoria de pods (`kubectl patch --subresource resize`), user namespaces en pods (`hostUsers: false`), image volumes, recursos a nivel de Pod (`spec.resources`), Gateway API, VolumeAttributesClass, ServiceCIDR/IPAddress para ampliar rangos de Service, Mutating/ValidatingAdmissionPolicy con CEL, Workload API / PodGroup / gang scheduling para cargas de IA/batch, `kuberc` (preferencias de usuario de kubectl).
