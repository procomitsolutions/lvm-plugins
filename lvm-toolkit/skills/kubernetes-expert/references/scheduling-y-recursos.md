# Scheduling, recursos, preemption y evicción

## Contenido
1. Requests, limits y unidades
2. Clases de QoS
3. LimitRange y ResourceQuota
4. Asignar pods a nodos (nodeSelector, afinidad, antiafinidad)
5. Taints y tolerations
6. Topology spread constraints
7. Prioridad y preemption
8. Evicción por presión del nodo y por API
9. Recursos del nodo (reservas, managers de CPU/memoria/topología)
10. GPUs, device plugins y DRA
11. Gang scheduling y Workload API

---

## 1. Requests y limits

- **requests**: lo que el scheduler reserva; garantiza ese mínimo.
- **limits**: tope. CPU excedida → **throttling** (no mata). Memoria excedida → **OOMKilled** (exit 137).
- Unidades: CPU en cores (`500m` = 0,5 core); memoria en bytes con sufijos binarios (`Mi`, `Gi`) o decimales (`M`, `G`). Ojo: `500m` de memoria significa 0,5 bytes — error común.
- Si se define limit sin request, el request toma el valor del limit.
- **Recursos a nivel de Pod** (`spec.resources`): presupuesto compartido para todos los contenedores del pod (revisa el estado de la feature en tu versión).
- **Resize in-place**: cambiar requests/limits sin recrear el pod (subrecurso `resize`; `resizePolicy` define si reinicia).
- Recomendación práctica: requests ≈ uso típico (p50–p90 observado); limit de memoria ≥ pico; limit de CPU opcional (muchos equipos no lo ponen para evitar throttling, pero entonces requests de CPU bien dimensionados son imprescindibles).

## 2. QoS

| Clase | Condición | Evicción |
|---|---|---|
| Guaranteed | Todos los contenedores con requests = limits en CPU y memoria | Última |
| Burstable | Al menos un request o limit, sin cumplir Guaranteed | Intermedia |
| BestEffort | Sin requests ni limits | Primera |

Ver: `kubectl get pod x -o jsonpath='{.status.qosClass}'`. Guaranteed con CPU entera es requisito para CPUs exclusivas con la política `static` del CPU manager.

## 3. LimitRange y ResourceQuota

**LimitRange** (por namespace): defaults (`default`, `defaultRequest`), mínimos/máximos por contenedor/pod/PVC y ratio limit/request. Se aplica en admisión (no a pods existentes).

**ResourceQuota** (por namespace): topes agregados de `requests.cpu`, `requests.memory`, `limits.*`, `requests.storage`, `persistentvolumeclaims`, `<sc>.storageclass.storage.k8s.io/requests.storage`, conteo de objetos (`count/deployments.apps`, `pods`, `services.loadbalancers`…), por `scopeSelector` (PriorityClass, BestEffort, Terminating…).
- **Trampa**: si hay quota de CPU/memoria, todo pod nuevo **debe** declarar esos requests/limits o será rechazado → combinar siempre con LimitRange que ponga defaults.
- Ver consumo: `kubectl describe quota -n app`.
- El error de cuota aparece en los eventos del **ReplicaSet**, no del Deployment: `kubectl describe rs -n app`.

## 4. Asignar pods a nodos

- `nodeSelector`: igualdad simple de labels (`disktype: ssd`).
- `nodeName`: salta el scheduler (evitar).
- **Node affinity**: `requiredDuringSchedulingIgnoredDuringExecution` (duro) y `preferredDuringSchedulingIgnoredDuringExecution` (blando, con `weight`). Operadores `In`, `NotIn`, `Exists`, `DoesNotExist`, `Gt`, `Lt`.
- **Pod affinity / antiaffinity**: co-ubicar o separar pods según labels de otros pods, por `topologyKey` (`kubernetes.io/hostname`, `topology.kubernetes.io/zone`). La antiafinidad dura por hostname limita réplicas a número de nodos; en clusters grandes es costosa: prefiere topology spread.
- Labels bien conocidas: `kubernetes.io/hostname`, `kubernetes.io/os`, `kubernetes.io/arch`, `topology.kubernetes.io/zone`, `topology.kubernetes.io/region`, `node.kubernetes.io/instance-type`.
- **Scheduling gates** (`spec.schedulingGates`): mantener el pod sin programar hasta que un controlador quite la puerta.
- **Pod overhead** (RuntimeClass): recursos extra de sandboxes como Kata.

## 5. Taints y tolerations

- Taint en el nodo: `kubectl taint nodes n1 dedicated=gpu:NoSchedule`. Quitar: mismo comando con `-` al final.
- Efectos: `NoSchedule`, `PreferNoSchedule`, `NoExecute` (además desaloja pods sin toleration; `tolerationSeconds` da margen).
- Toleration en el pod: `{key: dedicated, operator: Equal, value: gpu, effect: NoSchedule}`; `operator: Exists` tolera cualquier valor.
- Una toleration **permite** pero no **obliga**: para dedicar nodos combina taint + node affinity.
- Taints automáticos por condición: `node.kubernetes.io/not-ready`, `unreachable` (NoExecute, los pods tienen tolerations de 300 s por defecto → tardan ~5 min en reprogramarse si un nodo muere), `memory-pressure`, `disk-pressure`, `pid-pressure`, `unschedulable` (cordon), `network-unavailable`. Control plane de kubeadm: `node-role.kubernetes.io/control-plane:NoSchedule`.

## 6. Topology spread constraints

```yaml
topologySpreadConstraints:
- maxSkew: 1
  topologyKey: topology.kubernetes.io/zone
  whenUnsatisfiable: ScheduleAnyway      # o DoNotSchedule
  labelSelector:
    matchLabels: {app.kubernetes.io/name: web}
  matchLabelKeys: ["pod-template-hash"]  # distribuye por revisión durante rollouts
- maxSkew: 1
  topologyKey: kubernetes.io/hostname
  whenUnsatisfiable: ScheduleAnyway
  labelSelector:
    matchLabels: {app.kubernetes.io/name: web}
```
- `minDomains`, `nodeAffinityPolicy`, `nodeTaintsPolicy` afinan qué nodos cuentan.
- Solo actúa al programar; no rebalancea pods existentes (para eso, descheduler).

## 7. Prioridad y preemption

- `PriorityClass` (cluster-scoped) con `value`; `globalDefault` opcional; `preemptionPolicy: Never` para prioridad sin desalojar a otros.
- El scheduler puede **desalojar** pods de menor prioridad para hacer lugar (respeta PDB "en lo posible", no garantizado).
- Reservadas: `system-cluster-critical` y `system-node-critical` para addons críticos.
- Patrón de sobreaprovisionamiento: pods "placeholder" con prioridad negativa que reservan capacidad y se desalojan cuando llega carga real (ver "Overprovision Node Capacity").

## 8. Evicción

**Por presión del nodo** (kubelet): señales `memory.available`, `nodefs.available`, `nodefs.inodesFree`, `imagefs.available`, `pid.available`. Umbrales duros (`evictionHard`, p. ej. `memory.available<100Mi`) y blandos (`evictionSoft` + gracia). Orden: pods que exceden sus requests, por prioridad y por consumo relativo. Antes de desalojar el kubelet intenta reclamar (GC de imágenes y contenedores muertos). Pod desalojado: `status.reason: Evicted` (queda listado; limpiar con `kubectl delete pod --field-selector=status.phase=Failed`).

**OOM del kernel** vs evicción: el OOM killer actúa si la memoria se agota antes de que el kubelet desaloje; `oom_score_adj` depende de la clase QoS.

**Por API** (`Eviction`): lo que usa `kubectl drain`; respeta PDBs (responde 429 si no se puede).

**Node shutdown**: graceful node shutdown (`shutdownGracePeriod`, `shutdownGracePeriodCriticalPods`) y non-graceful (taint `node.kubernetes.io/out-of-service` para liberar volúmenes y reprogramar StatefulSets cuando el nodo murió sin aviso).

## 9. Recursos del nodo

- `Allocatable = Capacity − kube-reserved − system-reserved − eviction-threshold`. Configura reservas en la KubeletConfiguration para que el sistema operativo no se quede sin memoria.
- **CPU Manager** (`static`): CPUs exclusivas para pods Guaranteed con CPU entera. **Memory Manager** y **Topology Manager** (políticas `best-effort`, `restricted`, `single-numa-node`) para cargas sensibles a NUMA.
- **cgroup v2** es lo recomendado (cgroup v1 en modo mantenimiento/deprecado). El kubelet y el runtime deben usar el mismo driver de cgroups (`systemd` recomendado).
- **Swap**: soportado en nodos Linux con `LimitedSwap` (solo pods Burstable); configurar con cuidado.
- **PID limits**: `podPidsLimit` contra fork bombs.
- **HugePages**: `hugepages-2Mi`/`hugepages-1Gi` como recursos; requests = limits.

## 10. GPUs, device plugins y DRA

- **Device plugins**: el vendor (NVIDIA, AMD, Intel) publica recursos extendidos (`nvidia.com/gpu: 1` en `limits`). Simple, pero solo cuenta dispositivos enteros.
- **Dynamic Resource Allocation (DRA)** (`resource.k8s.io/v1`, GA): modelo flexible tipo PVC para dispositivos.
  - `DeviceClass` (admin): categoría de dispositivo + selectores CEL.
  - `ResourceSlice` (driver): inventario publicado por nodo.
  - `ResourceClaim` / `ResourceClaimTemplate` (usuario): qué necesita (cantidad, atributos, capacidad compartida, alternativas priorizadas).
  - El pod referencia el claim en `spec.resourceClaims` y cada contenedor en `resources.claims`.
  - En 1.37 son Stable: `ResourceClaim.status.devices`, solicitudes de extended resources servidas por DRA, device taints/tolerations y el atributo estándar `resource.kubernetes.io/numaNode`.
  - Ver "Hardening Guide - Dynamic Resource Allocation" y "Good practices for DRA as a Cluster Admin".

## 11. Gang scheduling y Workload API

Para entrenamiento distribuido o HPC, todos los pods de un grupo deben arrancar juntos o ninguno. Kubernetes incorporó la **Workload API** (`scheduling.k8s.io`: `Workload`, `PodGroup`, `CompositePodGroup`) con políticas de gang scheduling, preemption a nivel de grupo y scheduling consciente de topología. Son APIs recientes (alpha/beta): verifica su estado. Alternativas maduras del ecosistema: Kueue (colas y cuotas), JobSet, Volcano.
