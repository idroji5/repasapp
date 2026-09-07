#!/usr/bin/env python3
"""Lee el arte de Nouns: RLE on-chain -> píxeles.

Nouns no guarda PNG. Cada rasgo es una tira de bytes con la caja que ocupa y
después parejas (cuántos píxeles seguidos, qué color de la paleta). Así caben
450 dibujos en 151 KB, que es lo que permite meter la colección entera dentro
del APK sin un solo fichero de imagen.

    0x 00 | 02 1e 14 06 | 0500 0138 ...
       ^    ^^^^^^^^^^^   ^^^^ ^^^^
       |    arriba,       5 píxeles del color 0 (transparente),
       |    derecha,      1 del color 0x38...
       |    abajo,
       |    izquierda
       paleta (siempre 0)
"""
from __future__ import annotations

import json
import pathlib

LADO = 32  # el lienzo de un Noun

RAIZ = pathlib.Path(__file__).resolve().parent.parent
# El orden importa y es el de Nouns: el accesorio va sobre el cuerpo, la
# cabeza tapa el cuello y las gafas van encima de todo.
CAPAS = ["bodies", "accessories", "heads", "glasses"]


def cargar(ruta: pathlib.Path | None = None) -> dict:
    return json.loads((ruta or RAIZ / "nouns" / "image-data.json").read_text("utf-8"))


def _hex_a_rgb(h: str) -> tuple[int, int, int]:
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def pintar(datos: str, paleta: list[str], lienzo: list[list[tuple]]) -> None:
    """Pinta un rasgo encima del lienzo, respetando lo que ya había."""
    d = datos.removeprefix("0x")
    arriba, derecha, _abajo, izquierda = (int(d[i:i + 2], 16) for i in (2, 4, 6, 8))

    x, y = izquierda, arriba
    for i in range(10, len(d), 4):
        largo = int(d[i:i + 2], 16)
        color = int(d[i + 2:i + 4], 16)
        rgb = _hex_a_rgb(paleta[color]) if color else None  # el 0 es transparente

        # Un tramo puede seguir en la fila siguiente: en la cabeza de canguro
        # hay tres que lo hacen. Pintarlo entero en la misma fila es lo que
        # deja el dibujo escalonado, cada fila un poco más a la derecha.
        resto = largo
        while resto > 0:
            cabe = min(resto, derecha - x)
            if rgb is not None and 0 <= y < LADO:
                for k in range(cabe):
                    if 0 <= x + k < LADO:
                        lienzo[y][x + k] = (*rgb, 255)
            x += cabe
            resto -= cabe
            if x >= derecha:
                x = izquierda
                y += 1


def componer(datos: dict, rasgos: dict[str, int]) -> list[list[tuple]]:
    """Un Noun completo: fondo + cuerpo + accesorio + cabeza + gafas."""
    fondo = (*_hex_a_rgb(datos["bgcolors"][rasgos["bgcolors"]]), 255)
    lienzo = [[fondo] * LADO for _ in range(LADO)]
    for capa in CAPAS:
        pintar(datos["images"][capa][rasgos[capa]]["data"], datos["palette"], lienzo)
    return lienzo


def a_imagen(lienzo: list[list[tuple]], escala: int = 12):
    from PIL import Image
    img = Image.new("RGBA", (LADO, LADO))
    img.putdata([p for fila in lienzo for p in fila])
    # NEAREST y no otra cosa: cualquier suavizado convierte el píxel en papilla.
    return img.resize((LADO * escala, LADO * escala), Image.NEAREST)
