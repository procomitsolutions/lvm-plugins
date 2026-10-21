# Troubleshooting por síntoma

## Contenido
1. Rutina de diagnóstico general
2. Estados de Pod: Pending, ContainerCreating, ImagePullBackOff, CrashLoopBackOff, OOMKilled, CreateContainerConfigError, Error/Completed, Terminating
3. Pod Running pero no funciona (readiness, tráfico)
4. Services y conectividad
5. DNS
6. Deployments, StatefulSets y rollouts atascados
7. Nodos (NotReady, presión de recursos)
8. Control plane, kubectl y certificados
9. Herramientas: kubectl debug, crictl, events, logs, metrics

---

## 1. Rutina general

```bash
kubectl get pods -n <ns> -o wide                 # estado, reinicios, nodo, IP
kubectl describe pod <pod> -n <ns>               # Conditions + Events (¡al final!)
kubectl logs <pod> -n <ns> [-c <contenedor>]     # logs actuales
kubectl logs <pod> -n <ns> --previous            # logs del contenedor que murió
kubectl get events -n <ns> --sort-by=.lastTimestamp
kubectl events -n <ns> --for pod/<pod>           # eventos filtrados por objeto
kubectl get pod <pod> -n <ns> -o yaml            # status.containerStatuses completo
```
Atajo: `scripts/diagnose.sh pod <pod> -n <ns>` reúne todo eso.

Motivo y código de salida del último fallo:
```bash
kubectl get pod <pod> -n <ns> -o jsonpath='{range .status.containerStatuses[*]}{.name}{"\t"}{.lastState.terminated.reason}{"\t"}{.lastState.terminated.exitCode}{"\n"}{end}'
```
Exit codes: `0` éxito · `1`/`2` error de la app · `126` no ejecutable · `127` comando no encontrado (CMD/entrypoint mal escrito) · `137` SIGKILL (OOMKilled o killed por liveness/grace period) · `139` segfault · `143` SIGTERM.

Un contenedor puede escribir un mensaje de terminación en `/dev/termination-log` (o usar `terminationMessagePolicy: FallbackToLogsOnError`) que aparece en `describe`.

## 2. Estados de Pod

### Pending
El scheduler no pudo ubicarlo. Mira el evento `FailedScheduling`:
| Mensaje | Causa | Solución |
|---|---|---|
| `Insufficient cpu/memory` | Requests no caben en ningún nodo | Bajar requests, agregar nodos, revisar autoscaler |
| `node(s) had untolerated taint` | Taints sin toleration | Toleration o quitar taint |
| `didn't match Pod's node affinity/selector` | nodeSelector/afinidad sin nodos que coincidan | Revisar labels de nodos (`kubectl get nodes --show-labels`) |
| `didn't match pod anti-affinity rules` / `topology spread constraints` | Restricciones demasiado duras | `preferred` / `ScheduleAnyway` |
| `pod has unbound immediate PersistentVolumeClaims` | PVC Pending | Ver storage.md |
| `volume node affinity conflict` | Volumen en otra zona | `WaitForFirstConsumer` |
| `exceeded quota` (en eventos del ReplicaSet, el pod ni se crea) | ResourceQuota | `kubectl describe quota`, LimitRange con defaults |
| Sin eventos | Scheduler caído o `schedulerName` inexistente, o `schedulingGates` | Revisar `kube-scheduler` en kube-system, `spec.schedulingGates` |

### ContainerCreating / PodInitializing prolongado
Eventos `FailedMount` (Secret/ConfigMap/PVC inexistente, volumen adjunto a otro nodo: `Multi-Attach error`), `FailedCreatePodSandBox` (problema de CNI: plugin no instalado, IPs agotadas en el pool) o descarga lenta de imágenes grandes. Init containers que no terminan: `kubectl logs <pod> -c <init>`.

### ImagePullBackOff / ErrImagePull
- Nombre o tag mal escrito / inexistente (`manifest unknown`).
- Registry privado sin `imagePullSecrets` o con credenciales vencidas (`unauthorized`, `401/403`).
- Rate limit (Docker Hub `toomanyrequests`): usar mirror o credenciales.
- El nodo no llega al registry (proxy, DNS, firewall).
- Arquitectura incorrecta (`no matching manifest for linux/arm64`).
Probar desde el nodo: `crictl pull <imagen>`.

### CrashLoopBackOff
El contenedor arranca y muere repetidamente (backoff hasta 5 min).
1. `kubectl logs --previous` y exit code.
2. Causas típicas: error de configuración/variable faltante, dependencia no disponible al arrancar, comando/args mal escritos (exit 127), permisos (filesystem de solo lectura, usuario no root sin permisos en un directorio), puerto ya en uso, **liveness probe** que mata la app antes de que arranque (eventos `Unhealthy` + `Killing`), OOMKilled al arrancar.
3. Si el contenedor muere tan rápido que no hay logs: `kubectl debug <pod> -it --copy-to=dbg --container=app -- sh` (copia el pod cambiando el comando) o sobrescribir `command: ["sleep","3600"]` temporalmente para inspeccionar.

### OOMKilled (exit 137, reason OOMKilled)
- El contenedor superó su limit de memoria → subir el limit o corregir la fuga.
- JVM/Node/Go: ajustar el heap al limit del contenedor (`-XX:MaxRAMPercentage`, `--max-old-space-size`, `GOMEMLIMIT`).
- Si `reason: OOMKilled` pero el uso parece bajo: `emptyDir medium: Memory` cuenta contra el limit; también page cache en cgroup v2.
- Si el pod aparece `Evicted` (no OOMKilled): fue el kubelet por presión del nodo → revisar requests realistas y reservas del nodo.

### CreateContainerConfigError / CreateContainerError
Falta un ConfigMap/Secret o una clave referenciada en `env` (ver mensaje exacto en describe), `runAsNonRoot: true` con imagen que corre como root sin `runAsUser` numérico, subPath inválido.

### Error / Completed en un Deployment
`Completed` en un Deployment significa que el proceso principal terminó con 0: la app no es un proceso de larga duración (o el CMD es incorrecto). Los Deployments necesitan procesos que no terminen.

### Terminating eterno
- Finalizers pendientes (`kubectl get pod x -o jsonpath='{.metadata.finalizers}'`).
- Nodo caído: el kubelet no confirma la muerte. Para StatefulSets **no** fuerces si el nodo puede volver; confirma que el nodo está realmente muerto (o aplica el taint `node.kubernetes.io/out-of-service`).
- Último recurso: `kubectl delete pod x --grace-period=0 --force`.
- Namespace en Terminating: buscar recursos restantes (`kubectl api-resources --verbs=list --namespaced -o name | xargs -n1 kubectl get -n <ns> --ignore-not-found --show-kind`) y APIServices caídos (`kubectl get apiservice | grep False`), que impiden el borrado.

## 3. Pod Running pero no recibe tráfico

- `READY 0/1`: readinessProbe falla → eventos `Unhealthy`; probar la ruta: `kubectl exec <pod> -- wget -qO- localhost:8080/healthz`.
- La app escucha solo en `127.0.0.1`: debe escuchar en `0.0.0.0`.
- `containerPort` es solo informativo; lo que cuenta es el puerto real de la app y el `targetPort` del Service.
- Acceso directo para aislar el problema: `kubectl port-forward pod/<pod> 8080:8080`.

## 4. Services y conectividad

Secuencia oficial ("Debug Services"):
1. ¿Existe el Service? `kubectl get svc <svc> -n <ns>`
2. ¿Tiene endpoints? `kubectl get endpointslices -n <ns> -l kubernetes.io/service-name=<svc>` → si está vacío:
   - El `selector` no coincide con las labels de los pods: `kubectl get pods -n <ns> -l <selector>` (comparar con `kubectl get svc <svc> -o jsonpath='{.spec.selector}'`).
   - Los pods no están Ready.
3. ¿El `targetPort` coincide con el puerto real del contenedor?
4. Probar desde dentro: `kubectl run tmp --rm -it --image=busybox:1.36 --restart=Never -- wget -qO- http://<svc>.<ns>:<port>`.
5. ¿Resuelve DNS? (sección 5).
6. ¿Funciona por IP del pod y no por IP del Service? → kube-proxy o CNI: `kubectl -n kube-system logs ds/kube-proxy`, reglas iptables/nftables en el nodo.
7. ¿Hay NetworkPolicies que lo bloqueen? `kubectl get networkpolicy -n <ns>`; recordar el egress a DNS.
8. LoadBalancer en `<pending>`: no hay cloud-controller-manager / MetalLB, o cuotas del proveedor. Ver eventos del Service.
9. Ingress devuelve 404/503: `ingressClassName` incorrecto, controlador no instalado, Service/puerto backend mal referenciado, logs del controlador.

Herramienta útil para red: imagen `nicolaka/netshoot` con `kubectl debug` (curl, dig, tcpdump, ss).

## 5. DNS

```bash
kubectl run dnsutils --rm -it --image=registry.k8s.io/e2e-test-images/agnhost:2.39 --restart=Never -- nslookup kubernetes.default
kubectl exec -it <pod> -- cat /etc/resolv.conf     # nameserver = IP de kube-dns, search, ndots
kubectl -n kube-system get pods -l k8s-app=kube-dns
kubectl -n kube-system logs -l k8s-app=kube-dns
kubectl -n kube-system get endpointslices -l kubernetes.io/service-name=kube-dns
```
Causas: CoreDNS caído o en Pending (sin CNI), NetworkPolicy que bloquea el puerto 53, bucle de forward (CoreDNS con `loop` detectado porque el nodo usa `127.0.0.53` de systemd-resolved: apuntar el kubelet `resolvConf` a `/run/systemd/resolve/resolv.conf`), latencia por `ndots:5`, problemas de conntrack con UDP (NodeLocal DNSCache).

## 6. Rollouts atascados

- `kubectl rollout status deploy/x` se queda esperando → `kubectl describe deploy x` (Conditions) y `kubectl describe rs <nuevo-rs>` (eventos de creación: cuota, PSA, admission webhooks rechazando).
- Pods nuevos no pasan readiness → el rollout se detiene (por diseño, protege). Arreglar y volver a aplicar, o `kubectl rollout undo`.
- `ProgressDeadlineExceeded`: no se revierte solo.
- HPA y `replicas` en el manifiesto peleando: quitar `replicas` del YAML.
- StatefulSet atascado con un pod roto: corregir el template y borrar el pod roto para que se recree con la nueva revisión.
- Cambiar el selector de un Deployment → error `field is immutable`: hay que recrear el Deployment.

## 7. Nodos

**NotReady**:
```bash
kubectl describe node <nodo>          # Conditions: Ready, MemoryPressure, DiskPressure, PIDPressure, NetworkUnavailable
# En el nodo:
systemctl status kubelet
journalctl -u kubelet -f --since "10 min ago"
systemctl status containerd
crictl ps -a; crictl pods
```
Causas: kubelet detenido o con certificado vencido, runtime caído, CNI no inicializado (`network plugin is not ready: cni config uninitialized`), disco lleno, swap activada sin configuración, driver de cgroups distinto entre kubelet y runtime, reloj desincronizado, nodo sin conectividad con el apiserver.

**Depurar un nodo sin SSH**: `kubectl debug node/<nodo> -it --image=busybox:1.36` (monta el filesystem del host en `/host`; `chroot /host` para usar sus herramientas).

**Presión de recursos**: `kubectl top nodes`, `kubectl describe node` (Allocated resources), revisar evicciones recientes y GC de imágenes.

## 8. Control plane, kubectl y certificados

- `The connection to the server localhost:8080 was refused`: no hay kubeconfig (`export KUBECONFIG=...` o `~/.kube/config`).
- `Unable to connect ... x509: certificate has expired or is not yet valid`: certificados vencidos (kubeadm: `kubeadm certs check-expiration`, `kubeadm certs renew all`, reiniciar los static pods del control plane y actualizar el kubeconfig de admin) o reloj desincronizado.
- `x509: certificate signed by unknown authority`: kubeconfig de otro cluster o CA rotada.
- `Forbidden`: RBAC → `kubectl auth can-i ...`, `kubectl auth whoami`.
- Control plane kubeadm: son static pods en `/etc/kubernetes/manifests`; si el apiserver no responde, usar `crictl ps -a | grep kube-apiserver` y `crictl logs <id>` en el nodo.
- Salud: `kubectl get --raw='/readyz?verbose'`, `kubectl get --raw='/livez?verbose'`.
- etcd: `etcdctl endpoint health --cluster` (con certificados), espacio de la BD (`NOSPACE` → compactar y desfragmentar).
- Lentitud del apiserver: API Priority and Fairness (`kubectl get flowschemas,prioritylevelconfigurations`, métricas `apiserver_flowcontrol_*`), webhooks lentos, clientes con list masivos.
- Verbosidad de kubectl para ver las llamadas HTTP: `kubectl get pods -v=8`.

## 9. Herramientas

- **`kubectl debug`**:
  - Contenedor efímero en un pod vivo: `kubectl debug -it <pod> --image=busybox:1.36 --target=<contenedor>` (comparte namespace de procesos con el target).
  - Copia del pod con cambios: `--copy-to=<nuevo> --set-image=app=...` o `--share-processes`.
  - Nodo: `kubectl debug node/<nodo> -it --image=...`.
  - Perfiles: `--profile=general|baseline|restricted|netadmin|sysadmin`.
- **`kubectl exec -it <pod> -- sh`** (si la imagen tiene shell; distroless no → usar debug).
- **`kubectl cp`** (requiere `tar` en el contenedor).
- **`crictl`** en el nodo: `crictl ps`, `crictl logs`, `crictl inspect`, `crictl images`, `crictl pull`.
- **Métricas**: metrics-server para `kubectl top pod --containers` / `kubectl top node`; kube-state-metrics + Prometheus para estado de objetos; logs del sistema del kubelet en journald.
- **Auditoría** para saber quién cambió/borró algo.
- **Telepresence** u otras herramientas para depurar servicios localmente contra el cluster.
