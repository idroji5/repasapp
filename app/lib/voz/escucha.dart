import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

import '../correccion/alinear.dart' show sinTildes;
import '../dominio/guion.dart';

/// Escucha las palabras que el niño puede decir en voz alta ("listo", "repite",
/// "más despacio"…).
///
/// Es deliberadamente un vocabulario cerrado y cortísimo. El reconocimiento de
/// voz infantil es poco fiable, así que no se intenta entender lo que dice: se
/// comprueba si lo que ha dicho contiene alguna de las cuatro o cinco palabras
/// que esperamos. Y todo comando tiene siempre su botón en pantalla: la voz es
/// un atajo, nunca el único camino.
class Escucha {
  Escucha({SpeechToText? motor}) : _voz = motor ?? SpeechToText();

  final SpeechToText _voz;
  bool _disponible = false;
  bool _iniciada = false;

  /// true si el micrófono está listo. Si es false, la interfaz solo ofrece
  /// botones, sin avisos ni mensajes de error: al niño le da igual por qué.
  bool get disponible => _disponible;

  Future<bool> preparar() async {
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
          if (oido.contains(_normalizar(comando.dicho))) {
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
    if (_voz.isListening) await _voz.stop();
  }

  /// "Más Despacio" y "mas despacio" tienen que valer lo mismo.
  static String _normalizar(String s) => sinTildes(s.toLowerCase()).trim();
}
