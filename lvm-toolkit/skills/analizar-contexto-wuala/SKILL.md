---
name: analizar-contexto-wuala
description: >-
  Analiza el contexto.md (y los archivos crudos que lo acompañan) que genera
  la herramienta wuala_diagnostico/recolector para diagnosticar un incidente
  en un sitio Wuala. Usá esta skill cuando el usuario pegue o adjunte un
  contexto.md de esa carpeta (./contextos/[stack]/[fecha]/), pida "analizá
  este incidente", "qué pasó con [sitio]", "revisá este diagnóstico", o
  mencione la carpeta contextos/ generada por `python -m recolector.cli`.
  También aplica si solo tiene el path a la carpeta de salida y todavía no
  pegó el contenido — en ese caso, leé contexto.md desde ahí primero.
---

# Analizar un contexto.md de wuala_diagnostico

`contexto.md` es un **destilado**, no la fuente de verdad completa. Lo generó
`recolector` (ver `wuala/diagnostico/` en el repo, o `C:\Scripts\wuala_diagnostico`)
recolectando Portainer + InfluxDB + Loki + Cloudflare y resumiendo lo relevante
en 9 secciones. Al lado, en la misma carpeta, quedan los archivos crudos que
lo respaldan. Tu trabajo es leer `contexto.md` primero, y solo bajar a un
archivo crudo cuando el destilado no alcance para responder la pregunta —
nunca al revés.

## Paso 1 — Leer contexto.md completo

Antes de pedir nada más, leé las 9 secciones (identidad del stack, ventana
consultada, estado de las fuentes, contenedores, restarts, Cloudflare, límites
de recursos, destilado de logs, limitaciones). La mayoría de las preguntas de
diagnóstico se responden con esto solo.

Prestá atención especial a:
- **Sección 3 (estado de las fuentes):** si una fuente dice `fallo: ...` o
  `vacio: ...`, cualquier conclusión de esa sección es débil o inexistente —
  decilo explícitamente en vez de tratar el silencio como "todo normal".
- **Sección 9 (limitaciones):** siempre va a decir que no hay tabla de
  top-IPs (las IPs del access log son la red overlay de Traefik, no el
  visitante). Nunca intentes reconstruir esa tabla desde `logs.ndjson` — el
  dato no está ahí tampoco.

## Paso 2 — Saber qué hay en cada archivo crudo

Todos viven junto a `contexto.md`, en `./contextos/<stack>/<fecha>/`:

| Archivo | Qué tiene | Cuándo pedirlo/leerlo |
|---|---|---|
| `portainer.json` | Stack completo: todas las env vars (no solo las "interesantes" que filtra el reporte), compose completo, servicios/tasks crudos, git origin | Falta una env var puntual que no aparece en la sección 7, o hace falta el detalle de tasks/nodos más allá del resumen de restarts |
| `compose.yml` | El compose desplegado tal cual, texto plano | Se necesita ver un servicio completo (ej. volúmenes, healthchecks) que el reporte no extrae (el reporte solo saca `deploy.resources`) |
| `metricas.json` | Series completas de InfluxDB (ventana actual + referencia del día anterior), point-by-point, no solo el peak/mean agregado de la sección 4 | Hace falta ver **cuándo dentro de la ventana** pasó el pico, no solo que hubo un pico — o correlacionar un momento puntual entre métricas y logs |
| `logs.ndjson` | Una línea JSON por entrada de log: timestamp ART y UTC, labels del stream, línea cruda completa | El error agrupado de la sección 8 no trae el mensaje completo (las firmas normalizan pids/números), o hace falta ver el tráfico real alrededor de una ventana de tasa anómala marcada en la sección 8 |
| `cloudflare.json` | Igual al resumen de la sección 6, casi no agrega nada | Rara vez hace falta — la sección 6 ya es el dato completo |

## Paso 3 — Pedir el archivo correcto, no todos

Si necesitás bajar a un crudo, pedí (o leé) **solo el que corresponde** a la
pregunta, y decí por qué ese y no otro — no proceses `logs.ndjson` entero para
algo que ya está en la sección 8. Ejemplos de cuándo sí vale la pena:

- "¿Qué decía exactamente el error de `hookDisplayProductButtons`?" → `logs.ndjson`,
  filtrando por el módulo/mensaje de la firma en cuestión.
- "¿El pico de CPU fue justo antes o después del restart?" → `metricas.json`
  (serie completa) cruzado con la sección 5 (restarts) de `contexto.md`.
- "¿Qué límite de memoria tiene el contenedor de DB?" → ya está en la sección 7;
  si no aparece ahí, recién entonces `compose.yml`.

## Paso 4 — Nunca recalcules lo que el destilado ya calculó

Status codes, top endpoints, clasificación de user-agents, ratio de errores,
picos/medias por servicio: todo eso ya está en `contexto.md`. Si lo volvés a
calcular desde `logs.ndjson`/`metricas.json` a mano corrés el riesgo de no
replicar exactamente la lógica de `destilado/` (ventanas, exclusión de sftp/
filebrowser, normalización de firmas) y quedar en contradicción con el reporte.

## Si todavía no se generó el contexto.md

Esta skill no corre el recolector — si el usuario pide diagnosticar un sitio
y no hay carpeta `contextos/` con datos recientes, decíselo y sugerí correr:

```bash
python -m recolector.cli <sitio> --last 24h
```

desde `wuala/diagnostico/` (o `C:\Scripts\wuala_diagnostico` si está corriendo
desde la copia de trabajo).

### Connections
- Ver `wuala/docs/documentacion-diagnostico.md` en el repo (o la nota
  `Documentacion wuala_diagnostico` del vault) para el detalle completo de
  cómo se arma cada sección y cada archivo crudo.
