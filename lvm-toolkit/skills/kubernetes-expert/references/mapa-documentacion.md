# Mapa de la documentación oficial (kubernetes.io, v1.37)

Base: `https://kubernetes.io/docs/`. Para versiones anteriores reemplaza el dominio por `https://v1-36.docs.kubernetes.io`, `https://v1-35.docs.kubernetes.io`, etc. Agrega `_print/` al final de una sección para verla completa en una página. Existe traducción al español en `https://kubernetes.io/es/docs/` (menos completa y a veces desactualizada: prefiere la versión en inglés para detalles).

Estructura: **Setup** (instalar) · **Concepts** (cómo funciona) · **Tasks** (cómo hacer X) · **Tutorials** (ejemplos completos) · **Reference** (API, kubectl, flags, configs).

## Setup
- Inicio / entornos: `setup/`, `setup/learning-environment/`, `setup/production-environment/`
- Runtimes: `setup/production-environment/container-runtimes/`
- kubeadm: `setup/production-environment/tools/kubeadm/` → `install-kubeadm/`, `create-cluster-kubeadm/`, `high-availability/`, `ha-topology/`, `setup-ha-etcd-with-kubeadm/`, `kubelet-integration/`, `control-plane-flags/`, `troubleshooting-kubeadm/`, `dual-stack-support/`
- Buenas prácticas: `setup/best-practices/` → `cluster-large/`, `multiple-zones/`, `node-conformance/`, `enforcing-pod-security-standards/`, `certificates/`

## Concepts
- Overview: `concepts/overview/`, `components/`, `kubernetes-api/`, `kubectl/`, `working-with-objects/` (names, labels, namespaces, annotations, field-selectors, finalizers, owners-dependents, common-labels, storage-version, object-management)
- Arquitectura: `concepts/architecture/` → `nodes/`, `control-plane-node-communication/`, `controller/`, `leases/`, `cloud-controller/`, `cgroups/`, `self-healing/`, `garbage-collection/`, `mixed-version-proxy/`
- Contenedores: `concepts/containers/` → `images/`, `container-environment/`, `runtime-class/`, `container-lifecycle-hooks/`, `cri/`
- Pods: `concepts/workloads/pods/` → `pod-lifecycle/`, `pod-condition/`, `init-containers/`, `sidecar-containers/`, `ephemeral-containers/`, `probes/`, `disruptions/`, `pod-hostname/`, `pod-qos/`, `static-pods/`, `user-namespaces/`, `downward-api/`, `advanced-pod-config/`
- Controladores: `concepts/workloads/controllers/` → `deployment/`, `replicaset/`, `statefulset/`, `daemonset/`, `job/`, `ttlafterfinished/`, `cron-jobs/`
- Workload API / PodGroup: `concepts/workloads/workload-api/`, `podgroup-api/`, `compositepodgroup-api/`
- Autoscaling: `concepts/workloads/autoscaling/` → `horizontal-pod-autoscale/`, `vertical-pod-autoscale/`
- Red: `concepts/services-networking/` → `service/`, `ingress/`, `ingress-controllers/`, `gateway/`, `endpoint-slices/`, `network-policies/`, `dns-pod-service/`, `dual-stack/`, `topology-aware-routing/`, `cluster-ip-allocation/`, `service-traffic-policy/`
- Storage: `concepts/storage/` → `volumes/`, `persistent-volumes/`, `projected-volumes/`, `ephemeral-volumes/`, `storage-classes/`, `volume-attributes-classes/`, `dynamic-provisioning/`, `volume-snapshots/`, `volume-pvc-datasource/`, `storage-capacity/`, `storage-limits/`, `ephemeral-storage/`
- Configuración: `concepts/configuration/` → `configmap/`, `secret/`, `manage-resources-containers/`, `organize-cluster-access-kubeconfig/`
- Seguridad: `concepts/security/` → `pod-security-standards/`, `pod-security-admission/`, `service-accounts/`, `controlling-access/`, `rbac-good-practices/`, `secrets-good-practices/`, `multi-tenancy/`, `hardening-guide/*`, `api-server-bypass-risks/`, `linux-kernel-security-constraints/`, `security-checklist/`, `application-security-checklist/`
- Políticas: `concepts/policy/` → `limit-range/`, `resource-quotas/`, `pid-limiting/`
- Scheduling: `concepts/scheduling-eviction/` → `kube-scheduler/`, `assign-pod-node/`, `taint-and-toleration/`, `topology-spread-constraints/`, `pod-priority-preemption/`, `node-pressure-eviction/`, `api-eviction/`, `pod-scheduling-readiness/`, `pod-overhead/`, `scheduling-framework/`, `gang-scheduling/`, `resource-bin-packing/`
- Recursos/DRA: `concepts/resource-management/` → `resource-managers/`, `dynamic-resource-allocation/`
- Admin de cluster: `concepts/cluster-administration/` → `node-shutdown/`, `swap-memory-management/`, `node-autoscaling/`, `certificates/`, `networking/`, `observability/`, `logging/`, `system-metrics/`, `kube-state-metrics/`, `system-logs/`, `system-traces/`, `flow-control/`, `addons/`, `admission-webhooks-good-practices/`, `compatibility-version/`
- Windows: `concepts/windows/`
- Extensión: `concepts/extend-kubernetes/` → `api-extension/custom-resources/`, `api-extension/apiserver-aggregation/`, `operator/`, `compute-storage-net/network-plugins/`, `compute-storage-net/device-plugins/`

## Tasks (cómo hacer)
- Instalar kubectl: `tasks/tools/`
- Administrar: `tasks/administer-cluster/` → `kubeadm/kubeadm-upgrade/`, `kubeadm/kubeadm-certs/`, `kubeadm/adding-linux-nodes/`, `kubeadm/change-package-repository/`, `configure-upgrade-etcd/`, `safely-drain-node/`, `encrypt-data/`, `kms-provider/`, `reserve-compute-resources/`, `manage-resources/*`, `network-policy-provider/*`, `declare-network-policy/`, `dns-custom-nameservers/`, `dns-debugging-resolution/`, `nodelocaldns/`, `cpu-management-policies/`, `topology-manager/`, `configure-feature-gates/`, `kubelet-config-file/`, `securing-a-cluster/`, `cluster-upgrade/`, `migrating-from-dockershim/*`, `verify-signed-artifacts/`
- Pods y contenedores: `tasks/configure-pod-container/` → `assign-memory-resource/`, `assign-cpu-resource/`, `resize-container-resources/`, `security-context/`, `configure-service-account/`, `pull-image-private-registry/`, `configure-liveness-readiness-startup-probes/`, `assign-pods-nodes-using-node-affinity/`, `configure-pod-configmap/`, `user-namespaces/`, `image-volumes/`, `static-pod/`, `translate-compose-kubernetes/`, `enforce-standards-namespace-labels/`, `migrate-from-psp/`, `assign-resources/*` (DRA)
- Debug: `tasks/debug/` → `debug-application/debug-pods/`, `debug-service/`, `debug-statefulset/`, `determine-reason-pod-failure/`, `debug-init-containers/`, `debug-running-pod/`, `get-shell-running-container/`; `debug-cluster/` → `troubleshoot-kubectl/`, `resource-metrics-pipeline/`, `monitor-node-health/`, `crictl/`, `audit/`, `kubectl-node-debug/`
- Objetos: `tasks/manage-kubernetes-objects/` → `declarative-config/`, `kustomization/`, `imperative-command/`, `update-api-object-kubectl-patch/`, `storage-version-migration/`
- Secrets: `tasks/configmap-secret/`
- Inyectar datos: `tasks/inject-data-application/`
- Ejecutar apps: `tasks/run-application/` → `run-stateless-application-deployment/`, `update-deployment-rolling/`, `run-replicated-stateful-application/`, `horizontal-pod-autoscale-walkthrough/`, `configure-pdb/`, `access-api-from-pod/`, `force-delete-stateful-set-pod/`
- Jobs: `tasks/job/` → `automated-tasks-with-cron-jobs/`, `indexed-parallel-processing-static/`, `pod-failure-policy/`
- Acceso a apps: `tasks/access-application-cluster/` → `configure-access-multiple-clusters/`, `port-forward-access-application-cluster/`, `create-external-load-balancer/`, `list-all-running-container-images/`, `web-ui-dashboard/`
- Extender: `tasks/extend-kubernetes/` → `custom-resources/custom-resource-definitions/`, `custom-resource-definition-versioning/`, `configure-aggregation-layer/`, `configure-multiple-schedulers/`, `setup-konnectivity/`
- TLS: `tasks/tls/` → `managing-tls-in-a-cluster/`, `certificate-rotation/`, `manual-rotation-of-ca-certificates/`, `certificate-issue-client-csr/`
- DaemonSets: `tasks/manage-daemon/`; Red: `tasks/network/`; GPUs: `tasks/manage-gpus/scheduling-gpus/`; HugePages: `tasks/manage-hugepages/scheduling-hugepages/`; plugins kubectl: `tasks/extend-kubectl/kubectl-plugins/`

## Tutorials
`tutorials/hello-minikube/`, `tutorials/kubernetes-basics/`, `tutorials/configuration/` (ConfigMaps, sidecars, PV), `tutorials/security/` (PSS cluster/namespace, AppArmor, seccomp), `tutorials/stateless-application/` (canary, guestbook), `tutorials/stateful-application/` (StatefulSet basics, WordPress+MySQL, Cassandra, ZooKeeper), `tutorials/cluster-management/` (kubelet standalone, swap, DRA, admission policies, namespaces), `tutorials/services/` (connect apps, source IP, terminación de endpoints)

## Reference
- Glosario: `reference/glossary/`
- API: `reference/using-api/` → `api-concepts/`, `server-side-apply/`, `client-libraries/`, `cel/`, `deprecation-guide/`, `health-checks/`, `declarative-validation/`
- Control de acceso: `reference/access-authn-authz/` → `authentication/`, `authorization/`, `rbac/`, `node/`, `webhook/`, `admission-controllers/`, `extensible-admission-controllers/`, `validating-admission-policy/`, `mutating-admission-policy/`, `manifest-admission-control/`, `service-accounts-admin/`, `user-impersonation/`, `certificate-signing-requests/`, `kubelet-tls-bootstrapping/`, `bootstrap-tokens/`
- Política de deprecación: `reference/deprecation-policy/`
- Labels/annotations/taints conocidos: `reference/labels-annotations-taints/`
- API de cada recurso: `reference/kubernetes-api/` (por grupo: core, apps, batch, networking, storage, rbac, policy, autoscaling, scheduling, resource, admissionregistration, apiextensions, certificates, coordination, discovery, events, flowcontrol…)
- Instrumentación: `reference/instrumentation/` (métricas, SLIs, PSI, z-pages)
- Seguridad/CVE: `reference/issues-security/` (feed oficial de CVEs)
- Nodo: `reference/node/` (node-labels, kubelet-files, node-status, seccomp, swap-behavior, kernel-version-requirements, what-happens-on-restart)
- Red: `reference/networking/` (ports-and-protocols, virtual-ips, service-protocols)
- kubeadm: `reference/setup-tools/kubeadm/` (init, join, upgrade, config, reset, token, certs, phases, implementation-details)
- kubectl: `reference/kubectl/` → `quick-reference/`, `generated/kubectl_<comando>/`, `jsonpath/`, `conventions/`, `docker-cli-to-kubectl/`, `kuberc/`
- Encodings: `reference/encodings/kyaml/`
- Componentes y feature gates: `reference/command-line-tools-reference/` → `feature-gates/`, `feature-gates-removed/`, `kube-apiserver/`, `kube-controller-manager/`, `kube-scheduler/`, `kube-proxy/`, `kubelet/`
- APIs de configuración: `reference/config-api/` (kubelet-config.v1, kubeadm-config.v1beta4, kube-scheduler-config.v1, kube-proxy-config.v1alpha1, apiserver-audit.v1, apiserver-config, client-authentication.v1, kubeconfig.v1, kuberc, credential provider…)
- APIs externas: `reference/external-api/` (metrics.v1, custom-metrics, external-metrics)
- Scheduling: `reference/scheduling/config/`, `policies/`

## Fuera de /docs
- Releases, EOL, version skew, notas: `https://kubernetes.io/releases/`
- Blog (anuncios de cada release, deprecaciones "sneak peek"): `https://kubernetes.io/blog/`
- Changelog: `https://git.k8s.io/kubernetes/CHANGELOG/`
- Proyectos SIG relacionados: Gateway API `https://gateway-api.sigs.k8s.io`, Kustomize, Cluster API, Kueue, JobSet, Autoscaler (VPA/Cluster Autoscaler), Karpenter, metrics-server, kind, minikube.
- Comunidad: `https://discuss.kubernetes.io`, `https://slack.k8s.io`, `https://k8s.dev`
