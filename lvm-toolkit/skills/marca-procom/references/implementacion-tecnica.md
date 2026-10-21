# Implementación técnica de la marca por formato

Estos snippets resuelven el mapeo de marca. La mecánica del formato (cómo escribir un docx, cómo
no corromper un pptx) está en las skills públicas `docx`, `pptx`, `xlsx` y `pdf` — leelas también.

## Contenido

1. [Constantes de marca](#constantes-de-marca)
2. [Los assets](#los-assets)
3. [DOCX con docx-js](#docx-con-docx-js)
4. [PPTX con pptxgenjs](#pptx-con-pptxgenjs)
5. [XLSX con openpyxl](#xlsx-con-openpyxl)
6. [HTML y markdown](#html-y-markdown)
7. [Gantt](#gantt)
8. [Verificación final](#verificación-final)

---

## Constantes de marca

### JavaScript (docx-js, pptxgenjs)

```js
// Paleta oficial Procom. En pptxgenjs los hex van SIN '#' — este objeto ya está sin '#'.
const PROCOM = {
  verdeTecnologico: 'A1C623',   // el verde de las siglas "IT" — acento principal
  verdeVision:      '6AB333',
  verdeEvolucion:   '12A039',
  azulProfundo:     '1166B0',
  azulMedio:        '2B90CF',
  celeste:          '29B0E6',
  negro:            '1D1E1B',
  // institucionales de soporte
  azulInstitucional:'182C49',   // títulos y fondos oscuros
  fondoClaro:       'EAF4FA',
  // neutros
  texto:            '333333',
  textoSuave:       '6B7280',
  linea:            'D9DEE3',
  zebra:            'F4F6F8',
  blanco:           'FFFFFF',
  // códigos de estado — no son colores de marca
  critico: 'C0392B', alto: 'E67E22', medio: 'F1C40F', ok: '12A039',
};

const FUENTE_TITULO = 'Sofia Sans';
const FUENTE_CUERPO = 'STEM';
const SERIES = [PROCOM.azulProfundo, PROCOM.verdeTecnologico, PROCOM.azulMedio,
                PROCOM.verdeEvolucion, PROCOM.celeste];
const SLOGAN = 'Doing IT Better Every Day';

// Barra de gradiente de marca: verde visión → azul profundo → azul institucional
const BARRA = ['6AB333', '1166B0', '182C49'];
```

### Python (openpyxl, reportlab, matplotlib)

```python
PROCOM = {
    "verde_tecnologico": "#A1C623", "verde_vision": "#6AB333", "verde_evolucion": "#12A039",
    "azul_profundo": "#1166B0", "azul_medio": "#2B90CF", "celeste": "#29B0E6",
    "negro": "#1D1E1B", "azul_institucional": "#182C49", "fondo_claro": "#EAF4FA",
    "texto": "#333333", "texto_suave": "#6B7280", "linea": "#D9DEE3", "zebra": "#F4F6F8",
    "critico": "#C0392B", "alto": "#E67E22", "medio": "#F1C40F", "ok": "#12A039",
}
SERIES = [PROCOM[k] for k in
          ("azul_profundo", "verde_tecnologico", "azul_medio", "verde_evolucion", "celeste")]
BARRA = ["#6AB333", "#1166B0", "#182C49"]
```

`openpyxl` quiere el hex sin `#`: `PatternFill("solid", start_color="182C49")`.

### Interpolar la barra de gradiente

Para `.pptx` y HTML, donde sí se puede dibujar por código:

```js
function barraGradiente(n = 24) {
  const hex2rgb = h => [0, 2, 4].map(i => parseInt(h.slice(i, i + 2), 16));
  const stops = BARRA.map(hex2rgb);
  return Array.from({ length: n }, (_, i) => {
    const t = i / (n - 1) * (stops.length - 1);
    const a = stops[Math.floor(t)], b = stops[Math.min(Math.ceil(t), stops.length - 1)];
    const f = t - Math.floor(t);
    return a.map((v, k) => Math.round(v + (b[k] - v) * f))
            .map(v => v.toString(16).padStart(2, '0')).join('').toUpperCase();
  });
}
```

En `.docx` **no** uses esto: insertá `assets/barra-gradiente.png` (ver más abajo).

---

## Los assets

Rutas relativas al directorio de la skill. Todos son PNG con canal alfa.

| Archivo | Dimensiones | Relación (ancho/alto) |
|---|---|---|
| `assets/logo-horizontal-color.png` | 2932 × 660 | 4.44 |
| `assets/logo-horizontal-blanco.png` | 2501 × 563 | 4.44 |
| `assets/logo-horizontal-negro.png` | 2501 × 563 | 4.44 |
| `assets/logo-vertical-color.png` | 3235 × 2288 | 1.41 |
| `assets/logo-vertical-blanco.png` | 1464 × 1117 | 1.31 |
| `assets/logo-vertical-negro.png` | 1464 × 1117 | 1.31 |
| `assets/isotipo-color.png` | 1620 × 1420 | 1.14 |
| `assets/barra-gradiente.png` | 2400 × 48 | 50.0 |
| `assets/fondo-portada-a4.png` | 2480 × 3508 | A4 a 300 ppp |
| `assets/fondo-portada-16x9.png` | 1920 × 1080 | 16:9 |

**Calculá siempre el alto a partir del ancho y la relación** — nunca fijes ancho y alto por
separado, porque cualquier redondeo deforma el logo y eso es un uso incorrecto explícito.

```js
const ANCHO = 150;                      // px en docx-js
const ALTO  = Math.round(ANCHO / 4.44); // 34
```

Medidas sugeridas: encabezado de documento 110–130 px de ancho; portada 200–240 px; pie de
slide 90–110 px; marca de agua (isotipo al 6% de opacidad) 400 px.

---

## DOCX con docx-js

**Estilos base.** Definilos una vez en `styles.default` y `styles.paragraphStyles` en vez de
repetir formato en cada `TextRun` — así el documento queda editable por el cliente sin desarmarse.

```js
const doc = new Document({
  styles: {
    default: {
      document: { run: { font: FUENTE_CUERPO, size: 21, color: PROCOM.texto },   // 21 half-pt = 10.5 pt
                  paragraph: { spacing: { line: 276, after: 140 } } },
    },
    paragraphStyles: [
      { id: 'Heading1', name: 'Heading 1', basedOn: 'Normal', next: 'Normal', quickFormat: true,
        run: { font: FUENTE_TITULO, size: 36, bold: true, color: PROCOM.azulInstitucional },
        paragraph: { spacing: { before: 340, after: 180 },
                     border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: PROCOM.verdeTecnologico, space: 6 } } } },
      { id: 'Heading2', name: 'Heading 2', basedOn: 'Normal', next: 'Normal', quickFormat: true,
        run: { font: FUENTE_TITULO, size: 28, bold: true, color: PROCOM.azulProfundo },
        paragraph: { spacing: { before: 260, after: 120 } } },
      { id: 'Heading3', name: 'Heading 3', basedOn: 'Normal', next: 'Normal', quickFormat: true,
        run: { font: FUENTE_TITULO, size: 23, bold: true, color: PROCOM.negro },
        paragraph: { spacing: { before: 180, after: 100 } } },
    ],
  },
  sections: [ /* ver abajo */ ],
});
```

Márgenes en DXA: 1417 ≈ 2,5 cm, 1134 ≈ 2 cm. A4 es el default de docx-js.

**Portada — usar fondo flotante, no una tabla.** El camino intuitivo (una tabla de una celda del
tamaño de la hoja con `shading`) **falla**: con una fila de altura casi-página, LibreOffice y Word
recortan cualquier imagen que esté dentro de la celda, y el logo aparece cortado a la mitad. El
método que funciona es una imagen de fondo flotante detrás del texto, con márgenes de página
normales:

```js
const fondoPortada = new Paragraph({ spacing: { after: 0 }, children: [ new ImageRun({
  type: 'png',
  data: fs.readFileSync(`${SKILL_DIR}/assets/fondo-portada-a4.png`),
  transformation: { width: 794, height: 1123 },     // A4 completo en px @96 ppp
  floating: {
    horizontalPosition: { relative: HorizontalPositionRelativeFrom.PAGE, offset: 0 },
    verticalPosition:   { relative: VerticalPositionRelativeFrom.PAGE,   offset: 0 },
    behindDocument: true, zIndex: 0,
  },
})] });
```

Va como **primer hijo** de la sección de portada; todo lo demás (logo, título, barra, datos,
slogan) son párrafos normales que se dibujan encima. El espaciado vertical se maneja con
`spacing: { before: N }`, no con párrafos vacíos.

**El interlineado del estilo base recorta las imágenes.** Si `styles.default` define
`spacing: { line: N }` sin `lineRule`, algunos visores lo tratan como alto exacto y recortan toda
imagen más alta que la línea — el síntoma es un logo cortado por la mitad, exactamente igual que
el bug anterior. Declará `lineRule: LineRuleType.AUTO` en el estilo base **y** en cada párrafo que
contenga una imagen:

```js
function logo(variante, ancho, after = 200) {
  return new Paragraph({
    spacing: { after, line: 240, lineRule: LineRuleType.AUTO },
    children: [ new ImageRun({
      type: 'png',
      data: fs.readFileSync(`${SKILL_DIR}/assets/logo-horizontal-${variante}.png`),
      transformation: { width: ancho, height: Math.round(ancho / 4.44) },
    })],
  });
}
```

**Barra de gradiente: usá el asset, no celdas.** Construirla con 24 celdas contiguas parece
razonable pero deja huecos visibles al renderizar. Insertá `assets/barra-gradiente.png` como
imagen y escalala:

```js
new Paragraph({ spacing: { after: 0, line: 240, lineRule: LineRuleType.AUTO },
  children: [ new ImageRun({ type: 'png',
    data: fs.readFileSync(`${SKILL_DIR}/assets/barra-gradiente.png`),
    transformation: { width: 300, height: 6 },   // 50:1, respetá la proporción
  })] })
```

**Tablas de contenido.** Encabezado con `shading` en `azulInstitucional` y texto blanco;
`tableHeader: true` en la primera fila para que se repita al cortar de página; zebra alternando
`PROCOM.zebra`; sin bordes verticales:

```js
borders: {
  top:    { style: BorderStyle.SINGLE, size: 4, color: PROCOM.linea },
  bottom: { style: BorderStyle.SINGLE, size: 4, color: PROCOM.linea },
  left:   { style: BorderStyle.NONE, size: 0, color: 'FFFFFF' },
  right:  { style: BorderStyle.NONE, size: 0, color: 'FFFFFF' },
  insideHorizontal: { style: BorderStyle.SINGLE, size: 2, color: PROCOM.linea },
  insideVertical:   { style: BorderStyle.NONE, size: 0, color: 'FFFFFF' },
}
```

Recordá: `columnWidths` en la tabla **y** `width` en cada celda, ambos en `WidthType.DXA`.

**Encabezado y pie** van en la sección del cuerpo, no en la de portada. Para alinear un texto a
izquierda y otro a derecha en la misma línea usá `tabStops` y un `\t`, nunca espacios de relleno:

```js
new Paragraph({
  tabStops: [{ type: 'right', position: 9639 }],
  border: { bottom: { style: BorderStyle.SINGLE, size: 4, color: PROCOM.linea, space: 4 } },
  children: [
    new TextRun({ text: 'PROCOM IT SOLUTIONS — Doing IT Better Every Day', font: FUENTE_CUERPO, size: 16, color: PROCOM.textoSuave }),
    new TextRun({ text: '\tPágina ', font: FUENTE_CUERPO, size: 16, color: PROCOM.textoSuave }),
    new TextRun({ children: [PageNumber.CURRENT], font: FUENTE_CUERPO, size: 16, color: PROCOM.textoSuave }),
    new TextRun({ text: ' de ', font: FUENTE_CUERPO, size: 16, color: PROCOM.textoSuave }),
    new TextRun({ children: [PageNumber.TOTAL_PAGES], font: FUENTE_CUERPO, size: 16, color: PROCOM.textoSuave }),
  ],
})
```

La portada cuenta como página 1, así que el cuerpo arranca en la 2.

---

## PPTX con pptxgenjs

```js
const pres = new pptxgen();
pres.layout = 'LAYOUT_16x9';          // 10" x 5.625" — fijalo ANTES de agregar slides
pres.defineSlideMaster({
  title: 'PROCOM_CONTENIDO',
  background: { color: PROCOM.blanco },
  objects: [
    { image: { path: `${SKILL_DIR}/assets/logo-horizontal-color.png`,
               x: 0.4, y: 5.0, w: 1.0, h: 1.0 / 4.44 } },
    { line: { x: 0.4, y: 0.95, w: 9.2, h: 0, line: { color: PROCOM.verdeTecnologico, width: 1 } } },
  ],
  slideNumber: { x: 9.3, y: 5.1, fontSize: 9, color: PROCOM.textoSuave, fontFace: FUENTE_CUERPO },
});
```

Puntos de fricción específicos:

- Hex **sin `#`** y sin alfa. `'#182C49'` corrompe el archivo.
- Portada y divisores: `slide.background = { path: '.../fondo-portada-16x9.png' }` o
  `{ color: PROCOM.azulInstitucional }`, con `logo-horizontal-blanco.png`.
- Título de slide: `x: 0.4, y: 0.35, w: 9.2, fontSize: 24, bold: true, fontFace: FUENTE_TITULO,
  color: PROCOM.azulInstitucional, isTextBox: true, margin: 0`.
- Barra de gradiente: pptxgenjs no soporta degradés. Insertá `assets/barra-gradiente.png` con
  `slide.addImage(...)`, o dibujá 24 rectángulos contiguos con `barraGradiente(24)`.
- No compartas un objeto de opciones entre dos `add*` — pptxgenjs lo muta.
- Gráficos: `chartColors: SERIES`, `showTitle: true`, `showValue: true`,
  `valGridLine: { color: PROCOM.linea, size: 1 }`, `catGridLine: { style: 'none' }`,
  `showLegend: false` con una sola serie.

---

## XLSX con openpyxl

Para cronogramas, matrices de riesgo, inventarios y tableros.

```python
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side

TITULO = Font(name="Sofia Sans", size=11, bold=True, color="FFFFFF")
CUERPO = Font(name="STEM", size=10, color="333333")
FONDO_HEADER = PatternFill("solid", start_color="182C49")
ZEBRA = PatternFill("solid", start_color="F4F6F8")
BORDE = Border(bottom=Side(style="thin", color="D9DEE3"))
```

- Congelá la fila de encabezado (`ws.freeze_panes = "A2"`).
- Ancho de columna explícito; nada de `#####`.
- Formato numérico argentino: `'#,##0.00'`, moneda `'"$"#,##0.00'`.
- Sin cuadrícula en hojas de presentación: `ws.sheet_view.showGridLines = False`.
- Semáforos con formato condicional usando los códigos de estado, no relleno manual.
- El logo se inserta con `openpyxl.drawing.image.Image`, anclado en `A1`, con las filas 1–4
  reservadas como cabecera.

---

## HTML y markdown

```css
:root {
  --procom-verde: #A1C623;          /* verde tecnológico — acento */
  --procom-verde-vision: #6AB333;
  --procom-verde-evolucion: #12A039;
  --procom-azul-profundo: #1166B0;
  --procom-azul-medio: #2B90CF;
  --procom-celeste: #29B0E6;
  --procom-negro: #1D1E1B;
  --procom-azul-institucional: #182C49;
  --procom-fondo-claro: #EAF4FA;
  --procom-texto: #333333;
  --procom-texto-suave: #6B7280;
  --procom-linea: #D9DEE3;
  --procom-zebra: #F4F6F8;
  --fuente-titulo: "Sofia Sans", "Archivo", "Roboto Condensed", "Arial Narrow", Arial, sans-serif;
  --fuente-cuerpo: "STEM", "Inter", "Roboto", Calibri, Arial, sans-serif;
}
body { font-family: var(--fuente-cuerpo); color: var(--procom-texto); line-height: 1.55; }
h1, h2, h3 { font-family: var(--fuente-titulo); color: var(--procom-azul-institucional); }
h1 { border-bottom: 2px solid var(--procom-verde); padding-bottom: .3em; }
h2 { color: var(--procom-azul-profundo); }
thead th { background: var(--procom-azul-institucional); color: #fff; font-family: var(--fuente-titulo); }
tbody tr:nth-child(even) { background: var(--procom-zebra); }
.barra-marca { height: 8px; background: linear-gradient(90deg, #6AB333, #1166B0, #182C49); }
.portada { background: linear-gradient(135deg, #1166B0, #182C49); color: #fff; }
```

Sofia Sans se puede traer de Google Fonts con un `<link>`. STEM es comercial: va siempre con
fallback.

En markdown puro no hay color: la identidad se sostiene con la estructura de secciones, el
encabezado institucional y el tono. No fuerces HTML dentro del markdown solo para pintar.

---

## Gantt

Elegí el soporte según para qué se usa:

| Necesidad | Soporte |
|---|---|
| El cliente va a actualizar avances | `.xlsx` con celdas coloreadas por formato condicional |
| Va dentro de una propuesta o informe | Imagen generada con matplotlib, insertada en el docx |
| Va en un deck | Barras nativas de pptxgenjs (rectángulos posicionados) o imagen |
| Vista web / interactiva | HTML + CSS grid |

Convención cromática, igual en todos los soportes:

| Elemento | Color |
|---|---|
| Barra de tarea planificada | `#1166B0` |
| Avance real (barra interna, ~60% de alto) | `#6AB333` |
| Camino crítico | `#2B90CF` |
| Hito | Rombo en `#A1C623` |
| Línea de hoy | Punteada, `#6B7280` |
| Fin de semana / no laborable | Fondo `#F4F6F8` |
| Etiqueta de tarea | STEM 9 pt, `#333333` |

Reglas: eje temporal arriba, tareas agrupadas por fase con la fase en Sofia Sans bold sobre fondo
`zebra`, dependencias con flecha fina gris solo si aportan (un Gantt de 40 flechas no se lee), y
siempre una columna previa con responsable.

Para matplotlib usar `barh` con `left=` en días desde el inicio y `ax.invert_yaxis()` para que la
primera tarea quede arriba. Sin bordes de eje salvo el inferior.

---

## Verificación final

Antes de entregar, renderizá y mirá el archivo. No lo des por bueno sin verlo:

```bash
python /mnt/skills/public/docx/scripts/office/soffice.py --headless --convert-to pdf salida.docx
pdftoppm -jpeg -r 100 salida.pdf pagina
```

Después leé las imágenes y chequeá: portada a sangre completa, logo sin deformar, colores
correctos, tablas sin cortes feos, encabezado y pie presentes, nada desbordado. Recordá que las
fuentes de marca no están instaladas en el entorno, así que el render local usa fallbacks —
evaluá maquetación, no tipografía.
