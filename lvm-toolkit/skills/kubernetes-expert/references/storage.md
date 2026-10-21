# Almacenamiento

## Contenido
1. Volúmenes (efímeros y tipos comunes)
2. PersistentVolume / PersistentVolumeClaim
3. StorageClass y aprovisionamiento dinámico
4. CSI, snapshots, clonado, expansión, VolumeAttributesClass
5. Almacenamiento efímero local y límites
6. Problemas típicos

---

## 1. Volúmenes

Un volumen vive lo que vive el Pod (efímero) o más (persistente). Se declara en `spec.volumes` y se monta con `containers[].volumeMounts` (`mountPath`, `subPath`, `readOnly`).

| Tipo | Uso |
|---|---|
| `emptyDir` | Scratch compartido entre contenedores del pod; se borra con el pod. `medium: Memory` usa tmpfs (cuenta contra el límite de memoria). `sizeLimit` recomendado |
| `configMap`, `secret`, `downwardAPI` | Inyectar configuración como archivos (se actualizan solos, salvo con `subPath`) |
| `projected` | Combinar varias fuentes en un directorio, incluido `serviceAccountToken` con audiencia y expiración y `clusterTrustBundle` |
| `persistentVolumeClaim` | Almacenamiento persistente |
| `ephemeral` (generic ephemeral volume) | PVC creado y borrado con el pod; da almacenamiento de un StorageClass sin persistir |
| `csi` (inline) | Volúmenes efímeros de drivers CSI (p. ej. Secrets Store CSI Driver) |
| `image` | Montar el contenido de una imagen OCI como volumen de solo lectura (modelos, datos) |
| `hostPath` | Ruta del nodo. **Riesgo de seguridad**; prohibido por PSS baseline salvo excepciones. Solo para agentes de sistema |
| `local` | Disco local de un nodo como PV (con node affinity); sin aprovisionamiento dinámico nativo |
| `nfs`, `iscsi`, `fc` | Volúmenes de red legados en árbol |

Los drivers "in-tree" de nubes (awsElasticBlockStore, gcePersistentDisk, azureDisk, cinder, vsphereVolume…) fueron migrados a CSI y eliminados del código: usa los drivers CSI del proveedor.

## 2. PV y PVC

- **PersistentVolume (PV)**: recurso de almacenamiento del cluster (cluster-scoped), aprovisionado estática o dinámicamente.
- **PersistentVolumeClaim (PVC)**: solicitud de un usuario (namespaced): tamaño, modo de acceso, StorageClass.
- **Access modes**: `ReadWriteOnce` (RWO, un nodo), `ReadOnlyMany` (ROX), `ReadWriteMany` (RWX, varios nodos; requiere backend que lo soporte: NFS, CephFS, EFS, Azure Files…), `ReadWriteOncePod` (RWOP, un solo pod en todo el cluster).
- **volumeMode**: `Filesystem` (defecto) o `Block` (dispositivo crudo).
- **Reclaim policy**: `Delete` (defecto en dinámico: borrar el PVC borra el disco) o `Retain` (el PV queda `Released` y hay que limpiarlo a mano). `Recycle` está deprecado. Cambiar en un PV existente: `kubectl patch pv <pv> -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'`.
- **Fases del PV**: `Available`, `Bound`, `Released`, `Failed`.
- **Protección**: finalizers `kubernetes.io/pvc-protection` / `pv-protection` impiden borrar un PVC en uso (queda `Terminating` hasta que el pod se va).
- Para re-enlazar un PV `Released` a un nuevo PVC: quitar `spec.claimRef` del PV (con cuidado) o pre-asignar con `spec.volumeName` en el PVC.

## 3. StorageClass

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com      # depende del driver
parameters:
  type: gp3
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

- **`volumeBindingMode: WaitForFirstConsumer`** retrasa el aprovisionamiento hasta que el pod se programa: evita crear el disco en una zona distinta a la del pod (causa clásica de pods Pending con "volume node affinity conflict"). `Immediate` es el valor por defecto.
- `allowedTopologies` restringe zonas.
- Solo debería haber **un** StorageClass por defecto; un PVC sin `storageClassName` usa el default; `storageClassName: ""` pide explícitamente un PV estático sin clase.
- Cambiar el default: quitar la anotación del viejo y ponerla en el nuevo.

## 4. CSI y funciones avanzadas

- **CSI (Container Storage Interface)**: estándar para drivers externos. Objetos: `CSIDriver`, `CSINode`, `VolumeAttachment`, `CSIStorageCapacity` (capacidad por topología para que el scheduler elija bien).
- **Expansión**: `allowVolumeExpansion: true` y editar `spec.resources.requests.storage` del PVC (solo crecer). Según el driver puede requerir reinicio del pod para expandir el filesystem.
- **VolumeSnapshot / VolumeSnapshotClass / VolumeSnapshotContent** (`snapshot.storage.k8s.io/v1`): requieren las CRDs y el snapshot-controller externos más un driver CSI compatible. Restaurar = PVC con `dataSource` apuntando al snapshot.
- **Clonado**: PVC con `dataSource: {kind: PersistentVolumeClaim, name: origen}` (mismo namespace y StorageClass).
- **Volume populators**: `dataSourceRef` para poblar desde fuentes personalizadas.
- **VolumeAttributesClass**: cambiar parámetros mutables (IOPS, throughput) de un volumen en vivo, sin recrearlo, si el driver lo soporta.
- **Volume health monitoring** y límites de volúmenes por nodo (`CSINode` → `allocatable.count`).
- Backups de aplicaciones con estado: los snapshots no son backups consistentes por sí solos; considera Velero u herramientas de la BD.

## 5. Almacenamiento efímero local

- Recurso `ephemeral-storage` (logs de contenedores, capa escribible, emptyDir en disco). Define `requests`/`limits` de `ephemeral-storage`; si un pod excede el límite, el kubelet lo desaloja.
- Presión de disco del nodo (`DiskPressure`) dispara evicción y garbage collection de imágenes.

## 6. Problemas típicos

| Síntoma | Causa probable | Qué mirar |
|---|---|---|
| PVC en `Pending` | No hay StorageClass default, provisioner no instalado, capacidad, zona | `kubectl describe pvc`, eventos del provisioner, `kubectl get sc` |
| Pod Pending "volume node affinity conflict" | Disco creado en otra zona | `WaitForFirstConsumer`, topología |
| `Multi-Attach error` | Volumen RWO aún adjunto a otro nodo (p. ej. durante rolling update o nodo caído) | Estrategia `Recreate` para RWO, esperar detach, revisar `VolumeAttachment` |
| Permiso denegado al escribir | UID/GID del contenedor no coincide con el volumen | `securityContext.fsGroup`, `fsGroupChangePolicy: OnRootMismatch`, `runAsUser` |
| Montaje lento en volúmenes grandes | `chown` recursivo por `fsGroup` | `fsGroupChangePolicy: OnRootMismatch`; con SELinux, mount option en vez de relabel (SELinuxMount, Stable en 1.37) |
| PVC atascado en `Terminating` | Un pod aún lo usa | `kubectl get pods -A -o json | jq` buscando el claimName; borrar el pod |
| ConfigMap montado no se actualiza | Montado con `subPath`, o la app no relee | Quitar `subPath`, o `kubectl rollout restart` |
