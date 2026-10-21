---
name: marketing-procom
description: Piezas de marketing y redes sociales de PROCOM IT SOLUTIONS y su sub-marca LVM - imágenes para Instagram (historias, posts, collages de fotos de eventos, capacitaciones y workshops con partners), co-branding con logos de partners y textos para acompañarlas. Usar SIEMPRE que se pida una imagen, collage, placa, historia o post "para Instagram", "para redes", "para LinkedIn" o "para publicar", que se pida poner el logo de Procom, de LVM o de un partner sobre fotos, o adaptar una imagen existente a formato de red social, aunque no se nombre "marketing". Se combina con marca-procom, que manda en paleta, logos y voz.
---

# Marketing y redes — PROCOM IT SOLUTIONS

Esta skill cubre las piezas que salen a redes: qué formato usar, cómo componer fotos y logos, qué
revisar antes de publicar y cómo nombrar el archivo. Nació de una pieza real ya aprobada (collage de
un workshop de Cloudflare con el equipo LVM), y las reglas de abajo son las decisiones que se
tomaron en esa sesión, incluidas las que hubo que corregir.

**Relación con `marca-procom`:** esa skill es la fuente de paleta, tipografías, logos y voz. Leela
antes de armar cualquier pieza y usá sus archivos de `assets/`. Acá solo se agrega lo específico de
redes. Si las dos se contradicen, manda `marca-procom`.

## Formato por defecto

Cuando el pedido es "para Instagram" y no aclara más, la pieza es una **historia vertical 9:16 de
1080 × 1920 px**. Es una preferencia ya definida: no preguntes el formato, usalo. Cambiá
solo si el pedido nombra otro.

| Destino | Tamaño | Relación | Nota |
|---|---|---|---|
| **Historia / Reel (por defecto)** | 1080 × 1920 | 9:16 | Zonas de interfaz arriba y abajo |
| Post vertical de feed | 1080 × 1350 | 4:5 | El que más pantalla ocupa en el feed |
| Post cuadrado | 1080 × 1080 | 1:1 | |
| Post horizontal | 1080 × 566 | 1,91:1 | Evitarlo: se ve chico en el teléfono |

**Zonas de interfaz de la historia.** Instagram superpone el nombre de la cuenta en los ~250 px
superiores y la barra de respuesta en los ~250 px inferiores (hasta ~330 px en algunos teléfonos).
Ahí no va nada que importe: ni logos, ni texto, ni caras. Sí puede ir contenido prescindible (techo,
mesa, bordes de una foto). Por eso los logos van en el centro vertical y no en las esquinas.

Un collage apaisado no sirve para Instagram aunque se vea bien en pantalla: en el teléfono queda
como una tira angosta. Si llega una pieza horizontal para publicar, se recompone en vertical; no
alcanza con estirarla ni con agregarle bandas.

## Composición aprobada: collage de historia

```
┌───────────────┬─────────┐
│               │ foto 2  │
│    foto 1     ├─────────┤   mitad superior: grande a la izquierda
│   (3:4)       │ foto 3  │
├───────────────┴─────────┤
│ PROCOM   (LVM)  PARTNER │   franja blanca de logos, centro vertical
├─────────┬───────────────┤
│ foto 5  │               │
├─────────┤    foto 4     │   mitad inferior: espejada, grande a la derecha
│ foto 6  │   (3:4)       │
└─────────┴───────────────┘
```

- **Fotos grandes**: las dos que cuentan la historia (la que muestra las marcas juntas, la que
  tiene gente). Al ser 3:4, una foto vertical de celular entra sin recorte.
- **Fotos chicas**: detalles (merchandising, pantallas, material impreso). Se recortan a casi
  cuadrado, así que hay que elegir el punto de interés de cada una.
- **Franja de logos**: fondo blanco liso, de borde a borde, 1/8 del alto (240 px en 1920).
- **Separadores** blancos de 12 px entre fotos y en el borde.
- Con menos fotos el script se adapta: 2 por mitad van lado a lado, 1 ocupa todo el ancho.

### Logos en la franja

- **Orden fijo: Procom a la izquierda, la sub-marca o área al centro, el partner a la derecha.**
  Los tres centrados a la misma altura.
- El isotipo de LVM va en un círculo blanco que sobresale de la franja un 10 % por lado. Es el
  único elemento que pisa las fotos, y lo hace sobre el separador.
- Para Procom usá `logo-vertical-color.png` cuando hay tres logos (el espacio lateral es casi
  cuadrado) y `logo-horizontal-color.png` cuando hay uno o dos.
- Los logos van siempre sobre blanco liso, sin sombras, sin recolorear y escalados en proporción.
  Son las reglas de `marca-procom`, y aplican igual al logo del partner.
- **No poner logos en círculos encima de las fotos.** Se probó primero y tapaba contenido (un logo
  del partner impreso, parte del merchandising); obligó a reordenar fotos y achicar círculos. La
  franja resuelve eso de raíz.

### De dónde salen los logos

| Logo | Fuente |
|---|---|
| Procom | `assets/` de la skill `marca-procom` |
| LVM | `assets/lvm/` de `marca-procom` si existe; si no, el archivo `PROCOM_LVM_isotipo_color.png` del proyecto |
| Partner | El archivo oficial que pase el usuario o el kit de prensa del partner |

Nunca dibujes ni aproximes un logo. Si el del partner no está, pedilo. Si hay que avanzar igual, se
puede usar uno de un repositorio público de íconos, pero avisá de dónde salió y que conviene
reemplazarlo por el oficial antes de publicar: versiones viejas o de color apenas distinto son
comunes en esos repositorios.

## Generar el collage

Guardá este script como `collage_instagram.py` y corrélo. Necesita Pillow; para logos en SVG,
también `cairosvg`.

```python
#!/usr/bin/env python3
"""Collage de marca para Instagram: fotos arriba y abajo, franja blanca de logos al centro.

Uso:
  python3 collage_instagram.py --fotos f1.jpg f2.jpg ... --logos procom.png lvm.png partner.png \
      --circulo 2 --salida PROCOM_LVM_Collage_Tema_Story_2026-10-06.jpg --guia guia.jpg

- 2 a 6 fotos. Se reparten mitad arriba, mitad abajo. En una mitad con 3 fotos, la primera
  es la grande (3:4, sin recorte para fotos verticales) y las otras dos van apiladas.
- Punto de interes del recorte por foto: ruta@cx,cy (0 a 1). Ej: remera.jpg@0.5,0.25
- 1 a 3 logos, en orden izquierda -> derecha. --circulo N pone el logo N en un circulo
  blanco que sobresale de la franja (para isotipos cuadrados).
"""
import argparse
import math
from PIL import Image, ImageDraw, ImageOps


def abrir_logo(ruta, ancho_svg=2048):
    if ruta.lower().endswith(".svg"):
        try:
            import cairosvg
        except ImportError:
            raise SystemExit("Para logos SVG: pip install cairosvg --break-system-packages")
        import io
        return Image.open(io.BytesIO(cairosvg.svg2png(url=ruta, output_width=ancho_svg))).convert("RGBA")
    return Image.open(ruta).convert("RGBA")


def foto(lienzo, spec, caja):
    ruta, _, foco = spec.partition("@")
    cx, cy = (float(v) for v in foco.split(",")) if foco else (0.5, 0.5)
    x, y, w, h = caja
    im = ImageOps.exif_transpose(Image.open(ruta)).convert("RGB")
    lienzo.paste(ImageOps.fit(im, (w, h), Image.LANCZOS, centering=(cx, cy)), (x, y))


def mitad(lienzo, fotos, y, alto, ancho, g, espejo):
    """Dibuja 1, 2 o 3 fotos en una mitad. espejo=True pone la grande a la derecha."""
    util = ancho - 2 * g
    if len(fotos) == 1:
        foto(lienzo, fotos[0], (g, y, util, alto))
    elif len(fotos) == 2:
        w1 = (util - g) // 2
        foto(lienzo, fotos[0], (g, y, w1, alto))
        foto(lienzo, fotos[1], (g + w1 + g, y, util - w1 - g, alto))
    else:
        wg = round(alto * 3 / 4)            # foto grande 3:4
        wc = util - wg - g                  # columna de fotos chicas
        hc = (alto - g) // 2
        xg, xc = (g + wc + g, g) if espejo else (g, g + wg + g)
        foto(lienzo, fotos[0], (xg, y, wg, alto))
        foto(lienzo, fotos[1], (xc, y, wc, hc))
        foto(lienzo, fotos[2], (xc, y + hc + g, wc, alto - hc - g))


def pegar_logo(lienzo, ruta, cx, cy, max_w, max_h):
    lg = abrir_logo(ruta)
    lg = lg.crop(lg.getbbox())
    k = min(max_w / lg.width, max_h / lg.height)       # escala proporcional, nunca deformar
    lg = lg.resize((max(1, round(lg.width * k)), max(1, round(lg.height * k))), Image.LANCZOS)
    lienzo.paste(lg, (cx - lg.width // 2, cy - lg.height // 2), lg)


def pegar_circulo(lienzo, ruta, cx, cy, d):
    s = 4                                              # supermuestreo para borde limpio
    m = Image.new("L", (d * s, d * s), 0)
    ImageDraw.Draw(m).ellipse((0, 0, d * s - 1, d * s - 1), fill=255)
    m = m.resize((d, d), Image.LANCZOS)
    disco = Image.new("RGBA", (d, d), "white")
    lg = abrir_logo(ruta)
    if 0.9 <= lg.width / lg.height <= 1.1:             # isotipo cuadrado: conserva su propio aire
        lg = ImageOps.contain(lg, (d, d), Image.LANCZOS)
    else:
        lg = ImageOps.contain(lg.crop(lg.getbbox()), (round(d * 0.68), round(d * 0.68)), Image.LANCZOS)
    disco.alpha_composite(lg, ((d - lg.width) // 2, (d - lg.height) // 2))
    lienzo.paste(disco.convert("RGB"), (cx - d // 2, cy - d // 2), m)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--fotos", nargs="+", required=True)
    ap.add_argument("--logos", nargs="*", default=[])
    ap.add_argument("--circulo", type=int, default=0, help="posicion (1..3) del logo que va en circulo")
    ap.add_argument("--tamano", default="1080x1920", help="lienzo AnchoxAlto; historia 9:16 por defecto")
    ap.add_argument("--salida", required=True)
    ap.add_argument("--guia", help="guarda una copia con las zonas de interfaz de Instagram marcadas")
    ap.add_argument("--zona", type=int, default=250, help="alto en px de la zona de interfaz arriba y abajo")
    a = ap.parse_args()

    if not 2 <= len(a.fotos) <= 6:
        raise SystemExit("Se admiten de 2 a 6 fotos.")
    if len(a.logos) > 3:
        raise SystemExit("Se admiten hasta 3 logos.")
    W, H = (int(v) for v in a.tamano.lower().split("x"))
    g = round(W / 90)                                  # separador: 12 px en 1080
    franja = round(H / 8) if a.logos else g            # franja de logos: 240 px en 1920
    alto = (H - 2 * g - franja) // 2
    lienzo = Image.new("RGB", (W, H), "white")

    n_arriba = math.ceil(len(a.fotos) / 2)
    mitad(lienzo, a.fotos[:n_arriba], g, alto, W, g, espejo=False)
    mitad(lienzo, a.fotos[n_arriba:], g + alto + franja, alto, W, g, espejo=True)

    cy = H // 2
    d = round(franja * 1.2)                            # el circulo sobresale 10% de cada lado
    n = len(a.logos)
    if n == 3 and a.circulo == 2:
        lado = (W - d) // 2
        centros, max_w = [lado // 2, W // 2, W - lado // 2], round(lado * 0.73)
    elif n:
        centros, max_w = [round(W * (2 * i + 1) / (2 * n)) for i in range(n)], round(W / n * 0.73)
    for i, ruta in enumerate(a.logos):
        if a.circulo == i + 1:
            pegar_circulo(lienzo, ruta, centros[i], cy, d)
        else:
            pegar_logo(lienzo, ruta, centros[i], cy, max_w, round(franja * 0.625))

    lienzo.save(a.salida, quality=95, subsampling=0)
    print(f"OK {a.salida} {W}x{H} | franja {franja}px | mitades {alto}px")

    if a.guia:
        capa = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        dr = ImageDraw.Draw(capa)
        dr.rectangle((0, 0, W, a.zona), fill=(255, 0, 0, 70))
        dr.rectangle((0, H - a.zona, W, H), fill=(255, 0, 0, 70))
        Image.alpha_composite(lienzo.convert("RGBA"), capa).convert("RGB").save(a.guia, quality=85)


if __name__ == "__main__":
    main()
```

Ejemplo, la pieza aprobada:

```bash
python3 collage_instagram.py \
  --fotos notebook.jpg remera.jpg@0.5,0.45 slide.jpg@0.5,0.25 \
          presentador.jpg bloqueo.jpg@0.5,0.58 medias.jpg@0.5,0.58 \
  --logos logo-vertical-color.png PROCOM_LVM_isotipo_color.png cloudflare.svg --circulo 2 \
  --salida PROCOM_LVM_Collage_Cloudflare_Story_2026-10-06.jpg --guia guia.jpg
```

El orden de `--fotos` define la ubicación: la primera de cada mitad es la grande. `ruta@cx,cy`
mueve el recorte hacia el punto de interés (0 a 1; `0.5,0.25` deja visible la parte de arriba).

**Mirá siempre el resultado antes de entregarlo**, y también la `--guia`, que marca en rojo las
zonas de interfaz. Lo que hay que comprobar: que ningún logo, texto o cara caiga en rojo, que los
recortes de las fotos chicas no corten el objeto, y que el círculo no tape nada relevante. Si algo
falla, se corrige reordenando fotos o cambiando el foco del recorte, no achicando logos.

Para otra composición (una sola foto con logos, una placa con texto), el script sirve como base:
las funciones `pegar_logo` y `pegar_circulo` ya respetan las reglas de marca.

## Revisión antes de publicar

Las fotos de eventos y capacitaciones casi siempre incluyen pantallas. Antes de entregar una pieza
para redes, revisá cada foto y avisale al usuario lo que encuentres:

- **Pantallas**: URLs, IDs de sesión, barra de marcadores, nombres de clientes o de carpetas
  internas, direcciones IP, pestañas abiertas, notificaciones.
- **Personas**: si hay alguien identificable, recordá que conviene tener su conformidad.
- **Marcas de terceros** que no son parte de la pieza (otros proveedores, stickers, el fabricante
  del monitor).

Si algo sensible se puede dejar afuera con el recorte, hacelo y contalo. Si queda visible, decilo
de forma concreta ("el ID de sesión del cartel sigue visible") y ofrecé recortar o difuminar. No lo
borres por tu cuenta si cambia lo que muestra la foto.

## Texto que acompaña la pieza

Si se pide el texto del post o de la historia, la voz es la de `marca-procom`: partner tecnológico,
frases cortas, concreto, sin adjetivos de relleno. En redes corresponde el "nosotros" institucional.

- Contá qué pasó y para qué le sirve al cliente, no solo que hubo un evento.
- Nombrá al partner y al área de Procom involucrada.
- El slogan `Doing IT Better Every Day` va en inglés y sin modificar, como remate, no en cada pieza.
- Cuenta de Instagram: `@procomitsolutions`.
- Contacto del equipo LVM en piezas institucionales: `lvm@procomitsolutions.com`.
- No inventes hashtags oficiales, cuentas de partners, cifras ni fechas. Lo que no esté confirmado
  va como `[COMPLETAR: …]`.

## Archivo de salida

- JPG, sRGB, calidad 95, 1080 px de ancho. Instagram recomprime, así que no tiene sentido subir más
  resolución, y sí conviene partir de un archivo limpio.
- Nombre: `PROCOM_[Area]_[Tipo]_[Tema]_[Formato]_[AAAA-MM-DD].jpg`, sin espacios ni acentos.
  `Formato`: `Story`, `Post4x5`, `Post1x1`. Ejemplo:
  `PROCOM_LVM_Collage_Cloudflare_Story_2026-10-06.jpg`.
- La fecha es la del evento, no la del día en que se arma la pieza.

## Lista de control

1. Formato correcto para el destino (historia 9:16 si no se aclaró).
2. Nada importante en los 250 px de arriba ni de abajo.
3. Logos oficiales, en orden Procom / área / partner, misma altura, sobre blanco, sin deformar.
4. Fotos revisadas por datos sensibles y personas; hallazgos avisados.
5. Resultado mirado en imagen, no solo generado.
6. Nombre de archivo según la convención.
7. Si se usó un logo de partner no oficial, dicho en la entrega.
