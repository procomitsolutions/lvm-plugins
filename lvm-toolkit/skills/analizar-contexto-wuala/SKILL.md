---
name: analizar-contexto-wuala
description: >-
  Analiza el contexto.md (y los archivos crudos que lo acompañan) que genera
  la herramienta wuala_diagnostico/recolector para diagnosticar un incidente
  en un sitio Wuala, consulta casos previos con la misma firma, y al cerrar
  el incidente emite un registro de caso estructurado para la base de casos
  (RAG). Usá esta skill cuando el usuario pegue o adjunte un contexto.md de
  esa carpeta (./contextos/[stack]/[fecha]/), pida "analizá este incidente",
  "qué pasó con [sitio]", "revisá este diagnóstico", mencione la carpeta
  contextos/ generada por `python -m recolector.cli`, o diga que un caso
  Wuala quedó resuelto / pida "cerrá el caso", "registralo", "armá el registro".
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

Las restricciones de qué se puede recomendar (no subir recursos como primera
opción, qué capa es de LVM/Procom y cuál de Wuala) están en
`contexto-infra-procom`. Leelas antes de proponer cambios.

## Paso 1 — Leer contexto.md completo

Antes de pedir nada más, leé las 9 secciones (identidad del stack, ventana
consultada, estado de las fuentes, contenedores, restarts, Cloudflare, límites
de recursos, destilado de logs, limitaciones). La mayoría de las preguntas de
diagnóstico se responden con esto solo.

Prestá atención especial a:
- **Sección 3 (estado de las fuentes):** si una fuente dice `fallo: ...` o
  `vacio: ...`, cualquier conclusión de esa sección es débil o inexistente —
  decilo explícitamente en vez de tratar el silencio como "todo normal".
- **Sección 9 (limitaciones):** puede afirmar que no hay tabla de top-IPs
  porque las IPs del access log serían la red overlay de Traefik. **Eso no
  vale para todos los stacks**: en varios (verificado en hov) el access log
  trae la IP pública real del visitante. Comprobalo mirando unas líneas de
  `logs.ndjson` antes de aceptar la limitación.
- **Ventanas de silencio (sección 8):** Apache loguea al *completar* el
  request, así que el inicio real de un corte puede ser anterior a la
  ventana, nunca posterior. Un hueco sin ninguna línea de ningún tipo (ni
  access, ni error, ni DB) y sin ráfaga de recuperación suele ser un hueco de
  ingesta de Loki, no una caída.

## Paso 2 — Buscar casos previos con la misma firma

Antes de armar hipótesis propias, identificá la **firma** del incidente
(qué se ve en los datos, no qué lo causó) y buscá casos previos:

- Si tenés acceso a la base de casos (RAG), consultala con la firma y el
  síntoma, no con una causa supuesta. Ej.: "CPU de prestashop en 0 con memoria
  congelada, sin restart, ventana de silencio de 2 h", no "problema de sincro".
- Si no tenés acceso, usá la taxonomía de abajo como lista de causas a
  descartar.

Un caso previo es una **hipótesis con prioridad, no un diagnóstico**. Antes de
reusar su solución, verificá que la firma coincide en los datos del caso
actual y decí explícitamente qué coincide y qué no. Si dos casos previos
tienen la misma firma con causas distintas (pasa con el freeze a CPU 0),
el trabajo es encontrar el dato que los separa.

## Paso 3 — Saber qué hay en cada archivo crudo

Todos viven junto a `contexto.md`, en `./contextos/<stack>/<fecha>/`:

| Archivo | Qué tiene | Cuándo pedirlo/leerlo |
|---|---|---|
| `portainer.json` | Stack completo: todas las env vars (no solo las "interesantes" que filtra el reporte), compose completo, servicios/tasks crudos, git origin | Falta una env var puntual que no aparece en la sección 7, o hace falta el detalle de tasks/nodos más allá del resumen de restarts |
| `compose.yml` | El compose desplegado tal cual, texto plano | Se necesita ver un servicio completo (ej. volúmenes, healthchecks, logging driver) que el reporte no extrae (el reporte solo saca `deploy.resources`) |
| `metricas.json` | Series completas de InfluxDB (ventana actual + referencia del día anterior), point-by-point, no solo el peak/mean agregado de la sección 4 | Hace falta ver **cuándo dentro de la ventana** pasó el pico, no solo que hubo un pico — o correlacionar un momento puntual entre métricas y logs |
| `logs.ndjson` | Una línea JSON por entrada de log: timestamp ART y UTC, labels del stream, línea cruda completa | El error agrupado de la sección 8 no trae el mensaje completo (las firmas normalizan pids/números), o hace falta ver el tráfico real alrededor de una ventana de tasa anómala marcada en la sección 8 |
| `cloudflare.json` | Igual al resumen de la sección 6, casi no agrega nada | Rara vez hace falta — la sección 6 ya es el dato completo |

Ojo: un `logs.ndjson` puede venir mezclado con otros stacks. Antes de sacar
conclusiones de tráfico, contá líneas por label `swarm_stack`.

## Paso 4 — Pedir el archivo correcto, no todos

Si necesitás bajar a un crudo, pedí (o leé) **solo el que corresponde** a la
pregunta, y decí por qué ese y no otro — no proceses `logs.ndjson` entero para
algo que ya está en la sección 8. Ejemplos de cuándo sí vale la pena:

- "¿Qué decía exactamente el error de `hookDisplayProductButtons`?" → `logs.ndjson`,
  filtrando por el módulo/mensaje de la firma en cuestión.
- "¿El pico de CPU fue justo antes o después del restart?" → `metricas.json`
  (serie completa) cruzado con la sección 5 (restarts) de `contexto.md`.
- "¿Qué límite de memoria tiene el contenedor de DB?" → ya está en la sección 7;
  si no aparece ahí, recién entonces `compose.yml`.

## Paso 5 — Nunca recalcules lo que el destilado ya calculó

Status codes, top endpoints, clasificación de user-agents, ratio de errores,
picos/medias por servicio: todo eso ya está en `contexto.md`. Si lo volvés a
calcular desde `logs.ndjson`/`metricas.json` a mano corrés el riesgo de no
replicar exactamente la lógica de `destilado/` (ventanas, exclusión de sftp/
filebrowser, normalización de firmas) y quedar en contradicción con el reporte.

## Paso 6 — Cierre de caso: emitir el registro

Cuando el caso se cierra, generá un registro para la base de casos con el
formato de abajo. Se cierra cuando:

- el usuario dice que quedó resuelto, que no hubo caídas nuevas, o pide
  "cerrá el caso" / "registralo"; o
- se aplicó un cambio y hay una verificación posterior con datos (contexto
  nuevo, métrica que volvió a su baseline, monitor sin caídas).

Si el usuario pide el registro sin verificación posterior, generalo igual con
`estado: en_monitoreo`. Nunca marques `resuelto` sin decir en
`verificacion` qué dato lo prueba.

Reglas del contenido:

- **Solo hechos del caso.** Lo que se confirmó con datos va como confirmado;
  lo inferido, con `confianza_causa: probable` o `hipotesis`. Una propuesta
  que no se aplicó va en "Pendiente", nunca en "Solución aplicada".
- **La firma es lo más importante del registro**: es lo que va a matchear el
  próximo caso. Escribila con los indicadores medibles concretos (valores,
  nombres de error, patrón temporal), no con la conclusión.
- **"Descartado" no es opcional** si se descartó algo con datos (ej. "la RAM
  no fue la causa: memoria plana durante el corte, `fail_count` 0"). Evita
  que el próximo diagnóstico pierda tiempo en lo mismo.
- **Nada de secretos ni exposición**: sin credenciales, sin puertos
  publicados de DB, sin IPs de usuarios finales. Hallazgos de seguridad del
  compose van a otro ticket, no al registro.
- Si el usuario corrige un dato del registro (ej. qué se aplicó), regeneralo
  completo, no un parche.
- Largo: hasta ~600 palabras de cuerpo. Un caso tiene que entrar en un solo
  chunk de la base.

Entregá el registro como archivo `.md` con nombre `<fecha>-<sitio>.md`
(ej. `2026-08-18-hov.md`).

### Formato del registro

```markdown
---
id: 2026-08-18-hov
fecha_incidente: 2026-08-18
fecha_cierre: 2026-08-22
sitio: hov
stack: hov-mitiendaonline-com
nodo: wn08
entorno: Capitalinas
plataforma: prestashop            # prestashop | wordpress | otra
categorias: [request-gigante, apache-prefork-sobredimensionado, opcache-roto]
estado: resuelto                  # resuelto | en_monitoreo | no_confirmado
confianza_causa: confirmada       # confirmada | probable | hipotesis
casos_relacionados: []            # ids de casos previos con la misma firma
---

## Síntoma reportado
Lo que dijo Wuala, en una o dos líneas, incluida su lectura de Grafana
(ej. "RAM de Presta saturada, CPU clavada en 200%").

## Firma técnica
Indicadores medibles: valores de CPU/memoria/throttling contra el límite,
`fail_count`, `pgmajfault`, errores literales (`AH00161`, `Errcode: 28`),
ventanas de silencio y su patrón temporal, perfil de tráfico (UA, rutas, %).

## Causa raíz
La cadena causal en 2–5 pasos.

## Descartado
Qué se descartó y con qué dato.

## Solución aplicada
Cambios concretos con valores y dónde (volumen, compose, Cloudflare, Wuala).

## Pendiente
Lo propuesto y no aplicado, con quién lo tiene (LVM, Wuala, cliente final).

## Verificación del cierre
Qué dato confirmó que quedó resuelto, y cuándo.
```

### Taxonomía de `categorias`

Lista cerrada. La primera categoría es la causa principal; las siguientes,
agravantes. Si nada encaja, usá `otra` y proponé la categoría nueva al
usuario para agregarla acá.

| Categoría | Firma típica |
|---|---|
| `crawl-facetado` | Ráfaga de URLs `?q=` con muchos filtros combinados, un UA dominante en miles de IPs, DB contra su techo de CPU |
| `bot-falso` | UA de Googlebot/Ahrefs/Semrush fuera de sus rangos publicados |
| `request-gigante` | `resultsPerPage=99999` o similar; pico de `active_anon` de PHP |
| `apache-prefork-sobredimensionado` | `MaxRequestWorkers` × `memory_limit` muy por encima del cgroup; memoria al 100% sin OOM, thrashing (`pgmajfault` disparado) |
| `apache-pool-chico` | `MaxRequestWorkers` muy bajo (ej. 8); encolamiento con recursos ociosos |
| `php-memory-limit-excesivo` | `memory_limit` igual o cercano al límite del contenedor |
| `mariadb-buffer-pool-default` | `innodb_buffer_pool_size` 128M con memoria asignada sin usar; block I/O read de la DB muy por encima del día anterior |
| `mariadb-disco-tmp` | `Errcode: 28` / temp tables a disco |
| `sincro-flexxus` | Requests `Cronicle/1.0` a `flxsincro/*.php` que no completan o inflan la memoria de PHP |
| `cron-purga-cache` | `delete_cache*.php` periódico; picos de memoria justo después de cada purga |
| `reindex-buscador` | Reindex completo de facetas/búsqueda en horario comercial (manual o cron con `full=1`) |
| `log-driver-bloqueante` | CPU 0 y memoria congelada sin restart; driver `loki` sin `mode: non-blocking` con retries en `journalctl -u docker` |
| `red-overlay` | CPU 0 en ambos contenedores; `SynRetrans` alto respecto de `ActiveOpens` en el nodo |
| `php-config` | Sesiones sin GC, `log_errors Off`, OPcache sin cargar u otros defaults rotos del template |
| `modo-desarrollo` | Stack en modo dev/debug/profiling activo |
| `cloudflare-config` | Regla de WAF/cache mal hecha o que no matchea, zona sin proxy |
| `monitoreo-config` | Kuma que acepta 5xx como up, o que no alertó |
| `wordpress-plugin` | Scans o crons de plugins pesados (Wordfence, wp-cron), xmlrpc |
| `otra` | — |

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
- `contexto-infra-procom`: nodos, entornos, límites de responsabilidad y
  restricciones al recomendar cambios.
