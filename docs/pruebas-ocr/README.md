# Hojas de prueba del OCR

Imágenes generadas con ChatGPT que imitan la letra de un niño de Primaria, usadas
para medir qué lee ML Kit y en qué se rompe la interpretación.

| Hoja | Qué mide |
|---|---|
| `01-dictado-imprenta-limpio.png` | Reconocimiento de texto correcto en letra de imprenta |
| `02-dictado-ligada-limpio.jpg` | Lo mismo en letra ligada, que es el caso difícil |
| `03-dictado-con-faltas.jpg` | La cadena completa: leer las faltas y clasificarlas |
| `04-operaciones-linea.jpg` | Emparejar cinco operaciones con lo dictado |

## Lo medido en un dispositivo real

**Dictado, letra de imprenta.** 12 de 13 palabras. Único fallo: leyó `fuerte`
como `tuerte`. Las tres tildes (`cayó`, `cerró`, `salón`) salieron bien, que es
lo que más importa: media app enseña reglas de acentuación.

**Dictado con faltas.** Transcripción perfecta, letra por letra, conservando
`cayo`, `mui`, `zerro`, `bentana` y `salon`. La app detectó las cinco y las
explicó bien.

**Operaciones.** ML Kit falló dos dígitos, los dos el mismo error: leyó `416`
como `446` y `11651` como `11654`. Siempre confunde el 1 con el 4.

## Aviso sobre la validez de estas pruebas

Estas imágenes NO son letra de un niño: son una ilustración de escritura a mano,
más regular y mejor contrastada que un lápiz de verdad sobre papel arrugado.
Sirven para DESCARTAR (si ML Kit falla aquí, el enfoque no se sostiene), no para
CONFIRMAR. La prueba que decide sigue siendo una hoja real fotografiada con un
móvil.
