# Workloads

## Contenido
1. Pods: ciclo de vida, fases, condiciones, terminación
2. Probes (liveness, readiness, startup)
3. Init, sidecar y ephemeral containers; lifecycle hooks
4. Elegir el controlador correcto
5. Deployment (rolling update, rollback, estrategias)
6. StatefulSet
7. DaemonSet
8. Job y CronJob
9. Autoscaling (HPA, VPA, nodos)
10. Disrupciones y PodDisruptionBudget
11. Downward API, static pods, QoS, otros

---

## 1. Pods

Unidad mínima desplegable: uno o más contenedores que comparten red (misma IP, `localhost`), volúmenes y (opcionalmente) namespace de procesos. Los Pods son efímeros: no se "mueven", se reemplazan.

**Fases (`status.phase`)**: `Pending` (aceptado, sin programar o descargando imágenes), `Running`, `Succeeded`, `Failed`, `Unknown` (se perdió contacto con el nodo).

**Estados de contenedor**: `Waiting` (con `reason`: ContainerCreating, CrashLoopBackOff, ImagePullBackOff, ErrImagePull, CreateContainerConfigError…), `Running`, `Terminated` (`reason`, `exitCode`).

**Condiciones del Pod**: `PodScheduled`, `PodReadyToStartContainers`, `Initialized`, `ContainersReady`, `Ready`, y `DisruptionTarget` cuando va a ser desalojado.

**restartPolicy**: `Always` (por defecto; único válido en Deployments), `OnFailure`, `Never` (Jobs). Los reinicios usan backoff exponencial hasta 5 min → `CrashLoopBackOff`.

**Terminación ordenada**:
1. El Pod pasa a Terminating; se quita de los endpoints de los Services (en paralelo, no garantizado antes del SIGTERM).
2. Se ejecuta el hook `preStop` (si existe).
3. Se envía SIGTERM al PID 1 de cada contenedor.
4. Tras `terminationGracePeriodSeconds` (30 s por defecto) → SIGKILL.
Consejo práctico: un `preStop` con `sleep` corto (p. ej. 5-10 s) evita errores 5xx durante rollouts porque da tiempo a que los endpoints se actualicen. Desde versiones recientes existe la acción `preStop: sleep: {seconds: N}` que no requiere binario `sleep` en la imagen.

## 2. Probes

| Probe | Pregunta | Si falla |
|---|---|---|
| `startupProbe` | ¿Terminó de arrancar? | Reinicia; mientras no pase, las otras probes no corren |
| `livenessProbe` | ¿Está viva o colgada? | Reinicia el contenedor |
| `readinessProbe` | ¿Puede recibir tráfico ahora? | Se saca de los endpoints (no reinicia) |

Mecanismos: `httpGet`, `tcpSocket`, `exec`, `grpc`. Parámetros: `initialDelaySeconds`, `periodSeconds` (10), `timeoutSeconds` (1), `failureThreshold` (3), `successThreshold` (1; debe ser 1 en liveness/startup), `terminationGracePeriodSeconds` a nivel de probe.

Buenas prácticas:
- Liveness **barata y local**; nunca dependas de BD u otros servicios en liveness (un fallo externo reinicia toda la flota).
- Readiness sí puede considerar dependencias críticas.
- Arranques lentos: `startupProbe` con `failureThreshold * periodSeconds` ≥ tiempo máximo de arranque.
- Timeouts de 1 s son agresivos para JVM/apps cargadas; súbelos si hay reinicios espurios.

## 3. Init, sidecar y ephemeral containers

**Init containers** (`spec.initContainers`): corren en orden, cada uno hasta completar, antes de los contenedores de la app. Uso: migraciones, esperar dependencias, preparar archivos. Si fallan, el Pod se reinicia según `restartPolicy`.

**Sidecar containers nativos**: un init container con `restartPolicy: Always`. Arranca antes que la app, sigue corriendo junto a ella, no bloquea la finalización de Jobs y se detiene después de los contenedores principales. Reemplaza el patrón viejo de sidecar como contenedor normal (que causaba Jobs que nunca terminaban y orden de arranque/parada indefinido). Admite probes.

```yaml
spec:
  initContainers:
  - name: log-shipper
    image: fluent/fluent-bit:3.1
    restartPolicy: Always
  containers:
  - name: app
    image: registry.example.com/app:1.4.2
```

**Ephemeral containers**: se agregan a un Pod en ejecución para depurar (`kubectl debug -it pod/x --image=busybox:1.36 --target=app`). No tienen puertos, probes ni recursos garantizados; no se pueden quitar.

**Lifecycle hooks**: `postStart` (sin garantía de ejecutarse antes del ENTRYPOINT) y `preStop` (síncrono, antes de SIGTERM). Handlers: `exec`, `httpGet`, `sleep`.

## 4. Elegir el controlador

| Necesidad | Usar |
|---|---|
| App sin estado, réplicas intercambiables | Deployment |
| Identidad de red estable, almacenamiento por réplica, orden (BD, Kafka, ZooKeeper) | StatefulSet |
| Un pod por nodo (agentes de logs, monitoreo, CNI, CSI) | DaemonSet |
| Tarea que termina | Job |
| Tarea periódica | CronJob |
| Grupo de pods que deben programarse juntos (IA/HPC) | Job + Workload/PodGroup (gang scheduling) o Kueue/JobSet |

ReplicationController es legado: usa Deployment. ReplicaSet directo casi nunca (lo gestiona el Deployment).

## 5. Deployment

- Gestiona ReplicaSets; cada cambio en `spec.template` crea un nuevo ReplicaSet (revisión).
- **Estrategias**: `RollingUpdate` (por defecto; `maxSurge` 25 %, `maxUnavailable` 25 %) o `Recreate` (baja todo y levanta; necesario si dos versiones no pueden coexistir, p. ej. volumen RWO).
- Para cero downtime: readinessProbe correcta + `maxUnavailable: 0` + `maxSurge: 1` (o 25 %) + preStop sleep + PDB.
- `minReadySeconds`: tiempo que un pod debe estar Ready para contarse disponible.
- `progressDeadlineSeconds` (600): si no progresa, condición `Progressing=False` con reason `ProgressDeadlineExceeded` (el rollout no se revierte solo).
- `revisionHistoryLimit` (10): ReplicaSets viejos conservados para rollback.

Comandos:
```bash
kubectl set image deploy/web app=registry.example.com/web:1.5.0
kubectl rollout status deploy/web --timeout=5m
kubectl rollout history deploy/web
kubectl rollout undo deploy/web [--to-revision=3]
kubectl rollout pause|resume deploy/web
kubectl rollout restart deploy/web        # recrea pods (p. ej. tras cambiar un ConfigMap)
kubectl scale deploy/web --replicas=5
kubectl annotate deploy/web kubernetes.io/change-cause="v1.5.0: fix login"
```

**Canary / blue-green nativos**: dos Deployments (stable y canary) con una label común que selecciona el Service; la proporción de réplicas aproxima el % de tráfico. Para control fino (pesos, headers) usa Gateway API (`HTTPRoute` con `weight`), un service mesh o Argo Rollouts / Flagger.

## 6. StatefulSet

- Pods con nombre ordinal estable (`web-0`, `web-1`…), DNS estable vía **headless Service** (`clusterIP: None`, obligatorio en `spec.serviceName`): `web-0.web.<ns>.svc.cluster.local`.
- `volumeClaimTemplates`: un PVC por réplica (`data-web-0`), que **persiste** al borrar o escalar hacia abajo (salvo `persistentVolumeClaimRetentionPolicy: {whenDeleted: Delete, whenScaled: Delete}`).
- `podManagementPolicy`: `OrderedReady` (por defecto, uno a uno) o `Parallel`.
- `updateStrategy`: `RollingUpdate` (de mayor a menor ordinal; `partition` para canary por ordinal; `maxUnavailable` disponible) u `OnDelete`.
- `ordinals.start` para empezar la numeración en otro número.
- **Cuidados**: escalar a 0 antes de borrar para un apagado ordenado; nunca forzar el borrado de un pod de StatefulSet si el nodo puede seguir vivo (dos pods con la misma identidad = corrupción). Un rollout puede quedar atascado si un pod nunca llega a Ready: hay que arreglarlo y borrar el pod roto a mano.

## 7. DaemonSet

- Un pod por nodo que cumpla `nodeSelector`/afinidad/tolerations. Para correr en control plane, tolera `node-role.kubernetes.io/control-plane:NoSchedule`.
- `updateStrategy`: `RollingUpdate` (`maxUnavailable`, `maxSurge`) u `OnDelete`. Rollback con `kubectl rollout undo ds/x`.
- Los pods de DaemonSet reciben tolerations automáticas (not-ready, unreachable, disk/memory/pid-pressure, unschedulable…).

## 8. Job y CronJob

**Job**:
- `completions`, `parallelism`, `completionMode: Indexed` (cada pod recibe `JOB_COMPLETION_INDEX`).
- `backoffLimit` (6 por defecto), `backoffLimitPerIndex` + `maxFailedIndexes` (Indexed), `activeDeadlineSeconds` (límite total).
- `podFailurePolicy`: reglas por exit code o condición del pod para fallar rápido (`FailJob`), ignorar (`Ignore`, p. ej. disrupciones) o contar (`Count`). Requiere `restartPolicy: Never`.
- `successPolicy` para declarar éxito con un subconjunto de índices.
- `ttlSecondsAfterFinished` para limpieza automática.
- `suspend: true` para pausar; base de colas como Kueue.
- `restartPolicy` debe ser `Never` u `OnFailure`.

**CronJob** (`batch/v1`):
- `schedule` en formato cron, `timeZone: "America/Argentina/Buenos_Aires"` (si no, usa la zona del kube-controller-manager).
- `concurrencyPolicy`: `Allow` (por defecto), `Forbid`, `Replace`.
- `startingDeadlineSeconds`: si se perdieron >100 programaciones sin este campo, el CronJob deja de programar.
- `successfulJobsHistoryLimit` (3), `failedJobsHistoryLimit` (1).
- Disparar manualmente: `kubectl create job --from=cronjob/backup backup-manual-1`.
- Los jobs deben ser **idempotentes**: el controlador puede crear 0 o 2 jobs en casos límite.

## 9. Autoscaling

**HPA** (`autoscaling/v2`):
- Escala `replicas` según métricas: `Resource` (CPU/memoria, requiere metrics-server y **requests definidos**), `Pods`, `Object`, `External` (vía adapters como Prometheus Adapter o KEDA), `ContainerResource`.
- Fórmula: `deseadas = ceil(actuales * valorActual / valorObjetivo)`.
- `behavior.scaleUp/scaleDown` con `stabilizationWindowSeconds` (scale down 300 s por defecto) y `policies` para evitar flapping.
- No combines HPA por CPU/memoria con VPA en modo Auto sobre el mismo recurso.
- No pongas `replicas` en el manifiesto del Deployment si un HPA lo gestiona (cada `apply` lo pisaría); o usa Server-Side Apply para no reclamar el campo.
- Scale-to-zero (minReplicas: 0) es Beta en 1.37 y solo para métricas Object/External. Para event-driven: KEDA.

```bash
kubectl autoscale deploy web --cpu=70% --min=2 --max=10   # en versiones recientes; antes: --cpu-percent=70
kubectl get hpa -w
kubectl describe hpa web     # ver condiciones AbleToScale, ScalingActive, ScalingLimited
```

**VPA** (proyecto aparte, `autoscaler` de SIG Autoscaling): recomienda/ajusta requests. Modos `Off`, `Initial`, `Recreate`, `InPlaceOrRecreate` (aprovecha el resize in-place).

**Resize in-place** de pods: modificar `resources` de un pod en ejecución vía subrecurso `resize` (`kubectl patch pod x --subresource resize --patch ...`); `resizePolicy` por recurso decide si reinicia el contenedor.

**Autoscaling de nodos**: Cluster Autoscaler o Karpenter (ver "Node Autoscaling"). Escalan por pods Pending que no caben.

## 10. Disrupciones y PDB

- **Involuntarias**: fallo de hardware, kernel panic, nodo desaparece, evicción por presión de recursos.
- **Voluntarias**: drain, borrado de pods, actualización de Deployment, autoscaler que quita nodos.
- **PodDisruptionBudget** (`policy/v1`) solo limita disrupciones voluntarias que usan la API de Eviction (drain las usa; borrar el pod o actualizar el Deployment no).
  - `minAvailable` o `maxUnavailable` (número o %). Usa uno solo.
  - `unhealthyPodEvictionPolicy: AlwaysAllow` evita que pods que nunca están Ready bloqueen los drains.
  - Un PDB con `maxUnavailable: 0` o `minAvailable` = réplicas bloquea los drains para siempre: error común.

## 11. Otros

- **Downward API**: exponer al contenedor datos del pod (`metadata.name`, `metadata.namespace`, `status.podIP`, `spec.nodeName`, labels, annotations, requests/limits) vía `env.valueFrom.fieldRef` / `resourceFieldRef` o volumen `downwardAPI`.
- **Static pods**: manifiestos en `/etc/kubernetes/manifests` gestionados directamente por el kubelet (así corre el control plane en kubeadm). El apiserver muestra un "mirror pod" de solo lectura.
- **QoS** (ver scheduling-y-recursos.md): Guaranteed, Burstable, BestEffort.
- **Pod hostname**: `spec.hostname`, `spec.subdomain` (con headless Service da DNS por pod), `setHostnameAsFQDN`.
- **User namespaces** (`spec.hostUsers: false`): root dentro del contenedor mapea a usuario sin privilegios en el host.
- **Docker Compose → Kubernetes**: la doc oficial muestra `kompose convert`; revisa siempre el resultado (no agrega probes, recursos ni securityContext).
