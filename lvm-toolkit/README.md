# lvm-toolkit

Skills del equipo LVM (Procom) para trabajar sobre la infraestructura de Docker Swarm, PrestaShop/Wuala y Flexxus.

## Skills incluidas

| Skill | Qué hace |
|---|---|
| `chequeo-compose` | Triage automático de un `docker-compose.yml` que falla al deployar en Swarm/Portainer. |
| `chequeo-logs` | Análisis de logs (Loki/Traefik/Apache/aplicación) para diagnosticar un incidente y producir una respuesta de ticket. |
| `analizar-contexto-wuala` | Analiza el `contexto.md` generado por el recolector de diagnóstico de un sitio Wuala. |
| `prompt-code` | Metodología de dos fases para diseñar una automatización y producir el prompt final para Claude Code. |
| `entrada-tiempo-autotask` | Redacta justificaciones de time entries / tickets de Autotask en el formato del equipo. |

## Instalación

Instalar el archivo `.plugin` desde Claude Code o Cowork. Las skills quedan disponibles automáticamente según el contexto de la conversación — no requieren invocación manual salvo que su descripción indique lo contrario.

## Mantenimiento

`contexto-infra-procom` es de contenido compartido: cuando el equipo detecte un dato de infra nuevo o desactualizado (IP, cuenta, convención), corresponde actualizar esa skill y republicar una nueva versión del plugin.
