---
name: marca-procom
description: 'Identidad de marca y formato institucional de PROCOM IT SOLUTIONS (paleta cromática oficial, tipografías, logos, voz, estructura de entregables). Usar SIEMPRE que se produzca cualquier pieza que salga con el nombre de Procom o vaya a un cliente de Procom — informes, informes de diagnóstico, propuestas comerciales, cotizaciones, planes de trabajo, cronogramas y Gantt, presentaciones y decks, minutas y actas, documentación técnica, procedimientos, handovers, resúmenes ejecutivos, one-pagers, dashboards y reportes de servicio — en docx, pptx, xlsx, pdf, markdown o HTML. Disparar aunque no se nombre "marca", "manual" o "branding": si el pedido es "armame un informe para el cliente", "hacé la propuesta", "pasame esto a presentación", "necesito el plan de trabajo del proyecto", esta skill define cómo tiene que verse y escribirse. También usar cuando se pregunte por colores, hex, tipografías, uso del logo o slogan de Procom, o para revisar si una pieza existente respeta los lineamientos.'
---

# Identidad y formato de entregables — PROCOM IT SOLUTIONS

Esta skill traduce el Manual de Marca (Abril 2026, v3) en reglas aplicables a documentación.
El objetivo es que cualquier pieza que sale de Procom se reconozca como Procom: mismo tono,
misma paleta, misma estructura. No es decoración — es lo que hace que un informe técnico
se lea como el trabajo de un partner tecnológico y no como un mail largo.

Los colores, logos y medidas de acá salen directamente del manual oficial. No los aproximes
ni los reemplaces por equivalentes "parecidos".

## Antes de escribir nada

1. **Identificá el tipo de entregable** (informe, propuesta, diagnóstico, plan de trabajo,
   presentación, minuta…). Cada uno tiene una estructura fija en
   `references/plantillas-documentos.md`. Leé ese archivo antes de armar el esqueleto.
2. **Identificá el formato de salida.** Si es `.docx`, `.pptx`, `.xlsx` o `.pdf`, usá la skill
   pública correspondiente para la mecánica del archivo, y esta skill para los parámetros de
   marca. Las dos se combinan, no se reemplazan.
3. **Usá los logos de `assets/`.** Están los siete archivos en PNG con fondo transparente y
   alta resolución. Nunca dibujes, generes ni aproximes un logo.

## Voz y tono

Procom se posiciona como **partner tecnológico, no proveedor**. Eso define cómo se escribe:

- **Simplificar lo complejo.** Traducir la complejidad técnica a impacto operativo. Un informe
  no termina en "el disco está al 94%": termina en qué se rompe, cuándo, y qué cuesta.
- **Español rioplatense neutro, tercera persona.** "Se relevó", "se detectó", "se recomienda".
  Evitar el "nosotros hicimos" salvo en propuestas comerciales, donde el "nosotros" institucional
  sí corresponde.
- **Afirmativo y concreto.** Frases cortas. Sin adjetivos de relleno ("solución de vanguardia",
  "sinergia"). Los números y las fechas mandan.
- **Sin alarmismo.** Los hallazgos críticos se enuncian con severidad y evidencia, no con
  dramatismo. La calma es parte del posicionamiento.
- **Cierre orientado a acción.** Toda pieza termina en próximos pasos con responsable y fecha,
  aunque el responsable sea el cliente.

Anclajes de identidad para portadas, cierres y textos institucionales:

| Elemento | Texto exacto |
|---|---|
| Razón social en documentos | PROCOM IT SOLUTIONS |
| Slogan | Doing IT Better Every Day |
| Bajada de marca | IT Solutions |
| Propósito | Innovación sin límites |
| Trayectoria | Más de 19 años en Argentina y Latinoamérica |

El slogan va en inglés y **nunca se traduce, se abrevia ni se reescribe**. Va en portada y/o
contratapa, no salpicado en el cuerpo. Cuando se usa como remate gráfico, el lockup del manual
es un chevron `›` en verde tecnológico + el slogan, con las siglas **IT** también en verde
tecnológico y el resto en azul institucional.

## Paleta oficial

Siete colores: tres verdes, tres azules y negro profundo. Los verdes representan innovación,
crecimiento y adaptabilidad; los azules, confianza, estabilidad y precisión técnica; el negro
aporta sobriedad y profesionalismo.

| Token | Nombre de marca | Hex | RGB | Rol en documentos |
|---|---|---|---|---|
| `verde-tecnologico` | Verde tecnológico | `#A1C623` | 162 198 35 | Acento principal. Es el verde de las siglas "IT" |
| `verde-vision` | Verde visión | `#6AB333` | 106 179 51 | Series de gráficos, barras de avance |
| `verde-evolucion` | Verde evolución | `#12A039` | 18 160 58 | Estados OK, fondo oscuro alternativo |
| `azul-profundo` | Azul profundo | `#1166B0` | 17 102 176 | Encabezados, títulos H2, primera serie |
| `azul-medio` | Azul medio | `#2B90CF` | 43 144 207 | Subtítulos, bordes, segunda serie |
| `celeste` | Celeste | `#29B0E6` | 41 177 230 | Resaltados, fondos suaves, tercera serie |
| `negro-procom` | Negro | `#1D1E1B` | 29 30 27 | Texto de títulos, logotipo tipográfico |

**Azul institucional `#182C49`.** No está en la paleta de siete, pero es el color que el propio
manual usa para los títulos sobre fondo claro y como base de todos sus fondos oscuros. Usalo
para portadas, divisores de sección y encabezados de tabla.

Neutros de maquetación (herramientas, no colores de marca): texto `#333333`, texto secundario
`#6B7280`, líneas `#D9DEE3`, fila alterna `#F4F6F8`, fondo claro institucional `#EAF4FA`.

**Reglas de uso:**
- Un documento no usa los siete colores. Base: **azul institucional + azul profundo + verde
  tecnológico**. Sumá un cuarto solo si hay que diferenciar datos.
- El verde tecnológico es acento, no color de cuerpo de texto. Nunca párrafos en verde.
- Semáforos de severidad: crítico `#C0392B`, alto `#E67E22`, medio `#F1C40F`, bajo/OK
  `#12A039`. Rojo y naranja no son colores de marca — sirven solo como código de estado.
- Los tres oscuros habilitados como fondo del logo blanco son `#12A039`, `#1166B0` y `#1D1E1B`.

## Barra de gradiente de marca

El elemento gráfico más reconocible del manual, y el más fácil de reproducir en cualquier
formato: una barra horizontal fina con un degradé de verde a azul oscuro.

```
#6AB333  →  #1166B0  →  #182C49
```

Va bajo el título de portada (ancho ≈ media página, alto ≈ 6 pt) y como remate al pie de los
divisores de sección. En `.docx` y `.pptx` insertá `assets/barra-gradiente.png`; en HTML se
resuelve con `linear-gradient`.

## Áreas técnicas y su color

Cada área especializada tiene su color asignado dentro de la gama. Sirve para codificar
secciones en informes multi-área, solapas de un deck de servicios e iconografía.

| Área | Token | Hex |
|---|---|---|
| Networking y Conectividades | `verde-tecnologico` | `#A1C623` |
| Virtualización y Almacenamiento Inteligente | `verde-vision` | `#6AB333` |
| Ciberseguridad Integral | `verde-evolucion` | `#12A039` |
| Microsoft 365 y Azure | `azul-profundo` | `#1166B0` |
| Microservicios y Cloud Services | `azul-medio` | `#2B90CF` |
| Automatización de Procesos Digitales | `celeste` | `#29B0E6` |
| Firewall | `negro-procom` | `#1D1E1B` |

El orden no es arbitrario: recorre la gama de verde a azul a negro, igual que el símbolo.
Respetalo cuando listes las áreas.

## Tipografía

| Uso | Fuente | Fallbacks (en este orden) |
|---|---|---|
| Títulos y subtítulos | **Sofia Sans** | Archivo, Roboto Condensed, Arial Narrow, Arial |
| Cuerpo, frases y párrafos | **STEM** | Inter, Roboto, Calibri, Arial |

En `.docx` y `.pptx` declará siempre la fuente de marca como primaria: si el destinatario la
tiene instalada la ve correcta, y si no, cae al fallback. En HTML usá la pila completa. En PDF
generado en este entorno ninguna de las dos está instalada, así que el render local usa el
fallback — no es un error, pero si el PDF es la pieza final avisalo.

| Nivel | Tamaño | Peso | Color |
|---|---|---|---|
| Título de portada | 32–40 pt | Bold | blanco sobre `#182C49` |
| H1 / sección | 18 pt | Bold | `#182C49` |
| H2 | 14 pt | Semibold | `#1166B0` |
| H3 | 11.5 pt | Bold | `#1D1E1B` |
| Cuerpo | 10.5–11 pt | Regular | `#333333`, interlineado 1.15–1.3 |
| Tablas | 9.5–10 pt | Regular | `#333333` |
| Pie de página / notas | 8 pt | Regular | `#6B7280` |

Los títulos de sección llevan una regla inferior fina (0.75 pt) en `verde-tecnologico`. Es el
gesto que identifica al documento como Procom incluso en una página sin logo.

## Logos disponibles

Todos en `assets/`, PNG con fondo transparente, extraídos del manual oficial.

| Archivo | Cuándo |
|---|---|
| `logo-horizontal-color.png` | Uso principal sobre fondo claro. Encabezados, portadas claras |
| `logo-vertical-color.png` | Espacios angostos o cuadrados sobre fondo claro |
| `logo-horizontal-blanco.png` | Sobre `#12A039`, `#1166B0`, `#1D1E1B`, `#182C49`, o fondos ajenos con buen contraste |
| `logo-vertical-blanco.png` | Ídem, en formato vertical |
| `logo-horizontal-negro.png` | Sin impresión a color: facturas, formularios, avisos |
| `logo-vertical-negro.png` | Ídem, en formato vertical |
| `isotipo-color.png` | Solo el símbolo: favicon, avatar, viñeta, marca de agua |
| `barra-gradiente.png` | La barra de gradiente de marca lista para insertar (2400×48) |
| `fondo-portada-a4.png` | Fondo de portada A4 (2480×3508) con el degradé institucional |
| `fondo-portada-16x9.png` | Ídem para slides (1920×1080) |

**Reglas:** no deformar (escala siempre proporcional), no rotar, no recolorear, no aplicar
sombras ni efectos, no encerrar en cajas, no usar sobre fondos de bajo contraste ni sobre
imágenes con ruido visual.

**Área de protección:** margen libre en los cuatro lados equivalente a la altura de la letra "O"
del logotipo — en la práctica, ~18% del alto del logo horizontal. No apoyes el logo contra el
borde del encabezado ni lo pegues a un título.

**Tamaños mínimos de impresión:**

| Versión | Con bajada "IT Solutions" | Sin bajada |
|---|---|---|
| Horizontal | 40 mm | 20 mm |
| Vertical | 30 mm | 20 mm |

La bajada se incluye siempre que el contexto lo permita. Se omite solo si el tamaño compromete
la legibilidad, o en piezas institucionales o conmemorativas donde quede fuera de contexto.

## Estructura de página estándar

Para informes, propuestas, diagnósticos y planes de trabajo en `.docx` / `.pdf`:

- **Hoja A4 vertical**, márgenes 2,5 cm arriba/abajo y 2 cm laterales.
- **Portada** en `#182C49` a sangre completa (o con `fondo-portada-a4.png`): logo blanco arriba
  a la izquierda, título en el tercio inferior, barra de gradiente de marca bajo el título, y
  debajo cliente, tipo de documento, fecha y versión. Slogan al pie en verde tecnológico.
- **Página 2**: control de versiones (Versión / Fecha / Autor / Cambios) y, si supera 6 páginas,
  índice.
- **Encabezado** desde la página 3: nombre del documento a la izquierda, cliente a la derecha,
  8 pt gris, con regla inferior fina.
- **Pie**: `PROCOM IT SOLUTIONS — Doing IT Better Every Day` a la izquierda, `Página X de Y` a
  la derecha, 8 pt gris.
- **Confidencialidad**: si el documento contiene datos de infraestructura del cliente, agregá al
  pie de portada *Documento confidencial — uso exclusivo de [Cliente] y PROCOM IT SOLUTIONS.*

### Tablas

Encabezado con fondo `#182C49` y texto blanco en Sofia Sans Bold. Filas alternadas con `#F4F6F8`.
Bordes horizontales finos en `#D9DEE3`, sin bordes verticales. Números a la derecha, texto a la
izquierda. Nunca una tabla partida entre páginas sin repetir el encabezado.

### Gráficos

Series en este orden: `#1166B0`, `#A1C623`, `#2B90CF`, `#12A039`, `#29B0E6`. Sin borde de
gráfico, sin fondo, grilla horizontal en `#D9DEE3`. Etiquetas de datos visibles con menos de 8
puntos. Leyenda solo con dos series o más.

## Nomenclatura de archivos

```
PROCOM_[Tipo]_[Cliente]_[Tema]_[AAAA-MM-DD]_v[N].[ext]
```

`Tipo`: Informe, Propuesta, Diagnostico, PlanTrabajo, Cronograma, Presentacion, Minuta, Procedimiento.
Sin espacios, sin acentos, sin caracteres especiales.
Ejemplo: `PROCOM_Diagnostico_Wuala_SaturacionBD_2026-09-04_v1.docx`

## Archivos de referencia

| Archivo | Cuándo leerlo |
|---|---|
| `references/plantillas-documentos.md` | **Siempre que armes un entregable**: estructura sección por sección de informe, propuesta, diagnóstico, plan de trabajo, presentación, minuta, procedimiento y reporte mensual |
| `references/implementacion-tecnica.md` | Antes de escribir el script que genera el docx/pptx/xlsx/html: constantes, snippets verificados, inserción de logos, armado de Gantt |
| `references/identidad-visual.md` | Paleta con equivalencias CMYK, detalle de versiones de logo, usos incorrectos, aplicaciones sobre materiales, checklist de auditoría |
| `assets/` | Logos y fondos listos para insertar |

## Qué no hacer

- No inventar datos de contacto, direcciones, CUIT ni URLs de Procom. El manual solo muestra la
  papelería como mockup de baja resolución, así que esos datos **no están confirmados**: si el
  documento los necesita, dejá `[COMPLETAR: …]` visible y avisá.
- No generar, dibujar ni aproximar un logo: usá los archivos de `assets/`.
- No usar plantillas genéricas de Word/PowerPoint con sus colores por defecto.
- No traducir el slogan ni usarlo como título de sección.
- No aplicar la paleta a piezas que no son de Procom (documentos internos del cliente, material
  de terceros) sin que lo pidan.
- No inflar el documento: si el contenido son tres hallazgos, el informe tiene tres hallazgos.
  La consistencia de marca no justifica relleno.
