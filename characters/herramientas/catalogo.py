#!/usr/bin/env python3
"""Construye `catalogo.json`: qué rasgos se usan, cómo se llaman y cuánto valen.

Nouns no tiene rarezas —todos sus rasgos salen con la misma probabilidad—, así
que las cuatro categorías que ve el niño se deciden aquí. La rareza no la
llevan los accesorios, que son estampados de camiseta y no se distinguen a
simple vista, sino las tres capas que sí se reconocen de un vistazo: el color
del cuerpo, la cabeza y las gafas.

    python3 herramientas/catalogo.py
"""
from __future__ import annotations

import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import nouns  # noqa: E402

RAIZ = pathlib.Path(__file__).resolve().parent.parent

# --- lo que se queda fuera ----------------------------------------------
# Nouns se dibujó para una comunidad de adultos. Esto es una app de deberes
# para niños de 6 a 12, así que el alcohol, las drogas y la sangre no entran.
FUERA = {
    "heads": ["beer", "wine", "wine-barrel", "weed", "peyote", "pipe", "pill"],
    "accessories": ["stains-blood"],
    "bodies": [],
    "glasses": [],
}

# --- rareza --------------------------------------------------------------
# Cuánta probabilidad se lleva cada categoría DENTRO de una capa. Repartido
# entre las tres capas que la llevan sale: normal 70 %, raro 20 %,
# extra raro 8 %, especial 2 %.
#
# Los números están elegidos por lo que se le acaba diciendo al niño, que es
# "sale 1 de cada N": raro 1 de cada 5, extra raro 1 de cada 12, especial 1 de
# cada 50. Con un premio al día eso es algo bueno dos veces por semana, algo
# muy bueno cada dos semanas y algo especial cada mes y medio. Un reparto más
# generoso daba "raro: 1 de cada 3", y una palabra que significa "casi
# siempre" no vale para nada.
MASAS = {"normal": 0.8879, "raro": 0.0776, "extra_raro": 0.0278, "especial": 0.0067}

RAREZAS = {
    "glasses": {
        "especial": ["square-black-rgb"],
        "extra_raro": ["hip-rose", "square-black-eyes-red"],
        "raro": ["deep-teal", "grass", "square-fullblack", "square-watermelon",
                 "square-green-blue-multi", "square-pink-purple-multi",
                 "square-yellow-orange-multi"],
    },
    "bodies": {
        "especial": ["gold"],
        "extra_raro": ["bege-bsod", "computerblue"],
        "raro": ["bege-crt", "gunk", "slimegreen", "cold", "grayscale-1"],
    },
    "heads": {
        "especial": ["crown", "queencrown", "faberge", "goldcoin", "void"],
        "extra_raro": ["blackhole", "ufo", "unicorn", "ghost-B", "undead",
                       "werewolf", "skeleton-hat", "dino", "robot", "turing",
                       "rainbow", "jupiter", "saturn", "earth", "moon"],
        # Los bichos. Son los que un niño reconoce y nombra sin dudar, así que
        # son los que tienen que sentirse como un hallazgo.
        "raro": ["aardvark", "ape", "bat", "bear", "bigfoot", "bigfoot-yeti",
                 "cat", "chameleon", "chicken", "cow", "crab", "croc-hat",
                 "dog", "duck", "ducky", "flamingo", "fox", "frog", "goat",
                 "goldfish", "grouper", "jellyfish", "kangaroo", "moose",
                 "mosquito", "mouse", "orangutan", "orca", "otter", "owl",
                 "oyster", "panda", "pufferfish", "rabbit", "raven", "scorpion",
                 "shark", "squid", "whale", "whale-alive", "zebra", "capybara",
                 "beluga", "tiger", "green-snake", "shrimp-tempura", "gnome"],
    },
    "accessories": {},
}

# --- nombres --------------------------------------------------------------
# La cabeza da nombre al Noun ("un Panda", "una Pizza"), así que están las 247.
# De cuerpos y gafas solo hace falta poder decir qué rasgo es el raro.
NOMBRES_CABEZAS = {
 "aardvark":"oso hormiguero","abstract":"abstracto","ape":"simio","bag":"bolsa",
 "bagpipe":"gaita","banana":"plátano","bank":"banco","baseball-gameball":"pelota de béisbol",
 "basketball":"balón de baloncesto","bat":"murciélago","bear":"oso","beet":"remolacha",
 "bell":"campana","bigfoot-yeti":"yeti","bigfoot":"pie grande","blackhole":"agujero negro",
 "blueberry":"arándano","bomb":"bomba","bonsai":"bonsái","boombox":"radiocasete",
 "boot":"bota","box":"caja","boxingglove":"guante de boxeo","brain":"cerebro",
 "bubble-speech":"bocadillo","bubblegum":"chicle","burger-dollarmenu":"hamburguesa",
 "cake":"tarta","calculator":"calculadora","calendar":"calendario","camcorder":"cámara de vídeo",
 "cannedham":"lata de jamón","car":"coche","cash-register":"caja registradora",
 "cassettetape":"casete","cat":"gato","cd":"cedé","chain":"cadena","chainsaw":"motosierra",
 "chameleon":"camaleón","chart-bars":"gráfico de barras","cheese":"queso",
 "chefhat":"gorro de cocinero","cherry":"cereza","chicken":"gallina","chilli":"guindilla",
 "chipboard":"placa de circuitos","chips":"patatas fritas","chocolate":"chocolate",
 "cloud":"nube","clover":"trébol","clutch":"bolso de mano","coffeebean":"grano de café",
 "cone":"cono","console-handheld":"consola","cookie":"galleta","cordlessphone":"teléfono",
 "cottonball":"bola de algodón","cow":"vaca","crab":"cangrejo","crane":"grúa",
 "croc-hat":"cocodrilo","crown":"corona","crt-bsod":"pantallazo azul",
 "crystalball":"bola de cristal","diamond-blue":"diamante azul","diamond-red":"diamante rojo",
 "dictionary":"diccionario","dino":"dinosaurio","dna":"adn","dog":"perro","doughnut":"dónut",
 "drill":"taladro","duck":"pato","ducky":"patito de goma","earth":"la Tierra","egg":"huevo",
 "faberge":"huevo Fabergé","factory-dark":"fábrica","fan":"ventilador","fence":"valla",
 "film-35mm":"carrete","film-strip":"tira de película","fir":"abeto",
 "firehydrant":"boca de incendios","flamingo":"flamenco","flower":"flor","fox":"zorro",
 "frog":"rana","garlic":"ajo","gavel":"mazo de juez","ghost-B":"fantasma",
 "glasses-big":"gafotas","gnome":"gnomo","goat":"cabra","goldcoin":"moneda de oro",
 "goldfish":"pez de colores","grouper":"mero","hair":"pelo","hardhat":"casco de obra",
 "heart":"corazón","helicopter":"helicóptero","highheel":"tacón","hockeypuck":"disco de hockey",
 "horse-deepfried":"caballo","hotdog":"perrito caliente","house":"casa","icepop-b":"polo",
 "igloo":"iglú","island":"isla","jellyfish":"medusa","jupiter":"Júpiter","kangaroo":"canguro",
 "ketchup":"kétchup","laptop":"portátil","lightning-bolt":"rayo","lint":"pelusa",
 "lips":"labios","lipstick2":"pintalabios","lock":"candado","macaroni":"macarrones",
 "mailbox":"buzón","maze":"laberinto","microwave":"microondas","milk":"leche","mirror":"espejo",
 "mixer":"batidora","moon":"la Luna","moose":"alce","mosquito":"mosquito",
 "mountain-snowcap":"montaña nevada","mouse":"ratón","mug":"taza","mushroom":"seta",
 "mustard":"mostaza","nigiri":"nigiri","noodles":"fideos","onion":"cebolla",
 "orangutan":"orangután","orca":"orca","otter":"nutria","outlet":"enchufe","owl":"búho",
 "oyster":"ostra","paintbrush":"pincel","panda":"panda","paperclip":"clip","peanut":"cacahuete",
 "pencil-tip":"punta de lápiz","piano":"piano","pickle":"pepinillo","pie":"tarta de manzana",
 "piggybank":"hucha","pillow":"almohada","pineapple":"piña","pirateship":"barco pirata",
 "pizza":"pizza","plane":"avión","pop":"refresco","porkbao":"bollo bao","potato":"patata",
 "pufferfish":"pez globo","pumpkin":"calabaza","pyramid":"pirámide","queencrown":"corona de reina",
 "rabbit":"conejo","rainbow":"arcoíris","rangefinder":"cámara de fotos","raven":"cuervo",
 "retainer":"aparato de dientes","rgb":"rgb","ring":"anillo","road":"carretera","robot":"robot",
 "rock":"piedra","rosebud":"capullo de rosa","ruler-triangular":"escuadra","saguaro":"cactus",
 "sailboat":"velero","sandwich":"sándwich","saturn":"Saturno","saw":"sierra",
 "scorpion":"escorpión","shark":"tiburón","shower":"ducha","skateboard":"monopatín",
 "skeleton-hat":"esqueleto","skilift":"telesilla","smile":"sonrisa","snowglobe":"bola de nieve",
 "snowmobile":"moto de nieve","spaghetti":"espaguetis","sponge":"esponja","squid":"calamar",
 "stapler":"grapadora","star-sparkles":"estrella","steak":"filete","sunset":"atardecer",
 "taco-classic":"taco","taxi":"taxi","thumbsup":"pulgar arriba","toaster":"tostadora",
 "toiletpaper-full":"papel higiénico","tooth":"diente","toothbrush-fresh":"cepillo de dientes",
 "tornado":"tornado","trashcan":"cubo de basura","turing":"Turing","ufo":"ovni","undead":"zombi",
 "unicorn":"unicornio","vent":"rejilla","void":"el vacío","volcano":"volcán",
 "volleyball":"balón de voleibol","wall":"muro","wallet":"cartera","wallsafe":"caja fuerte",
 "washingmachine":"lavadora","watch":"reloj","watermelon":"sandía","wave":"ola","weight":"pesa",
 "werewolf":"hombre lobo","whale-alive":"ballena","whale":"ballena varada",
 "wizardhat":"sombrero de mago","zebra":"cebra","capybara":"capibara","couch":"sofá",
 "hanger":"percha","index-card":"ficha","snowman":"muñeco de nieve",
 "treasurechest":"cofre del tesoro","vending-machine":"máquina expendedora","backpack":"mochila",
 "beanie":"gorro de lana","beluga":"beluga","cotton-candy":"algodón de azúcar",
 "curling-stone":"piedra de curling","fax-machine":"fax","satellite":"satélite","tiger":"tigre",
 "tuba":"tuba","sand-castle":"castillo de arena","shrimp-tempura":"gamba en tempura",
 "green-snake":"serpiente verde",
}

NOMBRES_CUERPOS = {
 "bege-bsod":"pantallazo azul","bege-crt":"pantalla antigua","blue-sky":"azul cielo",
 "bluegrey":"azul grisáceo","cold":"azul frío","computerblue":"azul ordenador",
 "darkbrown":"marrón oscuro","darkpink":"rosa oscuro","foggrey":"gris niebla","gold":"dorado",
 "grayscale-1":"casi negro","grayscale-7":"gris","grayscale-8":"gris claro",
 "grayscale-9":"casi blanco","green":"verde","gunk":"verde pringue","hotbrown":"marrón cálido",
 "magenta":"magenta","orange-yellow":"naranja amarillo","orange":"naranja","peachy-B":"melocotón",
 "peachy-a":"melocotón claro","purple":"morado","red":"rojo","redpinkish":"rojo rosado",
 "rust":"óxido","slimegreen":"verde slime","teal-light":"turquesa claro","teal":"turquesa",
 "yellow":"amarillo",
}

NOMBRES_GAFAS = {
 "hip-rose":"rosa moderno","square-black-eyes-red":"negras de ojos rojos",
 "square-black-rgb":"negras rgb","square-black":"negras",
 "square-blue-med-saturated":"azules","square-blue":"azul intenso",
 "square-frog-green":"verde rana","square-fullblack":"totalmente negras",
 "square-green-blue-multi":"verde y azul","square-grey-light":"gris claro",
 "square-guava":"guayaba","square-honey":"miel","square-magenta":"magenta",
 "square-orange":"naranjas","square-pink-purple-multi":"rosa y morado","square-red":"rojas",
 "square-smoke":"ahumadas","square-teal":"turquesas","square-watermelon":"sandía",
 "square-yellow-orange-multi":"amarillo y naranja","square-yellow-saturated":"amarillas",
 "deep-teal":"turquesa profundo","grass":"verde hierba",
}

NOMBRES = {"heads": NOMBRES_CABEZAS, "bodies": NOMBRES_CUERPOS, "glasses": NOMBRES_GAFAS}
PREFIJO = {"heads": "head-", "bodies": "body-", "glasses": "glasses-",
           "accessories": "accessory-"}


def construir() -> dict:
    datos = nouns.cargar()
    capas = {}
    for capa in nouns.CAPAS:
        rarezas = RAREZAS[capa]
        nombres = NOMBRES.get(capa, {})
        rasgos = []
        for i, pieza in enumerate(datos["images"][capa]):
            corto = pieza["filename"].removeprefix(PREFIJO[capa])
            if corto in FUERA[capa]:
                continue
            rareza = next((r for r, l in rarezas.items() if corto in l), "normal")
            rasgos.append({"i": i, "clave": corto,
                           "nombre": nombres.get(corto, corto), "rareza": rareza})
        # Un nombre sin traducir se vería tal cual en la pantalla del niño.
        # Se mira si la clave está en el diccionario, no si el texto cambió:
        # "magenta" se dice igual en las dos lenguas y no es un olvido.
        faltan = [r["clave"] for r in rasgos
                  if capa in NOMBRES and r["clave"] not in nombres]
        assert not faltan, f"{capa} sin traducir: {faltan}"
        # Una rareza mal escrita dejaría la categoría vacía y el reparto roto.
        for r, lista in rarezas.items():
            claves = {x["clave"] for x in rasgos}
            assert not (set(lista) - claves), f"{capa}/{r}: {set(lista) - claves}"
        capas[capa] = rasgos
    return {"masas": MASAS, "fondos": len(datos["bgcolors"]), "capas": capas}


def main() -> None:
    cat = construir()
    (RAIZ / "catalogo.json").write_text(
        json.dumps(cat, ensure_ascii=False, indent=1) + "\n", "utf-8")

    combos = cat["fondos"]
    for capa, rasgos in cat["capas"].items():
        reparto = {}
        for r in rasgos:
            reparto[r["rareza"]] = reparto.get(r["rareza"], 0) + 1
        combos *= len(rasgos)
        print(f"{capa:12} {len(rasgos):4}  {reparto}")
    print(f"combinaciones: {combos:,}")


if __name__ == "__main__":
    main()
