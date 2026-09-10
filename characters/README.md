# characters/ — la colección de RepasApp

Al terminar las tres actividades del día, el niño se lleva un **Noun**: un
dibujo de píxeles distinto cada vez, elegido al azar entre 48 millones.

```
2 fondos x 30 cuerpos x 142 accesorios x 247 cabezas x 23 gafas
= 48.402.120
```

Esta carpeta es el taller: de aquí sale lo que la app se lleva dentro. Ver
[ATRIBUCION.md](ATRIBUCION.md) para de dónde viene el arte y qué se ha dejado
fuera.

## Cómo está montado

```
nouns/image-data.json   El arte de Nouns, del repositorio oficial, sin tocar.
catalogo.json           Lo que pone RepasApp: qué rasgos se usan, cómo se
                        llaman en español y de qué rareza es cada uno.
herramientas/
  nouns.py              Descomprime el RLE de la cadena de bloques a píxeles.
  catalogo.py           Construye catalogo.json. Aquí se decide la rareza.
  generar.py            Sortea Nouns y comprueba el reparto de rarezas.
  exportar.py           Copia los dos ficheros a app/assets/nouns/.
```

```
python3 herramientas/catalogo.py                  # rehacer el catálogo
python3 herramientas/generar.py --estadisticas 200000
python3 herramientas/generar.py -n 48 --contacto ejemplos/muestra.png
python3 herramientas/exportar.py                  # llevarlo a la app
```

`generar.py` es el gemelo en Python de `app/lib/dominio/coleccion.dart`:
sortea igual y calcula las mismas probabilidades. Sirve para mirar el
resultado en grande sin abrir la app, y para que si uno de los dos se
equivoca, se note.

## Ni un PNG

El arte no son imágenes. Cada rasgo es una tira de bytes con la caja que ocupa
y después parejas de (cuántos píxeles seguidos, qué color de la paleta):

```
0x 00 | 05 1a 14 06 | 0500 0138 0200 ...
   ^    ^^^^^^^^^^^   ^^^^ ^^^^
   |    arriba,       5 píxeles del color 0 (transparente),
   |    derecha,      1 del color 0x38...
   |    abajo,
   |    izquierda
   paleta
```

Así caben 442 dibujos en 148 KB, y la app reconstruye cualquiera de los 48
millones de Nouns sin conexión y sin un solo fichero de imagen. Un Noun
guardado en la base de datos ocupa lo que ocupa su código —`1-9-5-113-3`—, de
manera que la colección de un año entero son unos kilobytes.

Un detalle que cuesta descubrir: **un tramo puede seguir en la fila
siguiente**. En la cabeza de canguro hay tres que lo hacen. Pintarlo entero en
la misma fila deja el dibujo escalonado, cada fila un poco más a la derecha, y
como el resultado casi se reconoce, es fácil pensar que el fallo está en otro
sitio.

## Las rarezas

Nouns no tiene: sus diez mil se sortearon con todos los rasgos igual de
probables. Las cuatro que ve el niño las pone esta app, y las llevan las tres
capas que se reconocen de un vistazo —el color del cuerpo, la cabeza y las
gafas—, no los accesorios, que son estampados de camiseta.

| Rareza | Sale | Con un premio al día |
|---|---|---|
| Normal | 70 % | — |
| Raro | 1 de cada 5 | dos veces por semana |
| Extra raro | 1 de cada 12 | cada dos semanas |
| Especial | 1 de cada 50 | cada mes y medio |

Esa columna del medio **no se le enseña al niño en ningún sitio**. De un cromo
se dice lo que es, no lo que cuesta: un número al lado del nombre lo convierte
en una cotización. Se sigue calculando porque es lo que demuestra que las
cuatro categorías son honradas.

## El nombre de cada cromo

Nouns no pone nombre a los suyos: se llaman "Noun 1042". Un número no se dice
en voz alta ni se cambia en el patio, así que cada cromo tiene el suyo:
**Kadavuyu, Munumoga, Vinemano, Prepepodo.**

Sale de sus cinco rasgos y de nada más, y no hay dos cromos que compartan uno.
El número del cromo se escribe en base 85 —17 consonantes por 5 vocales,
cuatro sílabas— porque 85⁴ = 52.200.625 y cromos hay 50.124.360.

Antes de convertirlo se multiplica por 3¹⁷, que sigue siendo una biyección
porque no comparte factores con 85⁴ = 5⁴·17⁴. Sin ese paso, dos cromos que
solo se diferencian en el fondo salen con palabras casi idénticas y el nombre
deja de servir para distinguirlos de un vistazo.

Los números están elegidos por lo que se le acaba diciendo al niño. Un reparto
más generoso daba "raro: 1 de cada 3", y una palabra que significa "casi
siempre" no vale para nada.

La rareza de un Noun es la de su rasgo más raro, y el "1 de cada N" se calcula,
no se estima: `herramientas/generar.py --estadisticas` compara la fórmula con
200.000 tiradas, y `app/test/coleccion_test.dart` hace lo mismo en Dart.

## En la app

| Dónde | Qué |
|---|---|
| `lib/dominio/coleccion.dart` | El arte, el sorteo, las rarezas y el nombre de cada cromo |
| `lib/ui/widgets/cromo.dart` | El cromo: marco, sello y sus cinco características |
| `lib/ui/widgets/sala.dart` | El cuarto oscuro: la rejilla y el foco de la rareza |
| `lib/datos/repositorio.dart` | `premioDelDia`, `nounDeHoy`, `coleccion` |
| `lib/datos/bd.dart` | La tabla `nouns` y la migración de la v1 |
| `lib/ui/widgets/noun.dart` | Dibujar un Noun |
| `lib/ui/widgets/sorpresa.dart` | La caja que hay que abrir |
| `lib/ui/pantallas/premio.dart` | El premio, al acabar el día |
| `lib/ui/pantallas/coleccion.dart` | El álbum |

El premio se gana **al corregir la última de las tres actividades del día**, y
solo uno por día: lo garantiza un índice único sobre (niño, día) en la base de
datos, no el código de la app.

El sorteo no mira quién es el niño, qué día es ni cómo le ha ido. Es
deliberado: si el dibujo dependiera de lo bien que ha salido el dictado,
dejaría de ser un premio y sería otra nota más, y el día que peor lo pasa es
justo el que más falta le hace terminar.
