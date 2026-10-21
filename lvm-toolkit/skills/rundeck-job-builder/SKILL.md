---
name: rundeck-job-builder
description: Convierte una automatización o script existente de Martín (alta-stack-wuala, alta-stack-flexxus, truncado de caché, sync KONG/NPM, etc.) en una definición de job de Rundeck lista para importar (YAML/XML), pensada para disparo vía la web-app propia que consume la API REST de Rundeck. Usar cuando Martín pida "armá el job de Rundeck para X", quiera exponer un script como job, o esté trabajando en la web-app de automatizaciones (ui-automatizaciones-rundeck) y necesite el lado de definición de jobs.
---

# Rundeck job builder

Genera la definición de job de Rundeck (formato YAML de exportación, importable vía API o UI) para
una automatización existente, más las notas de integración para que la web-app propia
(`ui-automatizaciones-rundeck`) pueda dispararla.

## Qué necesito de Martín antes de generar el job

Si no está claro en la conversación, preguntar:

1. **Script/comando exacto** a ejecutar y en qué nodo(s) corre (ver `contexto-infra-procom` para
   nombres de nodos conocidos)
2. **Parámetros** que la automatización recibe hoy (flags de CLI, variables de entorno) — se
   convierten en Options del job
3. **Node filter**: ¿corre en un nodo fijo (launcher) o se despacha a un nodo target elegido por
   parámetro?
4. **Modo destructivo o no**: si el script tiene `--dry-run`, exponerlo como Option boolean con
   default `true` — patrón que Martín ya usa (truncado de caché)
5. **Grupo/proyecto de Rundeck** donde va a vivir (si no lo sabe, dejar placeholder `<project>` y
   avisar)
6. **Access control**: ¿quién puede correrlo? Anotar como comentario en el job, la implementación
   real de ACL queda fuera de este skill salvo que Martín pida el policy YAML también.

## Estructura de la definición de job

Generar en formato YAML de exportación de Rundeck (`rd jobs load -f job.yaml -F yaml`, o API
`POST /project/[project]/jobs/import`):

```yaml
- name: <nombre-descriptivo-kebab-case>
  group: <grupo, p. ej. "automatizaciones-procom">
  description: <qué hace, una línea>
  loglevel: INFO
  sequence:
    keepgoing: false
    strategy: node-first
    commands:
      - exec: <comando o script real>
  nodefilters:
    filter: "<criterio de selección de nodo, o 'name: launcher-host' si es fijo>"
  options:
    - name: <param1>
      description: <qué es>
      required: true
    - name: dry_run
      description: "Si es true, no ejecuta cambios reales"
      type: boolean
      default: 'true'
      required: false
  notification: {}
```

Ajustar `commands` según si el script corre local en el nodo de Rundeck o hace SSH remoto (patrón
launcher+worker que Martín ya usa en varias automatizaciones — el job en Rundeck dispara el launcher,
el launcher hace SSH al nodo real).

## Integración con la web-app propia

Recordar que el objetivo final es que la web-app de Martín dispare esto vía la API REST de Rundeck
(`POST /job/[ID]/executions`), no que se corra manualmente desde la UI de Rundeck. Al entregar el
job, agregar una nota corta con:

- El endpoint de ejecución que la web-app va a necesitar
- Qué Options son obligatorias para el POST
- Si conviene usar polling de `/execution/[ID]/output` o SSE del lado de la web-app para mostrar
  progreso en vivo (Martín todavía no cerró esta decisión — si la conversación no lo aclara, ofrecer
  ambas opciones con el tradeoff, no elegir por él)

## Output

Entregar el YAML como bloque de código en el chat (no como archivo, salvo que Martín pida
descargarlo o esté armando varios jobs de una — ahí sí, un `.yaml` por job o un solo archivo
multi-job si lo pide así).
