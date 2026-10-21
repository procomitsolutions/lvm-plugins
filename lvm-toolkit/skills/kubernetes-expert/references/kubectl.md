# kubectl: chuleta

## Contenido
1. Configuración, contextos y autocompletado
2. Consultar recursos (get, describe, explain, salidas, JSONPath)
3. Crear y aplicar (imperativo rápido, declarativo, diff, dry-run)
4. Actualizar y parchear
5. Escalar, rollouts, borrar
6. Interactuar con pods (logs, exec, cp, port-forward, debug)
7. Nodos y cluster
8. kuberc, plugins y trucos

---

## 1. Configuración

```bash
source <(kubectl completion bash)          # zsh: source <(kubectl completion zsh)
alias k=kubectl; complete -o default -F __start_kubectl k
kubectl config view --minify               # config del contexto actual
kubectl config get-contexts
kubectl config use-context <ctx>
kubectl config set-context --current --namespace=<ns>
KUBECONFIG=~/.kube/a:~/.kube/b kubectl config view --flatten > ~/.kube/merged
kubectl version
kubectl cluster-info
kubectl auth whoami
```

## 2. Consultar

```bash
kubectl get pods -A -o wide
kubectl get pods -l app.kubernetes.io/name=web --show-labels
kubectl get pods --field-selector=status.phase!=Running -A
kubectl get pods --sort-by=.status.containerStatuses[0].restartCount
kubectl get all -n <ns>                    # (no incluye todo: faltan ConfigMaps, Secrets, PVC, Ingress…)
kubectl get deploy,svc,ingress,pvc -n <ns>
kubectl get pods -w                        # watch
kubectl describe <tipo>/<nombre>
kubectl explain deployment.spec.strategy --recursive
kubectl api-resources [--namespaced=true] [-o wide]
kubectl get <tipo> <nombre> -o yaml|json|kyaml|name|wide
kubectl get pods -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,IMAGE:.spec.containers[*].image
```

**JSONPath**:
```bash
kubectl get pods -o jsonpath='{.items[*].metadata.name}'
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}'
kubectl get secret db -o jsonpath='{.data.password}' | base64 -d
kubectl get pods -A -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' | sort | uniq -c   # imágenes en uso
```
Para filtros complejos, `-o json | jq`.

## 3. Crear y aplicar

**Generar YAML rápido** (clave en exámenes):
```bash
kubectl create deployment web --image=nginx:1.27 --replicas=3 --port=80 --dry-run=client -o yaml > deploy.yaml
kubectl expose deployment web --port=80 --target-port=80 --type=ClusterIP --dry-run=client -o yaml
kubectl run tmp --image=busybox:1.36 --restart=Never --dry-run=client -o yaml -- sleep 3600
kubectl create job once --image=busybox:1.36 -- echo hola
kubectl create cronjob nightly --image=busybox:1.36 --schedule="0 3 * * *" -- /bin/sh -c 'date'
kubectl create configmap cfg --from-literal=k=v --from-file=app.properties
kubectl create secret generic db --from-literal=password='s3cr3t'
kubectl create secret tls web-tls --cert=tls.crt --key=tls.key
kubectl create serviceaccount builder
kubectl create role pod-reader --verb=get,list,watch --resource=pods
kubectl create rolebinding read-pods --role=pod-reader --serviceaccount=app:builder
kubectl create ingress web --class=nginx --rule="app.example.com/*=web:80"
kubectl create quota q --hard=pods=20,requests.cpu=4,requests.memory=8Gi
kubectl create pdb web --selector=app=web --min-available=1
kubectl create token builder --duration=1h
```

**Declarativo**:
```bash
kubectl apply -f dir/ [-R]
kubectl apply -k overlays/prod             # Kustomize
kubectl apply --server-side -f x.yaml [--force-conflicts]
kubectl diff -f dir/
kubectl apply -f x.yaml --dry-run=server   # valida con admission sin persistir
kubectl apply --prune -l app=web -f dir/   # (prune con cuidado; existe ApplySet como mecanismo más nuevo)
kubectl kustomize overlays/prod            # renderizar sin aplicar
```

## 4. Actualizar y parchear

```bash
kubectl set image deploy/web app=nginx:1.27.2
kubectl set env deploy/web LOG_LEVEL=debug
kubectl set env deploy/web --from=configmap/cfg
kubectl set resources deploy/web -c app --requests=cpu=100m,memory=128Mi --limits=memory=256Mi
kubectl label pod x tier=frontend [--overwrite]; kubectl label pod x tier-
kubectl annotate deploy web owner=team-a
kubectl edit deploy/web
kubectl patch deploy web -p '{"spec":{"replicas":3}}'                                   # strategic merge (defecto)
kubectl patch deploy web --type=merge -p '{"metadata":{"labels":{"env":"prod"}}}'
kubectl patch deploy web --type=json -p '[{"op":"replace","path":"/spec/template/spec/containers/0/image","value":"nginx:1.27"}]'
kubectl patch pod x --subresource resize -p '{"spec":{"containers":[{"name":"app","resources":{"requests":{"cpu":"500m"}}}]}}'
kubectl replace --force -f x.yaml          # borra y recrea (para campos inmutables)
```
Strategic merge patch entiende listas con clave (`containers` por `name`); JSON merge patch reemplaza listas enteras; JSON patch usa operaciones explícitas.

## 5. Escalar, rollouts y borrar

```bash
kubectl scale deploy/web --replicas=5
kubectl scale --current-replicas=2 --replicas=3 deploy/web
kubectl autoscale deploy web --min=2 --max=10 --cpu=70%    # flags según versión de kubectl: --cpu-percent en versiones viejas
kubectl rollout status|history|undo|pause|resume|restart deploy/web
kubectl delete -f x.yaml
kubectl delete pod x --grace-period=0 --force          # último recurso
kubectl delete pods -l app=web --cascade=foreground
kubectl delete pod --field-selector=status.phase=Failed -A   # limpiar Evicted/Failed
kubectl wait --for=condition=Available deploy/web --timeout=120s
kubectl wait --for=delete pod/x --timeout=60s
kubectl wait --for=jsonpath='{.status.phase}'=Running pod/x
```

## 6. Interactuar con pods

```bash
kubectl logs pod/x [-c app] [-f] [--since=1h] [--tail=200] [--timestamps] [--previous]
kubectl logs deploy/web --all-containers --prefix
kubectl logs -l app=web --max-log-requests=10
kubectl exec -it pod/x -c app -- sh
kubectl cp ns/x:/var/log/app.log ./app.log
kubectl port-forward svc/web 8080:80 [--address 0.0.0.0]
kubectl attach -it pod/x
kubectl debug -it pod/x --image=busybox:1.36 --target=app
kubectl debug pod/x -it --copy-to=x-debug --container=app -- sh
kubectl debug node/n1 -it --image=busybox:1.36
kubectl top pod --containers -A --sort-by=memory
kubectl proxy --port=8001        # API en http://localhost:8001/api/v1/...
```

## 7. Nodos y cluster

```bash
kubectl get nodes -o wide --show-labels
kubectl describe node n1
kubectl top node
kubectl cordon|uncordon n1
kubectl drain n1 --ignore-daemonsets --delete-emptydir-data
kubectl taint nodes n1 key=value:NoSchedule[-]
kubectl label nodes n1 disktype=ssd
kubectl get --raw='/readyz?verbose'
kubectl get --raw /apis/metrics.k8s.io/v1/nodes
kubectl cluster-info dump --output-directory=/tmp/dump
kubectl auth can-i --list
kubectl get events -A --field-selector type=Warning --sort-by=.lastTimestamp
```

## 8. kuberc, plugins y trucos

- **kuberc** (`~/.kube/kuberc`, `KUBERC`): preferencias del usuario separadas del kubeconfig: alias propios y flags por defecto (p. ej. `--server-side` en apply, confirmación interactiva en delete). Gestionar con `kubectl kuberc view|set`. Verifica la versión de su API (v1beta1 en versiones recientes).
- **Plugins**: cualquier ejecutable `kubectl-<nombre>` en el PATH; gestor `krew`. Útiles: `ctx`/`ns` (kubectx/kubens), `neat`, `tree`, `stern` (logs multi-pod), `view-secret`, `who-can`, `node-shell`, `convert` (oficial, convierte apiVersions).
- `kubectl get pods -v=6..9` muestra las requests HTTP (útil para entender la API o depurar permisos).
- `--request-timeout`, `--chunk-size` para listas enormes.
- `kubectl events` (comando dedicado) ordena y filtra mejor que `get events`.
- Convenciones oficiales: en scripts usa recursos con grupo/versión explícitos (`deployments.v1.apps`), `-o name`/`jsonpath` en vez de parsear la salida por defecto, y no dependas de generadores imperativos.
- **kubectl para usuarios de Docker**: `docker run` → `kubectl run`/`create deployment`; `docker ps` → `kubectl get pods`; `docker logs` → `kubectl logs`; `docker exec` → `kubectl exec`.
