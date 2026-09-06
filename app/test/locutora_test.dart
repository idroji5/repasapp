import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:repasapp/voz/locutora.dart';

/// Un motor de voz de mentira que apunta a qué ritmo se le ha pedido hablar.
class _MotorEspia extends FlutterTts {
  final List<double> ritmos = [];
  final List<String> dicho = [];

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
        {'name': 'es-es-x-eea-local', 'locale': 'es-ES', 'network_required': '0'},
      ];

  @override
  Future<dynamic> setVoice(Map<String, String> voice) async => 1;

  @override
  Future<dynamic> setSpeechRate(double rate) async {
    ritmos.add(rate);
    return 1;
  }

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    dicho.add(text);
    // Se tarda algo en hablar: si volviera al instante, la locutora creería
    // que la voz está muda y cambiaría de voz para repetirlo.
    await Future<void>.delayed(const Duration(milliseconds: 400));
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

  test('el tope de espera crece cuando la voz va más lenta', () {
    const frase = 'Mi abuelo vive en el campo y tiene un perro pequeño y negro.';
    final rapido = Locutora.duracionEstimada(frase, Velocidad.rapida.tasa);
    final lento = Locutora.duracionEstimada(frase, Velocidad.lenta.tasa);

    // Si el tope no creciera al bajar la velocidad, la app cortaría las frases
    // largas a media palabra.
    expect(lento, greaterThan(rapido));
  });
}
