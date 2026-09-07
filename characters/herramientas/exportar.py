#!/usr/bin/env python3
"""Copia el arte y el catálogo a los assets de la app.

Son dos ficheros y nada más: el arte de Nouns tal cual viene del repositorio
oficial, sin tocar un byte, y el catálogo que dice qué rasgos se usan, cómo se
llaman en español y cuánto valen. La app no lleva ni un PNG.

    python3 herramientas/exportar.py
"""
import json
import pathlib
import shutil

RAIZ = pathlib.Path(__file__).resolve().parent.parent
DESTINO = RAIZ.parent / "app" / "assets" / "nouns"


def main() -> None:
    DESTINO.mkdir(parents=True, exist_ok=True)
    shutil.copy(RAIZ / "nouns" / "image-data.json", DESTINO / "image-data.json")

    # El catálogo va sin indentar: son 442 rasgos y en el APK cada byte cuenta.
    cat = json.loads((RAIZ / "catalogo.json").read_text("utf-8"))
    (DESTINO / "catalogo.json").write_text(
        json.dumps(cat, ensure_ascii=False, separators=(",", ":")), "utf-8")

    for f in sorted(DESTINO.iterdir()):
        print(f"{f.relative_to(RAIZ.parent)}  {f.stat().st_size / 1024:.0f} KB")


if __name__ == "__main__":
    main()
