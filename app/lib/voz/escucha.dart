import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../correccion/ortografia.dart' show sinTildes;
import '../dominio/guion.dart';

/// Escucha las palabras que el niño puede decir en voz alta ("listo", "repite",
/// "más despacio", "corregir"…).
///
/// Es deliberadamente un vocabulario cerrado y cortísimo. El reconocimiento de
/// voz infantil es poco fiable, así que no se intenta entender lo que dice: se
/// comprueba si lo que ha dicho contiene alguna de las pocas palabras que
/// esperamos, y de cada una se aceptan varias formas ("sigue", "siguiente",
/// "ya lo tengo"). Lo que se escucha siempre se puede tocar también: la voz es
/// el camino corto, el botón es la garantía.
class Escucha {
  Escucha({SpeechToText? motor})
      : _voz = motor ?? SpeechToText(),
        sorda = false;

  /// Una escucha que nunca oye nada, para las pruebas: sin micrófono de verdad,
  /// preparar el reconocedor se queda esperando para siempre y el guion no
  /// llega a empezar.
  @visibleForTesting
  Escucha.sorda()
      : _voz = SpeechToText(),
        sorda = true;

  final SpeechToText _voz;

  /// Si no hay que escuchar de verdad. Equivale a un móvil sin micrófono: la
  /// pantalla se queda con sus botones y todo sigue funcionando.
  final bool sorda;

  bool _disponible = false;
  bool _iniciada = false;

  /// true si el micrófono está listo. Si es false, la interfaz solo ofrece
  /// botones, sin avisos ni mensajes de error: al niño le da igual por qué.
  bool get disponible => _disponible;

  Future<bool> preparar() async {
    if (sorda) return false;
    if (_iniciada) return _disponible;
    _iniciada = true;
    try {
      _disponible = await _voz.initialize(
        onError: (_) {},
        onStatus: (_) {},
      );
    } catch (_) {
      _disponible = false;
    }
    return _disponible;
  }

  /// Escucha hasta oír uno de los comandos o hasta que se agote el tiempo.
  /// Devuelve null si no se ha entendido nada: entonces manda el botón.
  Future<Comando?> escucharComando(
    List<Comando> posibles, {
    Duration limite = const Duration(seconds: 30),
  }) async {
    if (!await preparar() || posibles.isEmpty) return null;

    final resultado = Completer<Comando?>();
    final temporizador = Timer(limite, () {
      if (!resultado.isCompleted) resultado.complete(null);
    });

    await _voz.listen(
      listenOptions: SpeechListenOptions(
        localeId: 'es_ES',
        partialResults: true,
      ),
      onResult: (r) {
        final oido = _normalizar(r.recognizedWords);
        if (oido.isEmpty) return;

        for (final comando in posibles) {
          if (seOye(oido, comando.comoSeDice)) {
            if (!resultado.isCompleted) resultado.complete(comando);
            return;
          }
        }
      },
    );

    final comando = await resultado.future;
    temporizador.cancel();
    await _voz.stop();
    return comando;
  }

  Future<void> parar() async {
    if (!sorda && _voz.isListening) await _voz.stop();
  }

  /// ¿Se ha dicho alguna de estas cosas?
  ///
  /// Las palabras cortas se buscan enteras y las expresiones como trozo suelto:
  /// si "sí" se buscara como trozo, "casi" y "sino" valdrían por un sí, y el
  /// niño acabaría contestando cosas que no ha dicho.
  static bool seOye(String oido, List<String> formas) {
    final palabras = oido.split(RegExp(r'[^a-z0-9ñ]+')).where((p) => p.isNotEmpty);
    for (final forma in formas) {
      final buscada = _normalizar(forma);
      if (buscada.length <= 4 && !buscada.contains(' ')) {
        if (palabras.contains(buscada)) return true;
      } else if (oido.contains(buscada)) {
        return true;
      }
    }
    return false;
  }

  /// "Más Despacio" y "mas despacio" tienen que valer lo mismo.
  static String _normalizar(String s) => sinTildes(s.toLowerCase()).trim();
}
