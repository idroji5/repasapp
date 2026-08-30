import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

/// Velocidades a las que la app dicta. El niño puede pedir "más despacio" en
/// cualquier momento y el cambio se aplica al siguiente fragmento.
enum Velocidad {
  lenta(0.34),
  normal(0.48),
  rapida(0.60);

  const Velocidad(this.tasa);

  /// Tasa de habla de flutter_tts, donde ~0,5 es el ritmo natural.
  final double tasa;

  Velocidad get masLenta => switch (this) {
        Velocidad.rapida => Velocidad.normal,
        _ => Velocidad.lenta,
      };

  Velocidad get masRapida => switch (this) {
        Velocidad.lenta => Velocidad.normal,
        _ => Velocidad.rapida,
      };
}

/// La voz de la app.
///
/// Usa el motor del propio teléfono, así que funciona sin conexión y sin coste.
/// A cambio, la calidad depende del dispositivo: en la primera ejecución se
/// busca la mejor voz castellana instalada y se avisa si no hay ninguna, porque
/// con voz latinoamericana el dictado de "zapato" o "cielo" deja de tener
/// sentido para un niño español.
class Locutora {
  Locutora({FlutterTts? motor}) : _tts = motor ?? FlutterTts();

  final FlutterTts _tts;
  bool _preparada = false;

  /// Queda a true cuando no se ha encontrado ninguna voz en español de España.
  bool vozCastellanaAusente = false;

  /// Nombre de la voz que se está usando, para poder diagnosticarlo.
  String vozElegida = '';

  /// true si la voz en uso exige conexión. La app funciona, pero se quedará
  /// muda sin wifi.
  bool usaVozDeRed = false;

  List<Map<String, String>> _candidatas = const [];
  int _indiceVoz = 0;

  /// Voces castellanas que ofrece el teléfono, para que el padre elija.
  List<Map<String, String>> get vocesDisponibles => List.unmodifiable(_candidatas);

  /// Voz fijada por el padre. Manda sobre la elección automática.
  String? vozPreferida;

  Velocidad velocidad = Velocidad.normal;

  Future<void> preparar() async {
    if (_preparada) return;

    await _tts.setLanguage('es-ES');
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(velocidad.tasa);
    // Sin esto, `speak` vuelve al instante y no se sabe cuándo ha terminado de
    // hablar, que es justo lo que necesita el guion para calcular las pausas.
    await _tts.awaitSpeakCompletion(true);

    await _elegirVoz();
    _preparada = true;
  }

  /// Ordena las voces castellanas de mejor a peor candidata.
  ///
  /// Android publica de cada voz si necesita conexión y si sus datos están
  /// instalados (`notInstalled`). Eso último importa mucho: una voz puede
  /// aparecer en la lista, aceptar la petición y no producir nada, porque su
  /// paquete nunca se descargó. El motor informa de éxito igualmente y la app
  /// se queda muda sin un solo error. Filtrarlas por bandera es la única forma
  /// fiable de saberlo; medir cuánto tarda en "hablar" no sirve, porque tarda
  /// lo mismo que si sonara.
  ///
  /// Entre las que sí funcionan se prefiere la que no necesita conexión: media
  /// app es funcionar sin wifi, y una app de dictado muda no está degradada,
  /// está rota.
  Future<void> _elegirVoz() async {
    try {
      final voces = (await _tts.getVoices as List?) ?? [];
      final castellanas = voces
          .cast<Map>()
          .map((v) => v.map((k, val) => MapEntry(k.toString(), val.toString())))
          .where((v) => (v['locale'] ?? '').toLowerCase().startsWith('es-es'))
          .toList();

      for (final v in castellanas) {
        debugPrint('[RepasApp] voz: ${v['name']} '
            'red=${v['network_required']} calidad=${v['quality']} '
            'rasgos=${v['features']}');
      }

      _candidatas = castellanas
          .where((v) => !(v['features'] ?? '').contains('notInstalled'))
          .toList();

      if (_candidatas.isEmpty) {
        // Sin ninguna voz utilizable, mejor probar las descartadas que callar.
        _candidatas = castellanas;
        vozCastellanaAusente = castellanas.isEmpty;
        if (_candidatas.isEmpty) return;
      }

      const puntosCalidad = {
        'very high': 4, 'high': 3, 'normal': 2, 'low': 1, 'very low': 0,
      };

      int puntuacion(Map<String, String> voz) {
        final nombre = voz['name']?.toLowerCase() ?? '';
        var puntos = 0;
        // Funcionar sin conexión manda sobre todo lo demás.
        if (voz['network_required'] == '0') puntos += 20;
        if (nombre.contains('female') || nombre.contains('-lfx')) puntos += 6;
        puntos += (puntosCalidad[voz['quality']] ?? 2) * 2;
        return puntos;
      }

      _candidatas.sort((a, b) => puntuacion(b).compareTo(puntuacion(a)));

      // Si el padre eligió una a mano, esa manda: es el único que puede oír si
      // funciona de verdad en este teléfono.
      final fijada = _candidatas.indexWhere((v) => v['name'] == vozPreferida);
      await _usarCandidata(fijada >= 0 ? fijada : 0);
      debugPrint('[RepasApp] voz elegida: $vozElegida (red=$usaVozDeRed)');
    } catch (e) {
      debugPrint('[RepasApp] no se pudo elegir voz: $e');
    }
  }

  Future<void> _usarCandidata(int indice) async {
    if (indice >= _candidatas.length) return;
    _indiceVoz = indice;
    final voz = _candidatas[indice];
    vozElegida = voz['name'] ?? '';
    usaVozDeRed = voz['network_required'] == '1';
    await _tts.setVoice({'name': vozElegida, 'locale': voz['locale'] ?? 'es-ES'});
  }

  /// Pasa a la siguiente voz de la lista. Devuelve false si no quedan.
  Future<bool> _probarSiguienteVoz() async {
    if (_indiceVoz + 1 >= _candidatas.length) return false;
    await _usarCandidata(_indiceVoz + 1);
    debugPrint('[RepasApp] cambio de voz a: $vozElegida');
    return true;
  }

  /// Una voz que no suena puede devolver el control casi al instante: el motor
  /// "termina" de decir una frase de tres segundos en una décima. Es una señal
  /// débil —muchas voces mudas tardan lo normal— pero cuando aparece es
  /// inequívoca, así que sirve de último recurso.
  static bool _pareceMuda(String texto, Duration estimada, Duration real) {
    final palabras = texto.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).length;
    if (palabras < 3) return false; // en frases cortas el margen no distingue
    return real < estimada * 0.35;
  }

  /// Aproximadamente cuánto se tarda en leer un texto en voz alta. Sirve para
  /// poner un tope razonable a la espera, no para medir nada con precisión.
  static Duration duracionEstimada(String texto, Velocidad velocidad) {
    final palabras = texto.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).length;
    final segundos =
        (palabras / 2.6 + 0.5) * (Velocidad.normal.tasa / velocidad.tasa);
    return Duration(milliseconds: (segundos * 1000).round());
  }

  /// Dice el texto y no vuelve hasta que ha terminado de decirlo.
  ///
  /// Con un tope de tiempo: si el motor de voz falla (sin datos de voz, sin
  /// conexión para una voz de red, motor a medio instalar) `speak` puede no
  /// avisar nunca de que ha terminado, y entonces la actividad se queda
  /// congelada para siempre en el primer paso. Es preferible seguir en silencio
  /// —el texto está en pantalla— que dejar al niño mirando una pantalla muerta.
  Future<void> decir(String texto, {Velocidad? a}) async {
    await preparar();
    final ritmo = a ?? velocidad;
    await _tts.setSpeechRate(ritmo.tasa);

    final estimada = duracionEstimada(texto, ritmo);
    final tope = estimada + const Duration(seconds: 6);

    final reloj = Stopwatch()..start();
    try {
      await _tts.speak(texto).timeout(tope);
    } on TimeoutException {
      falloDeVoz = true;
      await _tts.stop();
      return;
    }
    reloj.stop();

    // Red de seguridad para el caso raro en que una voz marcada como
    // instalada devuelva el control al instante: se cambia de voz y se repite
    // la frase, para que el niño pierda un segundo y no el dictado entero.
    if (_pareceMuda(texto, estimada, reloj.elapsed) && await _probarSiguienteVoz()) {
      try {
        await _tts.speak(texto).timeout(tope);
      } on TimeoutException {
        falloDeVoz = true;
        await _tts.stop();
      }
    }
  }

  /// Queda a true si alguna frase no llegó a sonar. La pantalla lo usa para
  /// avisar de que hay que revisar el motor de voz del teléfono.
  bool falloDeVoz = false;

  /// Cambia a una voz concreta y la prueba en voz alta. La usa la zona de
  /// padres: la calidad de las voces varía muchísimo entre teléfonos y hay
  /// voces que el sistema anuncia como buenas y no suenan, así que la única
  /// comprobación fiable es que una persona la oiga.
  Future<void> probarVoz(String nombre) async {
    await preparar();
    final indice = _candidatas.indexWhere((v) => v['name'] == nombre);
    if (indice < 0) return;
    await _usarCandidata(indice);
    vozPreferida = nombre;
    await decir('Hola. Vamos a hacer un dictado.');
  }

  /// Comprueba si la voz en uso genera audio de verdad, sintetizando a un
  /// fichero en lugar de al altavoz.
  ///
  /// Es la única forma de separar dos fallos que desde fuera son idénticos:
  /// una voz que el sistema anuncia como instalada pero no produce nada, y un
  /// teléfono que sí sintetiza pero no está sacando sonido. Sin esto, un padre
  /// solo puede decir "no se oye" y nadie sabe por dónde empezar.
  Future<bool> generaSonido() async {
    await preparar();
    try {
      final carpeta = await getTemporaryDirectory();
      final ruta = '${carpeta.path}/prueba_voz.wav';

      await _tts.awaitSynthCompletion(true);
      await _tts
          .synthesizeToFile('Vamos a hacer un dictado.', ruta, true)
          .timeout(const Duration(seconds: 20));

      final fichero = File(ruta);
      if (!await fichero.exists()) return false;

      // Un WAV de silencio pesa lo mismo que uno con voz: hay que mirar dentro.
      final bytes = await fichero.readAsBytes();
      await fichero.delete();
      if (bytes.length < 2000) return false;
      return bytes.skip(44).any((b) => b != 0 && b != 255);
    } catch (_) {
      return false;
    }
  }

  Future<void> parar() => _tts.stop();
}
