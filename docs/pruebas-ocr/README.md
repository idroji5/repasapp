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

**Dictado en letra ligada.** Aquí se rompe. De trece palabras, cinco
destrozadas:

```
En la hoja: Ayer cayó una tormenta muy fuerte.  Mi madre cerró la ventana...
ML Kit:     yer  cayó na  tomnta   muy unte     Mi madu  cernó la ventana...
```

Corregir eso tal cual sería acusar al niño de cinco faltas que no cometió.

**Operaciones.** ML Kit falló dos dígitos, los dos el mismo error: leyó `416`
como `446` y `11651` como `11654`. Siempre confunde el 1 con el 4.

## La conclusión que importa

ML Kit sirve con **letra de imprenta y números**, y no sirve con **letra
ligada**. Como no se puede exigir a un niño que escriba de una forma concreta,
la app no puede fiarse ciegamente de lo que lee.

La señal que las distingue resultó ser fiable: un niño falla de maneras con
nombre —una tilde, una b por una uve, una hache que se deja—, mientras que un
mal reconocimiento devuelve palabras que no encajan en ninguna regla. Cuando la
mayoría de las faltas no tienen regla, la app deja de puntuar y enseña lo que ha
leído para que se corrija.

## Aviso sobre la validez de estas pruebas

Estas imágenes NO son letra de un niño: son una ilustración de escritura a mano,
más regular y mejor contrastada que un lápiz de verdad sobre papel arrugado.
Sirven para DESCARTAR (si ML Kit falla aquí, el enfoque no se sostiene), no para
CONFIRMAR. La prueba que decide sigue siendo una hoja real fotografiada con un
móvil.
