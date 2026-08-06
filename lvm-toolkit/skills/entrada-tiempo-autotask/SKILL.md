---
name: entrada-tiempo-autotask
description: Redacta justificaciones de time entries / tickets de Autotask en el formato estándar del equipo LVM en Procom — español, tercera persona pasiva, bullets concisos. Usar cuando se pida cargar horas, redactar una justificación de ticket, un resumen para Autotask, o un desglose de tiempo por día/tarea sobre trabajo ya hecho (discutido en esta conversación o descripto por quien lo pide). Dispara también con frases como "cargá esto en el ticket", "resumime esto para Autotask", "necesito la justificación de esta tarea".
---

# Entrada de tiempo / justificación de ticket (Autotask)

Formato estándar del equipo LVM, validado en múltiples proyectos (KONG/NPM, truncado de caché,
listado de tiendas, alta de stack Wuala/Flexxus).

## Reglas de redacción

- **Español, tercera persona pasiva**: "Se configuró...", "Se desarrolló...", "Se validó...",
  "Se migró...", "Se diagnosticó...". Nunca primera persona ("hice", "armé").
- **Bullets concisos**, uno por acción o hito relevante — no párrafos largos.
- Sin relleno ni justificación emocional — es un registro de trabajo, no un reporte de estado.
- Si la tarea tocó varios sistemas (p. ej. GitHub + Portainer + Cloudflare), nombrarlos
  explícitamente salvo que se pida lenguaje genérico (puede pasar con nombres de producto, p. ej.
  NPM/KONG vs. "NGINX" genérico — si no se aclara, usar los nombres reales).

## Cuándo generar desglose por día en vez de bullets únicos

Si el trabajo tuvo una fase de diseño/planificación separada de la de implementación (patrón típico
en proyectos de automatización vía Claude Code), separar en dos entradas:
- **Día de planificación estratégica**: decisiones de arquitectura, alcance, preguntas resueltas
- **Día de implementación**: qué se construyó y validó

## Fuente del contenido

Extraé el contenido de lo que se hizo de:
1. Lo discutido en la conversación actual (preferido — más preciso)
2. Lo que describa directamente quien lo pide, si no hay contexto en el chat

No inventes pasos que no se mencionaron. Si falta un dato concreto (nombre de cliente, hora, sistema
exacto), preguntá antes de redactar en vez de generalizar.

## Formato de entrega

- Lista de bullets en el chat, lista para copiar/pegar directo en Autotask
- Si son muchas tareas numeradas, respetar la numeración ya definida en el plan de proyecto
  correspondiente
- Si se pide guardarlo en un vault, ofrecé exportarlo como markdown, pero el output principal
  siempre va en el chat primero
