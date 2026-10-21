# Services, balanceo y redes

## Contenido
1. Modelo de red de Kubernetes
2. Service: tipos y campos clave
3. EndpointSlices y políticas de tráfico
4. DNS
5. Ingress
6. Gateway API
7. NetworkPolicy
8. kube-proxy, IPs virtuales, dual-stack, rangos de Service

---

## 1. Modelo de red

- Cada Pod tiene su propia IP; todos los pods pueden hablar con todos sin NAT (salvo que una NetworkPolicy lo impida).
- Contenedores de un mismo pod comparten IP y se hablan por `localhost`.
- Lo implementa un **plugin CNI** (Calico, Cilium, Flannel, Antrea, Weave, kube-router, los de cada cloud…). Sin CNI, los nodos quedan `NotReady` y CoreDNS en Pending.
- Tres rangos que no deben solaparse entre sí ni con la red física: **red de nodos**, **Pod CIDR** (`--pod-network-cidr` en kubeadm) y **Service CIDR** (`--service-cidr`, 10.96.0.0/12 por defecto en kubeadm).
- Puertos de referencia: apiserver 6443, etcd 2379-2380, kubelet 10250, scheduler 10259, controller-manager 10257, NodePort 30000-32767.

## 2. Service

Abstracción estable (IP virtual + nombre DNS) para un conjunto de pods elegido por `selector`.

| Tipo | Qué hace | Uso |
|---|---|---|
| `ClusterIP` (defecto) | IP virtual interna | Comunicación dentro del cluster |
| `NodePort` | ClusterIP + puerto en cada nodo (30000-32767) | Entornos sin LB, pruebas, detrás de un LB externo propio |
| `LoadBalancer` | NodePort + LB externo provisto por el cloud-controller-manager o MetalLB/kube-vip en bare metal | Exponer TCP/UDP a internet |
| `ExternalName` | CNAME DNS a un nombre externo (sin proxy) | Alias a servicios fuera del cluster |
| Headless (`clusterIP: None`) | Sin IP virtual; DNS devuelve las IPs de los pods | StatefulSets, descubrimiento directo |

Campos clave:
- `ports[].port` (del Service), `targetPort` (del contenedor; número o **nombre** del puerto, preferible), `nodePort`, `protocol` (TCP/UDP/SCTP), `appProtocol`.
- Puertos con nombre son obligatorios cuando hay más de un puerto.
- `sessionAffinity: ClientIP` (+ `timeoutSeconds`).
- `externalTrafficPolicy: Local` (preserva la IP de origen del cliente y evita un salto extra, pero solo nodos con pods reciben tráfico y el balanceo puede quedar desigual) vs `Cluster` (por defecto).
- `internalTrafficPolicy: Local` para que el tráfico interno vaya solo a pods del mismo nodo (útil con DaemonSets).
- `loadBalancerClass` para elegir implementación; `loadBalancerSourceRanges` para restringir IPs.
- `trafficDistribution: PreferClose` (o variantes más nuevas como `PreferSameZone`/`PreferSameNode`, según versión) para preferir endpoints cercanos.
- Service sin selector + EndpointSlice manual: apuntar a backends externos con IP fija.
- `publishNotReadyAddresses: true` en headless Services de StatefulSets que necesitan descubrirse antes de estar Ready.

## 3. EndpointSlices

- Reemplazan a `Endpoints` (legado, con límite de 1000 direcciones). Hasta 100 endpoints por slice por defecto.
- Cada endpoint tiene condiciones `ready`, `serving`, `terminating`, más `nodeName` y `zone`.
- Ver: `kubectl get endpointslices -l kubernetes.io/service-name=web`.
- **Topology Aware Routing** (`service.kubernetes.io/topology-mode: Auto`) o `trafficDistribution` para mantener tráfico en la zona y reducir costos/latencia.

## 4. DNS

- CoreDNS como Service `kube-dns` en `kube-system`.
- Registros:
  - Service: `<svc>.<ns>.svc.cluster.local` → ClusterIP (A/AAAA). Headless → IPs de los pods.
  - SRV: `_<puerto>._<proto>.<svc>.<ns>.svc.cluster.local`.
  - Pod de StatefulSet: `<pod>.<svc-headless>.<ns>.svc.cluster.local`.
- `dnsPolicy`: `ClusterFirst` (defecto), `Default` (hereda del nodo), `ClusterFirstWithHostNet` (pods con `hostNetwork`), `None` (+ `dnsConfig`).
- `ndots:5` por defecto: nombres con menos de 5 puntos prueban primero los dominios de búsqueda → muchas consultas extra a nombres externos. Optimización: usar FQDN con punto final (`api.example.com.`) o bajar `ndots` vía `dnsConfig.options`.
- Personalizar: ConfigMap `coredns` en `kube-system` (stub domains, forward). **NodeLocal DNSCache** reduce latencia y problemas de conntrack con UDP.
- Depurar: ver troubleshooting.md, sección DNS.

## 5. Ingress

- Objeto `networking.k8s.io/v1` que define reglas HTTP(S) por host y ruta hacia Services. **No hace nada sin un Ingress controller** instalado (ingress-nginx, Traefik, HAProxy, Contour, los de cada cloud…).
- `spec.ingressClassName` elige el controlador (IngressClass); se puede marcar una clase como default con la anotación `ingressclass.kubernetes.io/is-default-class: "true"`.
- `pathType`: `Prefix`, `Exact`, `ImplementationSpecific`.
- TLS: `spec.tls[].secretName` con un Secret `kubernetes.io/tls` (típicamente gestionado por cert-manager).
- Ingress está **congelado** (no recibe nuevas features); para capacidades avanzadas cada controlador usa anotaciones no portables. La evolución es Gateway API.
- Nota: el proyecto comunitario ingress-nginx anunció su retiro (fin de mantenimiento en marzo de 2026); si el usuario lo usa, recomienda migrar a Gateway API o a otro controlador y verifica el estado actual.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
spec:
  ingressClassName: nginx
  tls:
  - hosts: [app.example.com]
    secretName: app-example-tls
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              name: http
```

## 6. Gateway API

API orientada a roles (proyecto oficial de SIG Network, se instala como CRDs `gateway.networking.k8s.io`; no viene incluida en el core):
- **GatewayClass** (proveedor de infraestructura): qué implementación (Envoy Gateway, Istio, Cilium, NGINX Gateway Fabric, Kong, Traefik, los de cada cloud…).
- **Gateway** (operador del cluster): listeners (puerto, protocolo, hostname, TLS).
- **Routes** (desarrolladores): `HTTPRoute`, `GRPCRoute` (GA), y `TLSRoute`, `TCPRoute`, `UDPRoute` (experimentales según versión).
- Ventajas sobre Ingress: tráfico ponderado (canary), matching por headers/método/query, reescrituras y redirecciones estándar, delegación entre namespaces con `ReferenceGrant`, sin anotaciones propietarias.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: web
spec:
  parentRefs:
  - name: public-gw
    namespace: infra
  hostnames: ["app.example.com"]
  rules:
  - matches:
    - path: {type: PathPrefix, value: /}
    backendRefs:
    - name: web-stable
      port: 80
      weight: 90
    - name: web-canary
      port: 80
      weight: 10
```

Verifica la versión del bundle de CRDs de Gateway API y qué features soporta la implementación (perfiles de conformidad) en gateway-api.sigs.k8s.io.

## 7. NetworkPolicy

- `networking.k8s.io/v1`. **Requiere un CNI que las implemente**; si no, se aceptan y se ignoran en silencio.
- Por defecto todo está permitido. En cuanto una política selecciona un pod para `Ingress` (o `Egress`), solo se permite lo que alguna política autorice en esa dirección (las políticas son aditivas, no hay "deny" explícito).
- Selectores: `podSelector`, `namespaceSelector` (usa la label automática `kubernetes.io/metadata.name`), `ipBlock` (con `except`).
- **Trampa clásica de YAML**: dentro de `from`, dos elementos separados (`- namespaceSelector` y `- podSelector`) son OR; ambos en el mismo elemento son AND.
- Al aplicar default-deny de egress, **permite DNS** (UDP y TCP 53 hacia kube-dns) o nada resolverá nombres.
- No filtran tráfico del propio nodo de forma consistente ni ofrecen L7: para eso, políticas propias del CNI (CiliumNetworkPolicy, Calico GlobalNetworkPolicy) o un service mesh. Existe además la iniciativa AdminNetworkPolicy (SIG Network) para políticas a nivel cluster.
- Ver `assets/networkpolicy-base.yaml`.

## 8. kube-proxy, IPs virtuales y rangos

- Modos de kube-proxy: `iptables` (por defecto en Linux), `ipvs` (en retirada a favor de nftables), `nftables` (moderno, mejor rendimiento en clusters grandes), `kernelspace` (Windows).
- Algunos CNI reemplazan kube-proxy con eBPF (Cilium).
- **Dual-stack IPv4/IPv6**: `ipFamilyPolicy` (`SingleStack`, `PreferDualStack`, `RequireDualStack`) e `ipFamilies` en el Service; requiere configurar CIDRs dobles en el cluster.
- **Ampliar rangos de Service sin reconstruir el cluster**: objetos `ServiceCIDR` e `IPAddress` (`networking.k8s.io/v1`). Ver tareas "Extend Service IP Ranges" y "Kubernetes Default ServiceCIDR Reconfiguration".
- `hostNetwork: true` / `hostPort`: evítalos salvo agentes de sistema; rompen el aislamiento y limitan el scheduling.
- `hostAliases` agrega entradas a `/etc/hosts` del pod.
- Source IP: con `externalTrafficPolicy: Cluster` se pierde la IP del cliente (SNAT); usa `Local` o PROXY protocol en el LB.
