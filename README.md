# RepasApp

App audio-first para que niños de Primaria repasen sus asignaturas: **escuchan,
trabajan en papel, y solo usan el móvil** para iniciar la actividad, pedir
repeticiones y fotografiar el cuaderno al terminar.

**Todo funciona en local.** No hay servidor, ni cuenta, ni conexión: el
contenido, la voz, el reconocimiento de la foto y los datos viven en el
dispositivo de la familia.

## Decisiones de producto

| Decisión | Valor |
|---|---|
| Edad objetivo | 6–12 (Primaria). Contenido del MVP: 3.º–6.º |
| Currículo | España (LOMLOE), indexado por **microdestreza**, no por curso |
| Idiomas | Castellano. La arquitectura admite añadir catalán e inglés |
| Contenido | Matemáticas: generador determinista. Dictado: banco curado a mano |
| Corrección | Foto por tanda + OCR en el dispositivo (ML Kit) |
| Feedback | Pistas antes que solución (configurable por el padre) |
| Zona de padres | Sí, protegida con PIN |
| Sesión diaria | "N minutos al día" → plan generado automáticamente |
| Nivel | 1–5 **independiente por asignatura**, con autoajuste |
| Voz | Motor del propio teléfono (`flutter_tts`), es-ES, voz femenina si la hay |
| Fotos | **Nunca se guardan.** Se reconocen en memoria y se descartan |

## Arquitectura

```
app/lib/
  contenido/    Qué se le plantea al niño
    numeros.dart      742 → "setecientos cuarenta y dos"
    dictados.dart     Banco de dictados revisados a mano
    matematicas.dart  Generador determinista de operaciones + narración
  dominio/      Las reglas, sin depender de nada
    curriculo.dart    Microdestrezas y en qué curso se introducen
    niveles.dart      Cuándo sube o baja el nivel de una asignatura
    planificador.dart "15 minutos" → sesión concreta
    guion.dart        Qué dice la voz, cuánto calla, qué espera
    actividades.dart  Construye el guion de cada tipo de actividad
  correccion/   Qué hizo el niño
    alinear.dart      Compara lo escrito con lo dictado y clasifica las faltas
    matematicas.dart  Compara resultados; distingue calcular mal de copiar mal
    ocr.dart          ML Kit (adaptador aislado)
    interpretar.dart  Qué significa lo que el OCR ha leído
  voz/          locutora (hablar), escucha (comandos), frases (qué se dice)
  datos/        SQLite local + repositorio
  ui/           Tema, reproductor de guiones y pantallas
```

El principio que ordena todo: **la pedagogía vive en el guion, no en las
pantallas**. La interfaz solo sabe reproducir pasos (`Habla`, `Fragmento`,
`Espera`, `Pregunta`, `PedirFoto`), así que cambiar cómo enseña la app no
obliga a tocar la interfaz.

## Arrancar

```bash
cd app
flutter pub get
flutter test          # 40 pruebas de la lógica pura y del repositorio
flutter run           # con un móvil o emulador conectado
```

Requiere JDK 17 para compilar en Android:
`flutter config --jdk-dir=/ruta/al/jdk-17`.

## Límites conocidos

- **El OCR de caligrafía infantil falla.** ML Kit está entrenado con texto
  impreso: va bien con números y letra de imprenta, y regular con letra ligada.
  Por eso la pantalla de resultado siempre ofrece *"Yo no escribí eso"* para
  arreglar lo que se ha leído mal y volver a corregir.
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
