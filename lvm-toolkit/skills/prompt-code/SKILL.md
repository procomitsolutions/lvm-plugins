---
name: prompt-code
description: Metodología de dos fases para diseñar una automatización y producir el prompt final en inglés para Claude Code. Usar SIEMPRE que Martín quiera construir un script, CLI, o automatización nueva (altas de stack, sync entre sistemas, provisioning, limpieza de datos, bots de infraestructura, etc.) y no haya pedido código directamente — es decir, cuando esté en etapa de diseño más que de implementación. También usar si dice explícitamente "hagamos el prompt para Claude Code", "arranquemos con la fase 1", o pide reusar este flujo para un proyecto nuevo.
---

# Prompt para Claude Code — metodología de dos fases

Martín diseña automatizaciones con Claude (este chat) y las implementa con Claude Code. El patrón
que sigue en TODOS sus proyectos (Alta Stack Wuala, Alta Stack Flexxus, truncado de caché, sync
KONG↔NPM, mapeo CPU/mem, app de Autotask, réplica Firebird) es siempre el mismo:

**Fase 1 (acá, en español)**: entender el problema a fondo antes de escribir nada.
**Fase 2 (acá, resultado en inglés)**: producir el prompt final para pegar en Claude Code.

Claude Code nunca corre en este chat — el output de este skill es siempre texto para que Martín
copie a otra herramienta.

## Fase 1 — Descubrimiento

No saltes a la Fase 2 hasta cerrar estas preguntas. Hacelas de a una o dos por vez, con default
sugerido cuando tengas base para proponerlo (Martín suele confirmar o corregir el default en vez
de partir de cero). Revisá primero `contexto-infra-procom` por si el dato ya está documentado —
no le vuelvas a preguntar algo que ya sabés.

Preguntas que SIEMPRE hay que cerrar:

1. **Alcance exacto**: ¿qué sistemas orquesta? (GitHub, Portainer, Cloudflare, MySQL/MariaDB,
   Firebird, SSH remoto, APIs internas, etc.) ¿Qué pasos hace hoy a mano, en qué orden?
2. **Modo de invocación**: ¿CLI interactivo (prompts paso a paso) o flags-first? Martín tiende a
   preferir interactivo para herramientas nuevas.
3. **Idempotencia y fuente de verdad**: si se corre dos veces, ¿qué pasa? ¿Contra qué sistema se
   valida el estado actual (consultar la API en vivo, no mantener estado propio en un JSON aparte)?
4. **Manejo de errores / rollback**: por default, NO rollback destructivo automático — loguear el
   estado y sugerir resolución manual. Confirmar si aplica excepción.
5. **Flags de seguridad**: ¿necesita `--dry-run`? (default sí, especialmente si hay pasos
   destructivos) ¿`--resume`?
6. **Secretos**: `.env` es el default de Martín. Nunca hardcodear ni pasar por variable de entorno
   visible en `ps` — para DB usar `MYSQL_PWD` u opción equivalente que no quede en el listado de
   procesos.
7. **Dónde corre**: workstation del operador vía VPN, o un contenedor/servidor fijo. Afecta paths y
   si puede asumir herramientas instaladas.
8. **Registro de estado compartido**: si hay un recurso incremental (puertos, nombres, contadores),
   ¿dónde vive? (ver convenciones en `contexto-infra-procom` — p. ej. `ports.json` en GitHub con
   optimistic locking vía `sha`)
9. **Orden de mutaciones externas**: escribir a un registro/checkpoint local ANTES de mutar sistemas
   externos, y confirmar en el registro remoto (commit, etc.) solo después de que todos los pasos
   externos terminaron bien.

Cerrada la Fase 1, resumí las decisiones en una lista corta y confirmá con Martín antes de pasar a
Fase 2.

## Fase 2 — Prompt para Claude Code

Reglas del prompt final:

- **Siempre en inglés**, aunque toda la Fase 1 fue en español
- Estructura: contexto del sistema (stack tecnológico, convenciones de nombres, endpoints/orgs
  relevantes) → arquitectura elegida → paso a paso ordenado → decisiones explícitas que Claude Code
  NO debe re-litigar (ya las cerraron en Fase 1) → flags y modo de secretos → qué NO hacer
- Si el proyecto es grande, dividir en fases numeradas (0, 1, 2…) como en el proyecto de Autotask
  (fases 0–4 build local con mock, 5–8 integración real) — permite implementar y probar incremental
- Cerrar siempre con: "ask before generating files you weren't asked for" si Martín lo pidió en esa
  sesión (lo pidió explícitamente en el proyecto DuckDB — confirmar si aplica acá también)
- Entregar como archivo markdown descargable cuando el prompt es largo (>~40 líneas); si es corto,
  directamente en el chat

## Al cerrar el proyecto

Si Martín pide el desglose de tiempo para time-tracking, no lo generes vos mismo — activá el skill
`entrada-tiempo-autotask`. Si pide documentación del proceso una vez implementado, no lo generes acá
tampoco — es un skill aparte (documentar-automatizacion, si existe) o pedile a Martín que aclare
formato.
