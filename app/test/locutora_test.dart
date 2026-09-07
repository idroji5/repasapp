import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:repasapp/voz/locutora.dart';

/// Un motor de voz de mentira que apunta a qué ritmo se le ha pedido hablar.
class _MotorEspia extends FlutterTts {
  _MotorEspia({this.comoHabla = _normal, this.voces = 1});

  /// Cuánto tarda de verdad en decir algo. Cambia mucho de un teléfono a otro,
  /// y ahí está la gracia: hay motores que ignoran la velocidad que se les pide.
  final Duration Function(String texto) comoHabla;

  /// Cuántas voces castellanas ofrece el teléfono.
  final int voces;

  static Duration _normal(String texto) =>
      Duration(milliseconds: 400 * texto.split(' ').length);

  final List<double> ritmos = [];
  final List<String> dicho = [];
  final List<String> vocesPuestas = [];

  void limpiar() {
    ritmos.clear();
    dicho.clear();
  }

  @override
  Future<dynamic> setLanguage(String language) async => 1;

  @override
  Future<dynamic> setPitch(double pitch) async => 1;

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async => 1;

  @override
  Future<dynamic> get getVoices async => <Map<String, String>>[
        for (var i = 0; i < voces; i++)
          {'name': 'es-es-voz-$i', 'locale': 'es-ES', 'network_required': '0'},
      ];

  @override
  Future<dynamic> setVoice(Map<String, String> voice) async {
    vocesPuestas.add(voice['name']!);
    return 1;
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async {
    ritmos.add(rate);
    return 1;
  }

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    dicho.add(text);
    await Future<void>.delayed(comoHabla(text));
    return 1;
  }

  @override
  Future<dynamic> stop() async => 1;
}

void main() {
  // El constructor de FlutterTts registra un canal de plataforma, y eso no
  // existe hasta que el binding está en marcha.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('explicar va a ritmo de conversación y dictar va más lento', () async {
    final motor = _MotorEspia();
    final locutora = Locutora(motor: motor);

    await locutora.decir('Prepara papel y lápiz.');
    final alExplicar = motor.ritmos.last;
    expect(motor.dicho, ['Prepara papel y lápiz.'],
        reason: 'una explicación se dice de una tirada');

    motor.limpiar();
    await locutora.dictar('El perro come.');
    final alDictar = motor.ritmos.last;

    expect(alExplicar, Locutora.tasaAlExplicar);
    expect(alDictar, Velocidad.normal.tasa);
    expect(alDictar, lessThan(alExplicar),
        reason: 'lo que hay que escribir se dice más despacio que lo que se explica');
  });

  test('al dictar se calla entre palabra y palabra', () async {
    final motor = _MotorEspia();
    final locutora = Locutora(motor: motor);

    final reloj = Stopwatch()..start();
    await locutora.dictar('El perro come.');
    reloj.stop();

    // Tres palabras, tres trozos: "El perro" va junto porque "el" solo suena a
    // lista de la compra.
    expect(motor.dicho, ['El perro', 'come.']);
    expect(reloj.elapsedMilliseconds,
        greaterThan(Velocidad.normal.pausaEntrePalabras),
        reason: 'entre trozo y trozo hay silencio de verdad');
  });

  test('un enunciado de matemáticas no se trocea palabra a palabra', () async {
    final motor = _MotorEspia();
    final locutora = Locutora(motor: motor);

    await locutora.dictar(
      'Cada caja trae doce lápices. ¿Cuántos hay?',
      corte: Corte.frases,
    );

    // Se corta por donde ya se respira al leerlo. Un problema se entiende de
    // corrido; trocearlo como un dictado lo vuelve ininteligible.
    expect(motor.dicho, ['Cada caja trae doce lápices.', '¿Cuántos hay?']);
  });

  test('lo que va en inglés se dice en inglés, y el resto no', () {
    expect(
      Locutora.enIdiomas('Traduce al español: «The cat is here».'),
      const [
        TrozoHablado('Traduce al español:', ingles: false),
        TrozoHablado('The cat is here', ingles: true),
      ],
      reason: 'el punto que queda suelto detrás no se dice aparte',
    );
    expect(
      Locutora.enIdiomas('Escribe en inglés: perro.'),
      const [TrozoHablado('Escribe en inglés: perro.', ingles: false)],
    );
  });

  test('se corta por donde se respira', () {
    expect(Locutora.enFrases('Hay 30 galletas, y son para tres niños. ¿Cuántas?'),
        ['Hay 30 galletas,', 'y son para tres niños.', '¿Cuántas?']);
    expect(Locutora.enFrases('Sin puntuación ninguna'),
        ['Sin puntuación ninguna']);
  });

  test('las palabras cortas no se dicen solas', () {
    expect(Locutora.enTrozos('Mi abuelo vive en el campo.'),
        ['Mi abuelo', 'vive', 'en el campo.']);
    expect(Locutora.enTrozos('¿Se ha escondido en el armario?'),
        ['¿Se ha escondido', 'en el armario?']);
    expect(Locutora.enTrozos('Setecientos'), ['Setecientos']);
  });

  test('pedir "más despacio" solo cambia el ritmo del dictado', () async {
    final motor = _MotorEspia();
    final locutora = Locutora(motor: motor)..velocidad = Velocidad.lenta;

    await locutora.dictar('El perro come.');
    expect(motor.ritmos.last, Velocidad.lenta.tasa);

    await locutora.decir('Muy bien. Empezamos.');
    expect(motor.ritmos.last, Locutora.tasaAlExplicar,
        reason: 'las instrucciones no se ralentizan con el dictado');
  });

  test('la segunda lectura de una frase va aún más despacio', () async {
    final motor = _MotorEspia();
    final locutora = Locutora(motor: motor);

    await locutora.dictar('El perro come.');
    final primera = motor.ritmos.last;

    motor.limpiar();
    await locutora.dictar('El perro come.', a: Velocidad.normal.masLenta);

    expect(motor.ritmos.last, lessThan(primera));
    expect(Velocidad.normal.masLenta.pausaEntrePalabras,
        greaterThan(Velocidad.normal.pausaEntrePalabras),
        reason: 'y con más silencio entre palabras');
  });

  test('un motor que ignora la velocidad no se toma por mudo', () async {
    // El fallo que dejaba mudas las matemáticas y el inglés: la app medía si la
    // voz había sonado comparando con el ritmo lento que ella había pedido. En
    // los teléfonos que ignoran ese ritmo y hablan normal, cada frase parecía
    // muda y la app se ponía a cambiar de voz hasta dar con una que no sonaba.
    // El dictado se libraba porque va palabra a palabra, y las palabras sueltas
    // no entran en esa cuenta.
    final motor = _MotorEspia(
      voces: 3,
      // Habla a ritmo de adulto con prisa, se le pida lo que se le pida.
      comoHabla: (t) => Duration(milliseconds: 250 * t.split(' ').length),
    );
    final locutora = Locutora(motor: motor);

    await locutora.dictar(
      'Primera: setecientos cuarenta y dos dividido entre siete.',
      corte: Corte.frases,
    );

    expect(motor.vocesPuestas.toSet(), hasLength(1),
        reason: 'no había ningún motivo para cambiar de voz');
    expect(motor.dicho.where((t) => t.contains('setecientos')), hasLength(1),
        reason: 'y por tanto tampoco para repetir la frase');
  });

  test('una voz que de verdad no suena se cambia, pero solo una vez', () async {
    final motor = _MotorEspia(
      voces: 3,
      comoHabla: (_) => const Duration(milliseconds: 5),
    );
    final locutora = Locutora(motor: motor);

    await locutora.decir('Vamos a hacer cinco operaciones muy fáciles.');
    expect(motor.vocesPuestas.toSet(), hasLength(2), reason: 'se prueba otra voz');

    await locutora.decir('Prepara papel y lápiz para empezar.');
    expect(motor.vocesPuestas.toSet(), hasLength(2),
        reason: 'si la segunda tampoco suena, el problema no es la voz');
  });

  test('cortar una frase a media no convierte la voz en muda', () async {
    // El fallo de la segunda asignatura del día: al terminar una actividad se
    // llama a `parar()`, la frase en curso devuelve el control al instante y la
    // app daba por muda una voz que iba perfectamente. Se cambiaba a la
    // siguiente de la lista y a partir de ahí ya no se oía nada.
    final motor = _MotorEspia(
      voces: 3,
      comoHabla: (_) => const Duration(milliseconds: 5),
    );
    final locutora = Locutora(motor: motor);
    await locutora.preparar();

    final hablando = locutora.decir('Ya está. Ahora lo corregimos juntos, con calma.');
    await locutora.parar();
    await hablando;

    expect(motor.vocesPuestas.toSet(), hasLength(1),
        reason: 'la ha callado el niño al salir, no un fallo de la voz');
  });

  test('después de callarla, la pantalla siguiente vuelve a tener voz', () async {
    // El fallo que dejaba muda la corrección entera: al terminar una actividad
    // se manda callar, y ese "calla" se quedaba puesto. La pantalla de
    // corrección pedía su primera frase y no sonaba absolutamente nada.
    final motor = _MotorEspia();
    final locutora = Locutora(motor: motor);

    await locutora.decir('Ya está. Ahora lo corregimos juntos.');
    await locutora.parar();
    motor.limpiar();

    await locutora.decir('Aquí tienes el dictado escrito.');
    expect(motor.dicho, ['Aquí tienes el dictado escrito.']);

    motor.limpiar();
    await locutora.parar();
    await locutora.dictar('El perro come.');
    expect(motor.dicho, isNotEmpty, reason: 'y dictar, igual');
  });

  test('callar a mitad de frase para de verdad', () async {
    // Y lo contrario: levantar el "calla" en cada palabra haría que mandar
    // callar durante un dictado no sirviera de nada.
    final motor = _MotorEspia(
      comoHabla: (_) => const Duration(milliseconds: 40),
    );
    final locutora = Locutora(motor: motor);
    await locutora.preparar();
    motor.limpiar();

    final dictando = locutora.dictar('Mi abuelo vive en el campo con su perro.');
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await locutora.parar();
    await dictando;

    expect(motor.dicho.length, lessThan(5),
        reason: 'se corta donde se le dijo, no al final de la frase');
  });

  test('en cuanto una voz suena, ya no se cambia', () async {
    var rapido = false;
    final motor = _MotorEspia(
      voces: 3,
      comoHabla: (t) => rapido
          ? const Duration(milliseconds: 5)
          : Duration(milliseconds: 400 * t.split(' ').length),
    );
    final locutora = Locutora(motor: motor);

    await locutora.decir('Esta frase se oye perfectamente, sin ningún problema.');
    rapido = true; // ahora el motor devuelve el control al instante
    await locutora.decir('Esta otra vuelve enseguida, pero la voz es la buena.');

    expect(motor.vocesPuestas.toSet(), hasLength(1));
  });

  test('el tope de espera crece cuando la voz va más lenta', () {
    const frase = 'Mi abuelo vive en el campo y tiene un perro pequeño y negro.';
    final rapido = Locutora.duracionEstimada(frase, Velocidad.rapida.tasa);
    final lento = Locutora.duracionEstimada(frase, Velocidad.lenta.tasa);

    // Si el tope no creciera al bajar la velocidad, la app cortaría las frases
    // largas a media palabra.
    expect(lento, greaterThan(rapido));
  });
}
