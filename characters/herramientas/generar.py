#!/usr/bin/env python3
"""Sortea Nouns y comprueba que las rarezas salen como se prometió.

Es el gemelo en Python de `app/lib/dominio/coleccion.dart`: sortea igual y
calcula las mismas probabilidades. Sirve para mirar el resultado en grande
antes de tocar la app y para verificar que "1 de cada 42" es verdad.

    python3 herramientas/generar.py -n 48 --contacto ejemplos/muestra.png
    python3 herramientas/generar.py --estadisticas 200000
"""
from __future__ import annotations

import argparse
import json
import math
import pathlib
import random
import sys
from collections import Counter

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import nouns  # noqa: E402

RAIZ = pathlib.Path(__file__).resolve().parent.parent
ORDEN = ["normal", "raro", "extra_raro", "especial"]


def cargar_catalogo() -> dict:
    return json.loads((RAIZ / "catalogo.json").read_text("utf-8"))


def pesos(rasgos: list[dict], masas: dict[str, float]) -> list[float]:
    """Reparte la masa de cada categoría entre los rasgos que la componen.

    Se reparte masa y no un peso por rasgo porque las capas tienen tamaños muy
    distintos: 23 gafas y 247 cabezas. Con un peso fijo por categoría, la
    cabeza especial saldría diez veces menos que las gafas especiales sin que
    nadie lo hubiera decidido.
    """
    cuantos = Counter(r["rareza"] for r in rasgos)
    crudo = [masas[r["rareza"]] / cuantos[r["rareza"]] for r in rasgos]
    total = sum(crudo)
    return [p / total for p in crudo]


def probabilidad_por_capa(cat: dict) -> dict[str, dict[str, float]]:
    """Cuánta probabilidad se lleva cada categoría en cada capa, ya normalizada."""
    fuera = {}
    for capa, rasgos in cat["capas"].items():
        ps = pesos(rasgos, cat["masas"])
        acumulado = {}
        for r, p in zip(rasgos, ps):
            acumulado[r["rareza"]] = acumulado.get(r["rareza"], 0.0) + p
        fuera[capa] = acumulado
    return fuera


def probabilidades(cat: dict) -> dict[str, float]:
    """La probabilidad exacta de cada rareza. Es el "1 de cada N" que ve el niño.

    La rareza de un Noun es la de su rasgo más raro, así que se calcula por
    acumulación: la de "hasta raro" menos la de "hasta normal" es la de "raro".
    """
    porcapa = probabilidad_por_capa(cat)
    fuera, anterior = {}, 0.0
    for i, rareza in enumerate(ORDEN):
        hasta = 1.0
        for capa in cat["capas"]:
            hasta *= sum(porcapa[capa].get(r, 0.0) for r in ORDEN[:i + 1])
        fuera[rareza] = hasta - anterior
        anterior = hasta
    return fuera


def tirar(cat: dict, azar: random.Random) -> dict:
    """Un Noun. Sin memoria: no depende del niño, del día ni de la actividad."""
    elegidos = {}
    for capa, rasgos in cat["capas"].items():
        elegidos[capa] = azar.choices(rasgos, pesos(rasgos, cat["masas"]))[0]
    rareza = max(elegidos.values(), key=lambda r: ORDEN.index(r["rareza"]))["rareza"]
    fondo = azar.randrange(cat["fondos"])
    return {
        "codigo": "-".join([str(fondo)] + [str(elegidos[c]["i"]) for c in nouns.CAPAS]),
        "nombre": elegidos["heads"]["nombre"],
        "rareza": rareza,
        "fondo": fondo,
        "rasgos": elegidos,
    }


def dibujar(noun: dict, datos: dict, escala: int = 12):
    indices = {c: noun["rasgos"][c]["i"] for c in nouns.CAPAS}
    indices["bgcolors"] = noun["fondo"]
    return nouns.a_imagen(nouns.componer(datos, indices), escala)


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("-n", type=int, default=1)
    p.add_argument("--semilla", type=int)
    p.add_argument("--contacto")
    p.add_argument("--estadisticas", type=int, metavar="N")
    args = p.parse_args()

    cat = cargar_catalogo()

    if args.estadisticas:
        azar = random.Random(1)
        cuenta = Counter(tirar(cat, azar)["rareza"] for _ in range(args.estadisticas))
        exactas = probabilidades(cat)
        print(f"{'rareza':12} {'teórico':>9} {'medido':>9}   se ve")
        for r in ORDEN:
            print(f"{r:12} {exactas[r]:8.2%} {cuenta[r] / args.estadisticas:9.2%}"
                  f"   1 de cada {round(1 / exactas[r])}")
        combos = cat["fondos"] * math.prod(len(v) for v in cat["capas"].values())
        print(f"combinaciones: {combos:,}")
        return

    azar = random.Random(args.semilla) if args.semilla is not None else random.SystemRandom()
    datos = nouns.cargar()
    nouns_ = [tirar(cat, azar) for _ in range(args.n)]

    if args.contacto:
        from PIL import Image
        cols = min(8, len(nouns_))
        filas = math.ceil(len(nouns_) / cols)
        lado = 96
        hoja = Image.new("RGBA", (cols * lado, filas * lado))
        for i, n in enumerate(nouns_):
            hoja.alpha_composite(dibujar(n, datos, 3), ((i % cols) * lado, (i // cols) * lado))
        ruta = RAIZ / args.contacto
        ruta.parent.mkdir(parents=True, exist_ok=True)
        hoja.save(ruta)
        print(f"{len(nouns_)} en {ruta.relative_to(RAIZ)}")

    if args.n <= 12:
        for n in nouns_:
            print(f"{n['codigo']:16} {n['rareza']:11} {n['nombre']}")


if __name__ == "__main__":
    main()
