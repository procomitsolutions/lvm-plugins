---
name: chequeo-logs
description: Análisis de logs (Loki/Traefik/Apache/aplicación) para diagnosticar un incidente de infraestructura — sitio caído, base de datos saturada, errores intermitentes — y producir una respuesta de ticket lista para el cliente. Usar SIEMPRE que Martín suba o pegue archivos de log y mencione una caída, saturación, incidente, o pida "revisá esto" sobre logs — sin esperar que explique el síntoma primero. También aplica si describe un patrón de incidente sin adjuntar logs todavía (guiar qué exportar).
---

# Chequeo de logs / postmortem de incidente

## Antes de analizar

Si Martín menciona un incidente pero todavía no adjuntó logs, pedile específicamente:
- Ventana de tiempo (con margen: pedir al menos 30-40 min ANTES del síntoma reportado, no solo el
  momento del crash — el patrón típico es que el problema empieza antes de que se note)
- Qué stack/servicio (ver `contexto-infra-procom` para contexto conocido del cluster)
- Si hay Cloudflare delante o no (cambia si hay visibilidad de tráfico externo)

## Corrección de zona horaria — SIEMPRE primero

Los contenedores loguean en UTC; los hosts worker y el horario de Argentina son ART (UTC-3). Antes
de armar cualquier timeline, convertí todos los timestamps a hora Argentina y decilo explícitamente
en la respuesta — esto ya causó confusión en incidentes pasados.

## Checklist de diagnóstico

1. **Armar el timeline primero, conclusión después.** No asumas causa antes de tener la secuencia
   completa de eventos ordenada.
2. **Ampliar la ventana hacia atrás si el log inicial no muestra causa.** El patrón más frecuente:
   los minutos justo antes del crash muestran solo el efecto (workers muriendo, SIGKILL en cascada);
   la causa real está 20-30 min antes. Si el primer archivo no explica nada, pedí o buscá el rango
   anterior antes de concluir "no hay causa visible en los logs".
3. **Señales de saturación de recursos**:
   - Ráfaga de requests concentrada en pocos segundos a un mismo endpoint (típico: checkout/carrito,
     porque recalcula todo el pedido — operación pesada en PrestaShop)
   - El pipeline de logging mismo atrasándose en el flush (si los logs tardan en escribirse, es
     evidencia indirecta de que el sistema ya estaba saturado antes del corte visible)
   - CPU de la base de datos al tope sin que Cloudflare muestre tráfico anómalo → sospechar
     queries pesadas o falta de índice, no necesariamente tráfico externo
4. **Descartar ruido de fondo.** Escaneos de vulnerabilidad de bajo rate (paths de webshells
   conocidos, todo 302/404) son comunes y casi nunca la causa — no los mezcles con la narrativa
   del incidente salvo que coincidan en tiempo con el síntoma.
5. **Confirmar con el dato más fuerte antes de nombrar causa.** Si hay una captura o log que
   confirma el patrón (p. ej. screenshot del propio Martín mostrando la ráfaga), citarlo como la
   evidencia decisiva, no como algo adicional.
6. **Diferenciar audiencia interna vs. externa desde el arranque**, especialmente en incidentes de
   certificados/DNS: separar qué puede resolver Martín directamente vs. qué requiere escalar a otra
   área (firewall, equipo de Windows, etc.) — no mezclar ambos en el mismo paso a paso.

## Formato de salida

Dos partes, siempre:

1. **Diagnóstico técnico** en el chat: timeline con horas ART, causa raíz identificada, evidencia
   que la respalda, y qué fue ruido descartado.
2. **Redacción de ticket para el cliente**: párrafo corto que abra con el resumen del incidente
   (causa → efecto → resolución/estado actual), en el mismo tono que Martín ya usa en sus tickets
   (directo, sin tecnicismos innecesarios si el ticket es cliente-facing). Si Martín ya tiene un
   párrafo de recomendación escrito (p. ej. sugerir Cloudflare), incorporalo tal cual al final, no
   lo reescribas.

No ofrezcas remediación inmediata (reiniciar, escalar) como primer paso salvo que Martín lo pida —
el foco de este skill es diagnóstico y comunicación, no acción en caliente.
