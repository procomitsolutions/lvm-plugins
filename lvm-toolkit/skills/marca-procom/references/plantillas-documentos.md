# Estructuras de entregables — PROCOM IT SOLUTIONS

Cada tipo de pieza tiene un esqueleto fijo. Respetalo: es lo que hace que un cliente que recibió
tres informes de Procom sepa dónde buscar la información en el cuarto.

Las secciones marcadas **(obligatoria)** van siempre. Las demás se incluyen si hay contenido —
mejor omitir una sección que rellenarla.

## Contenido

1. [Informe técnico](#1-informe-técnico)
2. [Informe de diagnóstico / incidente](#2-informe-de-diagnóstico--incidente)
3. [Propuesta comercial](#3-propuesta-comercial)
4. [Plan de trabajo y cronograma](#4-plan-de-trabajo-y-cronograma)
5. [Presentación / deck](#5-presentación--deck)
6. [Minuta de reunión](#6-minuta-de-reunión)
7. [Procedimiento / documentación técnica](#7-procedimiento--documentación-técnica)
8. [Reporte de servicio mensual](#8-reporte-de-servicio-mensual)
9. [Bloques reutilizables](#bloques-reutilizables)

---

## 1. Informe técnico

Para relevamientos, auditorías, análisis de capacidad, resultados de migración.

```
Portada (obligatoria)
Control de versiones (obligatoria)
Índice — si supera 6 páginas

1. Resumen ejecutivo (obligatoria)
   Media página máximo. Sin jerga. Qué se hizo, qué se encontró, qué hay que decidir.
   Si el lector lee solo esto, tiene que poder tomar la decisión.
2. Alcance y metodología
   Qué se relevó, qué NO se relevó, con qué herramientas, en qué ventana temporal.
   La exclusión explícita evita discusiones después.
3. Situación actual
   Estado del entorno con datos duros. Diagramas si aportan.
4. Hallazgos (obligatoria)
   Uno por bloque, cada uno con: ID, severidad, evidencia, impacto operativo, causa raíz.
   Ordenados por severidad descendente.
5. Recomendaciones (obligatoria)
   Numeradas y trazables al hallazgo que resuelven. Esfuerzo estimado e impacto.
6. Próximos pasos (obligatoria)
   Tabla: Acción / Responsable / Fecha objetivo.
Anexos — logs, capturas, salidas de comandos, inventarios.
```

**Tabla de hallazgos** (formato estándar):

| ID | Severidad | Hallazgo | Impacto | Recomendación |
|---|---|---|---|---|
| H-01 | Crítico | … | … | R-01 |

---

## 2. Informe de diagnóstico / incidente

Para caídas, saturaciones, degradaciones. Es el formato que va como respuesta de ticket ampliada.

```
Portada (obligatoria)
1. Síntesis del incidente (obligatoria)
   Qué pasó, cuándo empezó, cuándo se normalizó, a quién afectó. Tres a cinco líneas.
2. Línea de tiempo (obligatoria)
   Tabla cronológica con hora, evento y fuente de la evidencia.
   | Hora | Evento | Fuente |
3. Causa raíz (obligatoria)
   Una causa, enunciada sin ambigüedad. Si no está confirmada, decir "hipótesis principal"
   y listar qué falta para confirmarla. No inventar certeza.
4. Evidencia
   Extractos de logs, métricas, capturas. Recortados a lo relevante — no volcados crudos.
5. Acciones ejecutadas (obligatoria)
   Qué se hizo para contener y para resolver, con horario.
6. Impacto
   Duración, servicios afectados, usuarios alcanzados, datos comprometidos (o su ausencia).
7. Prevención (obligatoria)
   Qué evita que se repita. Diferenciar lo que hace Procom de lo que depende del cliente.
Anexos
```

El tono acá importa especialmente: hechos y horarios, sin defensiva ni culpabilización.

---

## 3. Propuesta comercial

Única pieza donde corresponde el "nosotros" institucional.

```
Portada (obligatoria) — incluye número de propuesta y validez
1. Entendimiento de la necesidad (obligatoria)
   Devolverle al cliente su problema en palabras claras. Demuestra que se escuchó.
2. Solución propuesta (obligatoria)
   Qué se implementa y por qué esa arquitectura y no otra.
3. Alcance
   3.1 Incluido
   3.2 No incluido (obligatoria) — la sección que evita el conflicto posterior
4. Plan de implementación
   Fases, duración estimada, hitos. Referencia al cronograma si va adjunto.
5. Equipo y modalidad de trabajo
   Roles asignados, canal de comunicación, SLA de respuesta.
6. Inversión (obligatoria)
   Tabla de ítems: Concepto / Cantidad / Unitario / Total. Moneda e IVA explícitos.
   Separar CAPEX de recurrente mensual si aplica.
7. Condiciones comerciales (obligatoria)
   Validez de la propuesta, forma de pago, plazo de entrega, garantía.
8. Por qué Procom
   Media página. Trayectoria (más de 19 años en Argentina y Latinoamérica), áreas de
   especialidad relevantes al proyecto, casos análogos si los hay.
9. Próximo paso (obligatoria)
   Una acción concreta con fecha.
```

Nunca poner precios sin moneda, sin fecha de validez o sin aclarar el tratamiento del IVA.
Si falta ese dato, marcar `[COMPLETAR: …]` y avisar al usuario.

---

## 4. Plan de trabajo y cronograma

```
Portada (obligatoria)
1. Objetivo del proyecto (obligatoria)
2. Alcance y entregables (obligatoria)
   Tabla: Entregable / Descripción / Criterio de aceptación.
3. Fases y actividades (obligatoria)
   Estructura numerada: 1. Fase → 1.1 Actividad → 1.1.1 Tarea.
   Cada tarea con duración, responsable y dependencias.
4. Cronograma / Gantt (obligatoria)
5. Hitos
   Tabla: Hito / Fecha / Criterio de cumplimiento.
6. Recursos y responsables
   Matriz RACI si el proyecto involucra más de tres personas.
7. Supuestos y dependencias del cliente (obligatoria)
   Accesos, ventanas de mantenimiento, disponibilidad de referentes.
8. Riesgos
   Tabla: Riesgo / Probabilidad / Impacto / Mitigación.
9. Gobernanza
   Frecuencia de reuniones de avance, formato de reporte, criterio de escalamiento.
```

**Gantt:** barras en `azul-profundo`; hitos como rombo en `verde-tecnologico`; camino crítico en
`azul-medio`; avance real como barra interna más fina en `verde-evolucion`; línea de "hoy"
punteada en gris. Fines de semana con fondo `#F4F6F8`. Ver
`implementacion-tecnica.md` para el armado concreto en xlsx, pptx o HTML.

---

## 5. Presentación / deck

Formato 16:9. Estructura base:

```
1. Portada — fondo azul-profundo a sangre, bloque de marca, título, cliente, fecha
2. Agenda
3. Contexto / situación actual
4-N. Contenido, una idea por slide
N+1. Conclusiones o recomendaciones
N+2. Próximos pasos
N+3. Cierre — "Doing IT Better Every Day" sobre azul-profundo, más datos de contacto
```

Reglas de slide:

- Un mensaje por slide. El título del slide **es** el mensaje, no la categoría:
  "El almacenamiento se satura en 4 meses", no "Almacenamiento".
- Máximo 6 bullets, máximo 2 líneas cada uno. Si no entra, es más de un slide.
- Cuerpo mínimo 16 pt; títulos 28–32 pt.
- Divisores de sección: fondo `azul-profundo`, número de sección grande en
  `verde-tecnologico`, título en blanco.
- Todo slide de contenido lleva el bloque de marca reducido y el número de slide al pie.
- Los datos van en gráfico nativo, no en captura de pantalla de una planilla.

---

## 6. Minuta de reunión

Pieza corta, se entrega el mismo día. Puede ser markdown o docx liviano, sin portada completa.

```
Encabezado: Cliente / Fecha y hora / Modalidad / Participantes (nombre y organización)
1. Temas tratados — bullets
2. Decisiones tomadas — numeradas, cada una atribuible
3. Acciones acordadas (obligatoria)
   Tabla: Acción / Responsable / Fecha comprometida / Estado
4. Temas pendientes para próxima reunión
5. Próxima reunión: fecha, hora, temario tentativo
```

Regla de oro: lo que no está en la minuta, no se acordó. Si algo quedó ambiguo en la reunión,
la minuta lo registra como pendiente, no lo resuelve por su cuenta.

---

## 7. Procedimiento / documentación técnica

Para runbooks, instructivos, handovers y documentación de entrega.

```
Portada + Control de versiones (obligatorias — la documentación técnica se versiona sí o sí)
1. Propósito y alcance (obligatoria)
2. Audiencia y prerrequisitos
   Qué accesos, permisos y conocimientos hacen falta antes de empezar.
3. Arquitectura / componentes involucrados
   Diagrama + inventario: componente, versión, ubicación, responsable.
4. Procedimiento paso a paso (obligatoria)
   Pasos numerados. Comando o acción en bloque monoespaciado, seguido de resultado esperado.
   Advertencias antes del paso, nunca después.
5. Verificación (obligatoria)
   Cómo se confirma que salió bien.
6. Rollback (obligatoria si el procedimiento modifica producción)
7. Troubleshooting
   Tabla: Síntoma / Causa probable / Resolución.
8. Contactos y escalamiento
```

En bloques de comandos usar fuente monoespaciada sobre fondo `#F4F6F8` con borde izquierdo de
3 pt en `verde-tecnologico`. Enmascarar credenciales, IPs públicas y datos sensibles del cliente
salvo indicación expresa.

---

## 8. Reporte de servicio mensual

```
Portada (obligatoria) — período cubierto en el subtítulo
1. Resumen del período (obligatoria)
   Tablero de indicadores: tickets recibidos / resueltos / pendientes, tiempo medio de
   respuesta y resolución, cumplimiento de SLA, disponibilidad.
2. Evolución
   Gráficos comparativos contra los períodos previos. Mínimo tres meses de serie.
3. Detalle por categoría
4. Incidentes destacados
   Los críticos del período, con enlace o referencia al informe de diagnóstico correspondiente.
5. Trabajos planificados ejecutados
6. Observaciones y recomendaciones (obligatoria)
   La sección que convierte el reporte en asesoría en lugar de en una planilla.
7. Planificado para el próximo período
```

---

## Bloques reutilizables

**Control de versiones**

| Versión | Fecha | Autor | Cambios |
|---|---|---|---|
| 1.0 | AAAA-MM-DD | Nombre — PROCOM IT SOLUTIONS | Versión inicial |

**Próximos pasos**

| # | Acción | Responsable | Fecha objetivo |
|---|---|---|---|

**Nota de confidencialidad** (pie de portada, cuando hay datos de infraestructura del cliente)

> Documento confidencial — uso exclusivo de [Cliente] y PROCOM IT SOLUTIONS.
> Prohibida su reproducción total o parcial sin autorización.

**Cierre institucional** (última página o slide)

> **PROCOM IT SOLUTIONS**
> Doing IT Better Every Day
> [COMPLETAR: web / email / teléfono]
