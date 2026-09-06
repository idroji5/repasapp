import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:repasapp/voz/locutora.dart';

/// Un motor de voz de mentira que apunta a qué ritmo se le ha pedido hablar.
class _MotorEspia extends FlutterTts {
  final List<double> ritmos = [];
  final List<String> dicho = [];

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

    await locutora.dictar('Mi abuelo vive en el campo.');
    final alDictar = motor.ritmos.last;

    expect(alExplicar, Locutora.tasaAlExplicar);
    expect(alDictar, Velocidad.normal.tasa);
    expect(alDictar, lessThan(alExplicar),
        reason: 'lo que hay que escribir se dice más despacio que lo que se explica');
  });

  test('pedir "más despacio" solo cambia el ritmo del dictado', () async {
    final motor = _MotorEspia();
    final locutora = Locutora(motor: motor)..velocidad = Velocidad.lenta;

    await locutora.dictar('Mi abuelo vive en el campo.');
    expect(motor.ritmos.last, Velocidad.lenta.tasa);

    await locutora.decir('Muy bien. Empezamos.');
    expect(motor.ritmos.last, Locutora.tasaAlExplicar,
        reason: 'las instrucciones no se ralentizan con el dictado');
  });

  test('la segunda lectura de una frase va aún más despacio', () async {
    final motor = _MotorEspia();
    final locutora = Locutora(motor: motor);

    await locutora.dictar('Mi abuelo vive en el campo.');
    await locutora.dictar('Mi abuelo vive en el campo.', a: Velocidad.normal.masLenta);

    expect(motor.ritmos.last, lessThan(motor.ritmos[motor.ritmos.length - 2]));
    expect(motor.dicho, hasLength(2));
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
