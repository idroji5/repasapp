# RepasApp

App audio-first para que niños de Primaria repasen sus asignaturas: **escuchan,
trabajan en papel, y solo usan el móvil** para iniciar la actividad, pedir
repeticiones y corregirse al terminar.

**Todo funciona en local.** No hay servidor, ni cuenta, ni conexión, ni cámara:
el contenido, la voz y los datos viven en el dispositivo de la familia.

## Descargar

APK firmado, listo para instalar en Android (hay que permitir "instalar de
orígenes desconocidos" la primera vez):

| Descarga | Para |
|---|---|
| [**RepasApp-arm64-v8a.apk**](https://github.com/idroji5/repasapp/releases/latest/download/RepasApp-arm64-v8a.apk) (17 MB) | Casi cualquier móvil de los últimos años |
| [RepasApp-armeabi-v7a.apk](https://github.com/idroji5/repasapp/releases/latest/download/RepasApp-armeabi-v7a.apk) (14 MB) | Móviles antiguos de 32 bits |
| [RepasApp-universal.apk](https://github.com/idroji5/repasapp/releases/latest/download/RepasApp-universal.apk) (48 MB) | Si las anteriores dan error de compatibilidad |

Todas las versiones en [Releases](https://github.com/idroji5/repasapp/releases).

## Decisiones de producto

| Decisión | Valor |
|---|---|
| Edad objetivo | 6–12 (Primaria). Contenido del MVP: 3.º–6.º |
| Currículo | España (LOMLOE), indexado por **microdestreza**, no por curso |
| Idiomas | Castellano. La arquitectura admite añadir catalán e inglés |
| Contenido | Matemáticas: generador determinista de cuentas y problemas. Dictado: banco curado a mano |
| Feedback | Pistas antes que solución (configurable por el padre) |
| Zona de padres | Sí, protegida con PIN |
| Sesión diaria | "N minutos al día" → plan generado automáticamente |
| Nivel | 1–5 **independiente por asignatura**, con autoajuste |
| Voz | Motor del propio teléfono (`flutter_tts`), es-ES, voz femenina si la hay |
| Dictado | Cada frase se lee **dos veces**, la segunda más despacio |
| Ritmo | Al dictar se calla entre palabra y palabra; lo que se explica va a ritmo de conversación |
| Al fallar | Se puede **volver a hacer** lo que ha salido mal, ahí mismo |
| Repetir | Cualquier actividad del día se puede repetir tocándola; no cuenta para el nivel |
| Corrección | El niño toca lo que ha fallado sobre la solución en pantalla |
| Cámara | **No se usa.** [Por qué](docs/por-que-no-hay-ocr/README.md) |

## Arquitectura

```
app/lib/
  contenido/    Qué se le plantea al niño
    numeros.dart      742 → "setecientos cuarenta y dos"
    dictados.dart     Banco de dictados revisados a mano
    generador.dart    Azar determinista y piezas comunes de los ejercicios
    matematicas.dart  Generador de cuentas + narración paso a paso
    problemas.dart    Problemas con enunciado ("Ana compra 3 cajas de 12…")
  dominio/      Las reglas, sin depender de nada
    curriculo.dart    Microdestrezas y en qué curso se introducen
    niveles.dart      Cuándo sube o baja el nivel de una asignatura
    planificador.dart "15 minutos" → sesión concreta, variada por familias
    guion.dart        Qué dice la voz, cuánto calla, qué espera
    actividades.dart  Construye el guion de cada tipo de actividad
  correccion/   Qué hizo el niño
    ortografia.dart   Qué regla se juega en cada palabra y cómo se explica
    dictado.dart      Las faltas que el niño dice haber tenido → nota y repaso
    matematicas.dart  Los ejercicios que contesta que no le han salido
  voz/          locutora (hablar), escucha (comandos), frases (qué se dice)
  datos/        SQLite local + repositorio
  ui/           Tema, reproductor de guiones y pantallas
```

El principio que ordena todo: **la pedagogía vive en el guion, no en las
pantallas**. La interfaz solo sabe reproducir pasos (`Habla`, `Fragmento`,
`Espera`, `Pregunta`, `Revisar`), así que cambiar cómo enseña la app no
obliga a tocar la interfaz.

## Cómo se corrige

Al terminar, la app enseña **todo lo que tenía que salir, de una vez y con letra
caligráfica**: el texto del dictado en letra ligada, como la del cuaderno, y las
cuentas en manuscrita clara, porque en cursiva un 4 y un 7 se confunden. Aquí ya
no hay prisa ni manos ocupadas, así que se marca tocando y se ve todo junto.

- **Dictado**: el texto completo con las palabras difíciles subrayadas, y el
  niño toca las que ha escrito mal. Después, *"¿alguna falta más?"* para las
  palabras que la app no señala. Cada palabra que marque se le explica:
  *"había: lleva hache, aunque no se oiga al pronunciarla"*.
- **Matemáticas**: los cinco ejercicios con su solución, cada uno con *"me ha
  salido"* / *"no me ha salido"*. Los que no, se repasan de viva voz con pistas.

Se pregunta por palabras y no por un número de faltas porque una palabra se
puede explicar y un número no: de ahí salen las reglas que la voz repasa y los
errores frecuentes de la zona de padres.

Y lo que ha salido mal se puede **volver a hacer ahí mismo**: la app monta una
actividad nueva con solo esos ejercicios —las mismas cuentas, no otras— y la
dicta otra vez. Corregir sin poder arreglarlo se queda a medias. Lo mismo desde
el plan de hoy: tocando una actividad ya terminada se repite entera.

La repetición se guarda aparte del primer intento, para que se vea que la
segunda salió mejor, pero **no cuenta para subir o bajar de nivel**: acaba de
ver las soluciones, así que bordarla no demuestra nada.

Corregirse uno mismo es menos automático que leer la hoja con la cámara, y es
mejor: comparar su cuenta con la buena y decidir si coinciden ya es corregir.
Además nunca se equivoca al leer su letra, que era [el problema que hundía la
confianza en la app](docs/por-que-no-hay-ocr/README.md).

## Lo que se puede decir en voz alta

Todo lo que hay que hacer durante una actividad se puede decir en voz alta, y
de cada cosa se aceptan varias formas, porque el reconocimiento de voz infantil
falla bastante.

| Momento | Se dice |
|---|---|
| Antes de empezar | *listo*, *preparado*, *ya está* |
| Dictando | *repite*, *más despacio*, *más rápido*, *sigue* |
| Al acabar la actividad | *corregir*, *he terminado* |
| Con una pista delante | *ya lo veo*, *otra pista* |

Lo que hay que escribir —el dictado, el enunciado de un problema, una cuenta—
se dice **palabra a palabra, con un silencio entre cada una** y dos veces
seguidas. Lo que un niño necesita para escribir no es oír la palabra estirada,
es que le dejen tiempo antes de la siguiente; quien dicta de verdad no habla
lento, habla y se calla. Las palabras de una o dos letras van pegadas a la
siguiente, que dichas solas suenan a lista de la compra.

Lo que la app explica va a ritmo de conversación: "prepara papel y lápiz" no se
escribe, se entiende y ya. "Más despacio" alarga los silencios del dictado y no
toca las explicaciones.

La voz manda mientras se trabaja, que es cuando el niño tiene las manos
ocupadas; corregir es al revés, y ahí se toca. Durante la actividad hay como
mucho dos botones, y nunca uno por cada cosa que se puede decir: cambiar la
velocidad se pide una vez en la vida y no merece ocupar sitio permanente. Lo que
no tiene botón se recuerda escrito debajo de la frase, para que se sepa que
existe.

## Arrancar

```bash
cd app
flutter pub get
flutter test          # 77 pruebas de la lógica pura y del repositorio
flutter run           # con un móvil o emulador conectado
```

Requiere JDK 17 para compilar en Android:
`flutter config --jdk-dir=/ruta/al/jdk-17`.

## Límites conocidos

- **La nota la pone el niño.** Si dice que le ha salido y no le ha salido, la
  app se lo cree. No es grave: el nivel necesita varias actividades seguidas
  para moverse, así que una autoevaluación imperfecta no descarrila el
  progreso, y comprobar su propia hoja es parte del ejercicio.
- **La app solo pregunta por las palabras difíciles del dictado.** De las demás
  se fía de lo que él conteste a "¿alguna falta más?", y de esas no puede
  explicar ninguna regla: no sabe cuáles son.
- **La voz depende del teléfono.** Se busca la mejor voz `es-ES` instalada. Si
  el dispositivo solo trae voz latinoamericana, el dictado de palabras con
  *c/z* pierde sentido para un niño español.
- **El banco de dictados es una semilla** (15 textos, 3 por nivel). Para
  producción hacen falta ~30 por nivel. Las operaciones sí son infinitas.

## `backend/`

Servidor Node + PostgreSQL escrito antes de decidir que todo fuera local. **La
app no lo usa.** Se conserva como referencia para el día que haga falta
sincronizar entre dispositivos o dar un panel web a los padres; la lógica que
comparte con la app está portada a Dart y probada allí.
