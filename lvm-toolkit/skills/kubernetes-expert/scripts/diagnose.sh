#!/usr/bin/env bash
# diagnose.sh — Recolecta evidencia de diagnóstico de Kubernetes. SOLO LECTURA (no modifica nada).
#
# Uso:
#   diagnose.sh pod <nombre> [-n <namespace>]
#   diagnose.sh deploy <nombre> [-n <namespace>]
#   diagnose.sh sts <nombre> [-n <namespace>]
#   diagnose.sh svc <nombre> [-n <namespace>]
#   diagnose.sh ns <namespace>
#   diagnose.sh node <nombre>
#   diagnose.sh cluster
#
# Variables: KUBECTL (por defecto "kubectl"), KUBECONFIG/--context vía KUBECTL="kubectl --context x".

set -uo pipefail
K="${KUBECTL:-kubectl}"
KIND="${1:-}"; NAME="${2:-}"; shift 2 2>/dev/null || true
NS_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace) NS_ARGS=(-n "$2"); shift 2 ;;
    *) shift ;;
  esac
done

h() { printf '\n========== %s ==========\n' "$*"; }
run() { echo "+ $*"; "$@" 2>&1 || true; }

usage() { sed -n '2,14p' "$0"; exit 1; }
[[ -z "$KIND" ]] && usage

case "$KIND" in
  pod)
    [[ -z "$NAME" ]] && usage
    h "Estado"; run $K get pod "$NAME" "${NS_ARGS[@]}" -o wide
    h "Contenedores: estado, último fallo y exit code"
    run $K get pod "$NAME" "${NS_ARGS[@]}" -o jsonpath='{range .status.initContainerStatuses[*]}init/{.name}{"\tready="}{.ready}{"\trestarts="}{.restartCount}{"\twaiting="}{.state.waiting.reason}{"\tlast="}{.lastState.terminated.reason}{"("}{.lastState.terminated.exitCode}{")"}{"\n"}{end}{range .status.containerStatuses[*]}{.name}{"\tready="}{.ready}{"\trestarts="}{.restartCount}{"\twaiting="}{.state.waiting.reason}{"\tlast="}{.lastState.terminated.reason}{"("}{.lastState.terminated.exitCode}{")"}{"\n"}{end}'
    h "QoS y nodo"; run $K get pod "$NAME" "${NS_ARGS[@]}" -o jsonpath='qos={.status.qosClass} node={.spec.nodeName} phase={.status.phase} reason={.status.reason}{"\n"}'
    h "describe"; run $K describe pod "$NAME" "${NS_ARGS[@]}"
    for c in $($K get pod "$NAME" "${NS_ARGS[@]}" -o jsonpath='{.spec.initContainers[*].name} {.spec.containers[*].name}' 2>/dev/null); do
      h "Logs $c (últimas 80 líneas)"; run $K logs "$NAME" "${NS_ARGS[@]}" -c "$c" --tail=80
      h "Logs previos $c"; run $K logs "$NAME" "${NS_ARGS[@]}" -c "$c" --previous --tail=80
    done
    h "Eventos del pod"; run $K events "${NS_ARGS[@]}" --for "pod/$NAME"
    h "Uso de recursos"; run $K top pod "$NAME" "${NS_ARGS[@]}" --containers
    ;;
  deploy|deployment|sts|statefulset|ds|daemonset)
    [[ -z "$NAME" ]] && usage
    case "$KIND" in deploy|deployment) R=deployment;; sts|statefulset) R=statefulset;; *) R=daemonset;; esac
    h "Estado"; run $K get "$R" "$NAME" "${NS_ARGS[@]}" -o wide
    h "describe"; run $K describe "$R" "$NAME" "${NS_ARGS[@]}"
    h "Rollout"; run $K rollout status "$R/$NAME" "${NS_ARGS[@]}" --timeout=5s
    run $K rollout history "$R/$NAME" "${NS_ARGS[@]}"
    SEL=$($K get "$R" "$NAME" "${NS_ARGS[@]}" -o jsonpath='{range $k,$v := .spec.selector.matchLabels}{$k}={$v},{end}' 2>/dev/null | sed 's/,$//')
    if [[ -n "$SEL" ]]; then
      [[ "$R" == deployment ]] && { h "ReplicaSets (eventos de creación: cuota, PSA, webhooks)"; run $K get rs "${NS_ARGS[@]}" -l "$SEL"; for rs in $($K get rs "${NS_ARGS[@]}" -l "$SEL" -o name 2>/dev/null | tail -2); do run $K describe "$rs" "${NS_ARGS[@]}"; done; }
      h "Pods ($SEL)"; run $K get pods "${NS_ARGS[@]}" -l "$SEL" -o wide
    fi
    h "HPA / PDB del namespace"; run $K get hpa,pdb "${NS_ARGS[@]}"
    h "Eventos Warning recientes"; run $K get events "${NS_ARGS[@]}" --field-selector type=Warning --sort-by=.lastTimestamp
    ;;
  svc|service)
    [[ -z "$NAME" ]] && usage
    h "Service"; run $K get svc "$NAME" "${NS_ARGS[@]}" -o wide
    run $K get svc "$NAME" "${NS_ARGS[@]}" -o jsonpath='selector={.spec.selector}{"\n"}ports={.spec.ports}{"\n"}'
    h "EndpointSlices (vacío = selector no coincide o pods no Ready)"
    run $K get endpointslices "${NS_ARGS[@]}" -l "kubernetes.io/service-name=$NAME" -o wide
    SEL=$($K get svc "$NAME" "${NS_ARGS[@]}" -o jsonpath='{range $k,$v := .spec.selector}{$k}={$v},{end}' 2>/dev/null | sed 's/,$//')
    [[ -n "$SEL" ]] && { h "Pods que coinciden con el selector"; run $K get pods "${NS_ARGS[@]}" -l "$SEL" -o wide; }
    h "NetworkPolicies del namespace"; run $K get networkpolicy "${NS_ARGS[@]}"
    h "Ingress / HTTPRoutes que podrían referenciarlo"; run $K get ingress "${NS_ARGS[@]}"; run $K get httproutes "${NS_ARGS[@]}"
    h "describe"; run $K describe svc "$NAME" "${NS_ARGS[@]}"
    ;;
  ns|namespace)
    N="${NAME:-default}"
    h "Namespace"; run $K get ns "$N" -o yaml
    h "Workloads"; run $K get deploy,sts,ds,job,cronjob,hpa,pdb -n "$N"
    h "Pods no Running/Succeeded"; run $K get pods -n "$N" --field-selector=status.phase!=Running,status.phase!=Succeeded -o wide
    h "Pods con reinicios"; run $K get pods -n "$N" --sort-by=.status.containerStatuses[0].restartCount
    h "Servicios / PVC"; run $K get svc,pvc -n "$N"
    h "Cuotas y límites"; run $K describe quota -n "$N"; run $K get limitrange -n "$N"
    h "Eventos Warning"; run $K get events -n "$N" --field-selector type=Warning --sort-by=.lastTimestamp
    ;;
  node)
    [[ -z "$NAME" ]] && usage
    h "Nodo"; run $K get node "$NAME" -o wide
    h "describe (Conditions, Taints, Allocated resources)"; run $K describe node "$NAME"
    h "Pods en el nodo"; run $K get pods -A --field-selector "spec.nodeName=$NAME" -o wide
    h "Uso"; run $K top node "$NAME"
    echo; echo "Siguiente paso (en el nodo o con 'kubectl debug node/$NAME -it --image=busybox:1.36'):"
    echo "  systemctl status kubelet containerd; journalctl -u kubelet --since '15 min ago'; crictl ps -a; df -h"
    ;;
  cluster)
    h "Versión"; run $K version
    h "Salud del API server"; run $K get --raw='/readyz?verbose'
    h "Nodos"; run $K get nodes -o wide
    h "Uso de nodos"; run $K top nodes
    h "Sistema (kube-system)"; run $K get pods -n kube-system -o wide
    h "APIServices no disponibles"; $K get apiservices 2>/dev/null | awk 'NR==1 || $3 ~ /False/'
    h "Pods problemáticos en todo el cluster"; run $K get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
    h "Eventos Warning recientes"; $K get events -A --field-selector type=Warning --sort-by=.lastTimestamp 2>&1 | tail -40
    ;;
  *) usage ;;
esac
