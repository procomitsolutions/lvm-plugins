# Administración de clusters

## Contenido
1. Elegir cómo instalar (aprendizaje vs producción)
2. kubeadm: requisitos, init, join, HA
3. Upgrades
4. etcd: backup y restore
5. Certificados
6. Mantenimiento de nodos (drain, cordon)
7. Runtimes y migración desde dockershim
8. Observabilidad (logs, métricas, trazas)
9. Clusters grandes, multi-zona y Windows

---

## 1. Opciones de instalación

- **Aprendizaje/local**: minikube, kind (Kubernetes in Docker; ideal para CI), k3d, Docker Desktop. Herramientas: kubectl, kind, minikube, kubeadm.
- **Producción autogestionada**: kubeadm (oficial), Cluster API, kOps, Kubespray; distribuciones como k3s, RKE2, Talos, OpenShift.
- **Gestionado** ("turnkey"): EKS, GKE, AKS, DOKS, OKE, etc. El proveedor opera control plane y etcd; tú gestionas nodos (o no, con modos tipo Autopilot/Fargate/Karpenter).

## 2. kubeadm

**Requisitos de cada nodo**: Linux compatible, 2 GB RAM, 2 CPUs en control plane, conectividad total entre nodos, hostname/MAC/`product_uuid` únicos, puertos abiertos (6443, 2379-2380, 10250, 10257, 10259, 30000-32767), swap deshabilitada o configurada para el kubelet, runtime CRI instalado.

**Preparar el nodo** (resumen; verifica la página "Container Runtimes"):
```bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay && sudo modprobe br_netfilter
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system
# containerd con SystemdCgroup = true en /etc/containerd/config.toml
```

**Repositorio de paquetes**: `pkgs.k8s.io` (los repos legados `apt.kubernetes.io`/`yum.kubernetes.io` se congelaron y eliminaron). Hay un repo por minor: `https://pkgs.k8s.io/core:/stable:/v1.37/deb/`. Para subir de minor hay que **cambiar el repo** ("Changing The Kubernetes Package Repository"). Fijar versiones: `apt-mark hold kubelet kubeadm kubectl`.

**Crear el cluster**:
```bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 \
  --control-plane-endpoint=k8s-api.example.com:6443 --upload-certs
mkdir -p $HOME/.kube && sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config && sudo chown $(id -u):$(id -g) $HOME/.kube/config
# instalar CNI (manifiesto/helm del proveedor elegido)
kubeadm token create --print-join-command        # para unir workers
```
Mejor aún: archivo de configuración `kubeadm init --config kubeadm.yaml` (API `kubeadm.k8s.io/v1beta4`; v1beta3 está deprecada) con `ClusterConfiguration`, `InitConfiguration`, `KubeletConfiguration`, `KubeProxyConfiguration`. `kubeadm config print init-defaults` muestra un ejemplo; `kubeadm config migrate` convierte versiones.

**Alta disponibilidad**:
- Topología **stacked etcd** (etcd en los mismos nodos del control plane; más simple) o **external etcd** (más resiliente, más nodos).
- Mínimo 3 nodos de control plane; un load balancer (o kube-vip/keepalived+haproxy) delante del puerto 6443 apuntado por `--control-plane-endpoint`.
- Unir control planes adicionales: `kubeadm join ... --control-plane --certificate-key <clave>`.
- Quórum etcd: 3 miembros toleran 1 caída; 5 toleran 2.

**Deshacer**: `kubeadm reset` (no limpia iptables/IPVS, CNI ni kubeconfig: hacerlo a mano). Destructivo.

## 3. Upgrades (kubeadm)

Reglas: una minor por vez; control plane antes que workers; leer release notes y la guía de APIs eliminadas; backup de etcd antes; revisar compatibilidad del CNI, CSI, ingress y operadores con la nueva versión.

```bash
# 1. Primer nodo de control plane
# cambiar el repo de paquetes a la nueva minor
sudo apt-mark unhold kubeadm && sudo apt-get update && sudo apt-get install -y kubeadm='1.37.1-*' && sudo apt-mark hold kubeadm
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.37.1
# 2. Otros nodos de control plane
sudo kubeadm upgrade node
# 3. En cada nodo (control plane y luego workers, de a uno o por lotes)
kubectl drain <nodo> --ignore-daemonsets --delete-emptydir-data
sudo apt-mark unhold kubelet kubectl && sudo apt-get install -y kubelet='1.37.1-*' kubectl='1.37.1-*' && sudo apt-mark hold kubelet kubectl
# en workers, antes del kubelet: actualizar kubeadm y correr `sudo kubeadm upgrade node`
sudo systemctl daemon-reload && sudo systemctl restart kubelet
kubectl uncordon <nodo>
```
`kubeadm upgrade apply` renueva los certificados del control plane por defecto. En clusters gestionados, seguir el procedimiento del proveedor (actualizan el control plane y luego node pools). Después del upgrade: migrar objetos almacenados a la nueva versión de storage si corresponde ("Storage Version Migration").

## 4. etcd

**Backup**:
```bash
ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-$(date +%F).db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
etcdutl snapshot status /backup/etcd-....db -w table
```
Guarda también `/etc/kubernetes/pki` (las CA). Automatiza y cifra los backups; pruébalos.

**Restore** (destructivo; detener el apiserver primero, idealmente en todos los miembros):
```bash
etcdutl snapshot restore /backup/etcd.db --data-dir /var/lib/etcd-restore
# apuntar el static pod de etcd (/etc/kubernetes/manifests/etcd.yaml) al nuevo data-dir (hostPath), esperar a que reinicie
```
En clusters multi-miembro hay que restaurar todos los miembros desde el mismo snapshot con un nuevo cluster token. Tras restaurar, los controladores reconcilian el estado: puede haber pods recreados.

Mantenimiento: `etcdctl defrag`, compactación (el apiserver compacta automáticamente), cuota de espacio (`--quota-backend-bytes`), alarma `NOSPACE`. Discos SSD de baja latencia: etcd es sensible a la latencia de fsync.

## 5. Certificados

- kubeadm genera una PKI en `/etc/kubernetes/pki`: CA del cluster, CA de etcd, CA de front-proxy, y certificados de apiserver, kubelet-client, etc. Vigencia: **1 año** los certificados de hoja; 10 años las CA.
- `kubeadm certs check-expiration`, `kubeadm certs renew all` (luego reiniciar los static pods del control plane moviendo temporalmente los manifiestos o reiniciando el kubelet, y copiar el nuevo `admin.conf`).
- Kubelet: rotación automática del certificado de cliente (`rotateCertificates: true`); certificados de servidor del kubelet firmados vía CSR requieren aprobación (`serverTLSBootstrap` + aprobador).
- CSRs: `kubectl get csr`, `kubectl certificate approve <csr>`. Emitir certificados de cliente para usuarios vía `CertificateSigningRequest` con `signerName: kubernetes.io/kube-apiserver-client`.
- Rotación manual de la CA: procedimiento largo y delicado (ver "Manual Rotation of CA Certificates").
- Certificados para apps: cert-manager (no es parte del core).
- `ClusterTrustBundle` y `PodCertificateRequest` permiten distribuir anclas de confianza y emitir certificados para pods (verifica su estado en tu versión).

## 6. Mantenimiento de nodos

```bash
kubectl cordon <nodo>            # no programar más pods
kubectl drain <nodo> --ignore-daemonsets --delete-emptydir-data [--timeout=10m]
# mantenimiento…
kubectl uncordon <nodo>
```
- drain usa la API de Eviction → respeta PDBs; si se queda esperando, algún PDB no permite la evicción (revisa `kubectl get pdb -A`).
- Pods sin controlador bloquean el drain (requieren `--force`, y se pierden).
- Quitar un nodo: drain → `kubectl delete node <nodo>` → `kubeadm reset` en el nodo.

## 7. Runtimes

- containerd o CRI-O. El kubelet se comunica vía CRI (`--container-runtime-endpoint`, p. ej. `unix:///run/containerd/containerd.sock`).
- dockershim eliminado en 1.24: para migrar de Docker Engine a containerd, drain → instalar/configurar containerd → apuntar el kubelet → uncordon. Las imágenes construidas con Docker siguen funcionando (son OCI).
- Ver qué runtime usa cada nodo: `kubectl get nodes -o wide` (columna CONTAINER-RUNTIME).
- Agentes que montaban `/var/run/docker.sock` deben migrar.
- `RuntimeClass` para elegir runtimes alternativos (gVisor `runsc`, Kata) por pod.

## 8. Observabilidad

- **Logs**: los contenedores escriben a stdout/stderr; el kubelet rota logs (`containerLogMaxSize`, `containerLogMaxFiles`). Agregación con un agente DaemonSet (Fluent Bit, Vector, OpenTelemetry Collector) hacia Loki/Elasticsearch/servicio cloud. Logs de componentes del sistema: journald o archivos; formato JSON y logging estructurado disponibles.
- **Métricas**: componentes exponen `/metrics` en formato Prometheus; metrics-server (pipeline de métricas de recursos, `metrics.k8s.io` GA en 1.37) para HPA/top; kube-state-metrics para estado de objetos; métricas cAdvisor/CRI y PSI (Pressure Stall Information) de nodos.
- **Trazas**: apiserver y kubelet pueden emitir trazas OpenTelemetry (OTLP).
- **z-pages** (`/statusz`, `/flagz`) para inspeccionar componentes.
- **Eventos**: retención corta (1 h por defecto); exportarlos si se necesitan para auditoría.

## 9. Otros temas de administración

- **Clusters grandes** (límites probados oficialmente): hasta 5.000 nodos, 150.000 pods totales, 300.000 contenedores, 110 pods por nodo. Escalar etcd y apiserver, separar eventos en otro etcd si hace falta.
- **Multi-zona**: nodos en varias zonas, control plane repartido, topology spread, StorageClass con `WaitForFirstConsumer`, etcd en número impar de zonas.
- **Feature gates**: `--feature-gates=Nombre=true` en cada componente (o en su archivo de configuración); revisar la tabla oficial por versión.
- **Kubelet**: configurar vía archivo `KubeletConfiguration` (`/var/lib/kubelet/config.yaml`), con soporte de directorio drop-in (`--config-dir`) para fusionar fragmentos.
- **Windows**: nodos worker Windows soportados (control plane solo Linux); usar `nodeSelector: kubernetes.io/os: windows`; HostProcess pods y GMSA para casos especiales; diferencias de red y almacenamiento.
- **Addons**: instalar CNI, CoreDNS (kubeadm lo trae), metrics-server, ingress/gateway, CSI, autoscaler de nodos, cert-manager, políticas.
- **Verificar artefactos firmados** de Kubernetes (binarios e imágenes de `registry.k8s.io`) con cosign.
- **Registro de imágenes oficial**: `registry.k8s.io` (reemplazó a `k8s.gcr.io`, congelado).
