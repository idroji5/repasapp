import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

/// Velocidades a las que la app DICTA lo que hay que escribir. El niño puede
/// pedir "más despacio" en cualquier momento y el cambio se aplica al
/// siguiente fragmento.
///
/// Las tres van muy por debajo del ritmo de conversación a propósito. Quien
/// dicta a un niño de Primaria no habla como habla con un adulto: articula,
/// separa las palabras y espera a que la mano llegue. Un adulto lee ~2,6
/// palabras por segundo; aquí, a ritmo normal, va a menos de la mitad.
///
/// Y el ritmo de partida no es el mismo para todos: en los cursos bajos se
/// arranca ya en [Velocidad.lenta], porque un niño de siete años todavía dibuja
/// cada letra. Ver [velocidadDeDictado].
///
/// Esto NO afecta a las explicaciones. "Prepara papel y lápiz" no se escribe,
/// se entiende y ya: dicho a ritmo de dictado se hace eterno y aburre antes de
/// llegar a lo que importa. Ver [Locutora.tasaAlExplicar].
enum Velocidad {
  lenta(0.16, 1500),
  normal(0.22, 1100),
  rapida(0.32, 700);

  const Velocidad(this.tasa, this.pausaEntrePalabras);

  /// Tasa de habla de flutter_tts, donde 0,5 es el ritmo natural de un adulto.
  final double tasa;

  /// Milisegundos de silencio entre una palabra y la siguiente al dictar.
  ///
  /// Bajar la tasa hace que cada palabra suene arrastrada, y arrastrada no es
  /// lo mismo que despacio: lo que un niño necesita para escribir no es oír la
  /// palabra estirada, es que le dejen tiempo antes de la siguiente. Quien
  /// dicta de verdad no habla lento, habla normal y se calla entre palabra y
  /// palabra.
  final int pausaEntrePalabras;

  Velocidad get masLenta => switch (this) {
        Velocidad.rapida => Velocidad.normal,
        _ => Velocidad.lenta,
      };

  Velocidad get masRapida => switch (this) {
        Velocidad.lenta => Velocidad.normal,
        _ => Velocidad.rapida,
      };
}

/// A qué ritmo se empieza a dictar a un niño de este nivel.
///
/// Se arranca despacio y se sube, y no al revés: la primera frase de un dictado
/// demasiado rápido ya se ha perdido cuando el niño se da cuenta de que iba
/// deprisa. Desde la actividad puede pedir "más rápido" cuando le sobre tiempo.
Velocidad velocidadDeDictado(int nivel) =>
    nivel <= 2 ? Velocidad.lenta : Velocidad.normal;

/// Cuánto se trocea al dictar: una frase de dictado se copia palabra por
/// palabra; un enunciado de matemáticas se entiende de corrido.
enum Corte { palabras, frases }

/// Un trozo de texto con el idioma en el que hay que decirlo.
class TrozoHablado {
  const TrozoHablado(this.texto, {required this.ingles});
  final String texto;
  final bool ingles;

  @override
  String toString() => ingles ? '«$texto»' : texto;

  @override
  bool operator ==(Object other) =>
      other is TrozoHablado && other.texto == texto && other.ingles == ingles;

  @override
  int get hashCode => Object.hash(texto, ingles);
}

/// La voz de la app.
///
/// Usa el motor del propio teléfono, así que funciona sin conexión y sin coste.
/// A cambio, la calidad depende del dispositivo: en la primera ejecución se
/// busca la mejor voz castellana instalada y se avisa si no hay ninguna, porque
/// con voz latinoamericana el dictado de "zapato" o "cielo" deja de tener
/// sentido para un niño español.
class Locutora {
  Locutora({FlutterTts? motor})
      : _tts = motor ?? FlutterTts(),
        muda = false;

  /// Una locutora que no habla y contesta al instante.
  ///
  /// Para las pruebas: sin un motor de voz de verdad detrás, cada frase se
  /// queda esperando una respuesta que no llega nunca y el guion no avanza, así
  /// que no se podría probar ni una actividad entera.
  @visibleForTesting
  Locutora.silenciosa()
      : _tts = FlutterTts(),
        muda = true;

  final FlutterTts _tts;

  /// Si no hay que hablar de verdad.
  final bool muda;

  bool _preparada = false;

  /// Queda a true cuando no se ha encontrado ninguna voz en español de España.
  bool vozCastellanaAusente = false;

  /// Queda a true cuando no hay ninguna voz inglesa instalada. Los ejercicios
  /// de inglés se dicen igual, con la voz castellana, pero pronunciados por una
  /// voz española "butterfly" no se parece a nada: el padre tiene que saberlo.
  bool vozInglesaAusente = false;

  /// La voz con la que se dice lo que va en inglés.
  Map<String, String>? _vozInglesa;

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

  /// Ritmo al que la app explica las cosas: el de una conversación tranquila
  /// con un niño, un punto por debajo del de un adulto con otro adulto.
  ///
  /// Es fijo. El niño puede pedir que se dicte más despacio, que es lo que le
  /// cuesta seguir; nadie pide que le expliquen las instrucciones más despacio.
  static const double tasaAlExplicar = 0.46;

  /// A qué velocidad se dicta ahora mismo.
  Velocidad velocidad = Velocidad.normal;

  Future<void> preparar() async {
    if (_preparada || muda) return;

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
      _elegirVozInglesa(voces);

      // Si el padre eligió una a mano, esa manda: es el único que puede oír si
      // funciona de verdad en este teléfono.
      final fijada = _candidatas.indexWhere((v) => v['name'] == vozPreferida);
      await _usarCandidata(fijada >= 0 ? fijada : 0);
      debugPrint('[RepasApp] voz elegida: $vozElegida (red=$usaVozDeRed)');
    } catch (e) {
      debugPrint('[RepasApp] no se pudo elegir voz: $e');
    }
  }

  /// La mejor voz inglesa que haya, para los ejercicios de inglés.
  ///
  /// Se prefiere británica: es el inglés que se enseña en el colegio en España
  /// y el que va a oír en clase.
  void _elegirVozInglesa(List<dynamic> voces) {
    final inglesas = voces
        .cast<Map>()
        .map((v) => v.map((k, val) => MapEntry(k.toString(), val.toString())))
        .where((v) => (v['locale'] ?? '').toLowerCase().startsWith('en'))
        .where((v) => !(v['features'] ?? '').contains('notInstalled'))
        .toList();

    int puntos(Map<String, String> voz) {
      final locale = (voz['locale'] ?? '').toLowerCase();
      return (locale.startsWith('en-gb') ? 10 : 0) +
          (voz['network_required'] == '0' ? 5 : 0);
    }

    inglesas.sort((a, b) => puntos(b).compareTo(puntos(a)));
    vozInglesaAusente = inglesas.isEmpty;
    _vozInglesa = inglesas.firstOrNull;
    debugPrint('[RepasApp] voz inglesa: ${_vozInglesa?['name'] ?? "ninguna"}');
  }

  Future<void> _usarCandidata(int indice) async {
    if (indice >= _candidatas.length) return;
    _indiceVoz = indice;
    final voz = _candidatas[indice];
    vozElegida = voz['name'] ?? '';
    usaVozDeRed = voz['network_required'] == '1';
    await _tts.setVoice({'name': vozElegida, 'locale': voz['locale'] ?? 'es-ES'});
  }

  /// Si la voz que se está usando ha sonado alguna vez de verdad.
  ///
  /// En cuanto se la oye una vez, no se cambia nunca más: una detección
  /// equivocada después de eso solo puede empeorar las cosas, cambiando una voz
  /// que funciona por otra que a lo mejor no.
  bool _estaVozHaSonado = false;

  /// Solo se cambia de voz una vez por sesión. Si la segunda tampoco suena, el
  /// problema no es la voz, y seguir bajando por la lista es ir a peor.
  bool _yaSeCambioDeVoz = false;

  /// Pasa a la siguiente voz de la lista. Devuelve false si no quedan o si ya
  /// no toca cambiar.
  Future<bool> _probarSiguienteVoz() async {
    if (_estaVozHaSonado || _yaSeCambioDeVoz) return false;
    if (_indiceVoz + 1 >= _candidatas.length) return false;

    _yaSeCambioDeVoz = true;
    await _usarCandidata(_indiceVoz + 1);
    debugPrint('[RepasApp] cambio de voz a: $vozElegida');
    return true;
  }

  /// Una voz que no suena devuelve el control casi al instante: el motor
  /// "termina" de decir una frase de tres segundos en una décima.
  ///
  /// La comparación se hace contra lo que tardaría un adulto hablando deprisa,
  /// NO contra el ritmo lento que la app ha pedido. Hay motores que ignoran la
  /// velocidad y lo dicen todo a ritmo normal: si se midiera contra lo pedido,
  /// esos teléfonos parecerían mudos en cada frase y la app se pondría a
  /// cambiar de voz hasta dar con una que de verdad no suena. Eso es justo lo
  /// que pasaba en matemáticas y en inglés y no en el dictado: el dictado se
  /// dice palabra a palabra, y las palabras sueltas no entran en esta cuenta.
  static bool _pareceMuda(String texto, Duration real) {
    final palabras = texto.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).length;
    if (palabras < 5) return false; // en frases cortas el margen no distingue

    final deprisa = duracionEstimada(texto, 0.5);
    return real < deprisa * 0.35;
  }

  /// Aproximadamente cuánto se tarda en leer un texto en voz alta. Sirve para
  /// poner un tope razonable a la espera, no para medir nada con precisión.
  ///
  /// Se calcula contra el ritmo real de la voz y no contra "lo normal": si se
  /// midiera en proporción a la velocidad normal, al bajarla el tope se
  /// quedaría corto y la app cortaría frases largas a media palabra.
  static Duration duracionEstimada(String texto, double tasa) {
    final palabras = texto.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).length;
    const palabrasPorSegundoDeAdulto = 2.6; // a tasa 0,5
    final porSegundo = palabrasPorSegundoDeAdulto * (tasa / 0.5);
    return Duration(milliseconds: ((palabras / porSegundo + 0.8) * 1000).round());
  }

  /// Explica algo: instrucciones, preguntas, correcciones. Ritmo de conversar.
  Future<void> decir(String texto) async {
    for (final trozo in enIdiomas(texto)) {
      if (_cancelado) return;
      await _hablar(trozo.texto, tasaAlExplicar, ingles: trozo.ingles);
    }
  }

  /// Dicta algo para que el niño lo escriba, al ritmo que él haya pedido o al
  /// que se indique en [a].
  ///
  /// [corte] decide cuánto aire se deja. Una frase de dictado se copia palabra
  /// por palabra, así que se dice palabra por palabra. Un problema de
  /// matemáticas no se copia: se entiende, se decide qué cuenta hay que hacer y
  /// se escribe esa. Trocearlo igual que un dictado lo vuelve ininteligible.
  Future<void> dictar(String texto, {Velocidad? a, Corte corte = Corte.palabras}) async {
    if (muda) return;
    final ritmo = a ?? velocidad;
    final trozos = corte == Corte.palabras ? enTrozos(texto) : enFrases(texto);
    final pausa = corte == Corte.palabras
        ? ritmo.pausaEntrePalabras
        : ritmo.pausaEntrePalabras ~/ 2;

    for (var i = 0; i < trozos.length; i++) {
      if (_cancelado) return;
      for (final parte in enIdiomas(trozos[i])) {
        if (_cancelado) return;
        await _hablar(parte.texto, ritmo.tasa, ingles: parte.ingles);
      }
      if (i + 1 < trozos.length) {
        await Future<void>.delayed(Duration(milliseconds: pausa));
      }
    }
  }

  /// Parte un texto en trozos por idioma.
  ///
  /// Lo que va entre comillas angulares se dice en inglés: «What's your name?».
  /// Una frase de un ejercicio de inglés mezcla los dos idiomas —"traduce al
  /// español: «my sister is tall»"— y leerla entera con la voz castellana
  /// convierte el inglés en una ristra de sonidos que no se parecen a nada.
  static List<TrozoHablado> enIdiomas(String texto) {
    final salida = <TrozoHablado>[];
    for (final trozo in texto.split(RegExp(r'(?=«)|(?<=»)'))) {
      final limpio = trozo.trim();
      // Detrás de una frase entrecomillada suele quedar el punto solo. Decirlo
      // aparte es cambiar de idioma para no decir nada.
      if (!RegExp(r'[a-záéíóúüñ0-9]', caseSensitive: false).hasMatch(limpio)) {
        continue;
      }
      final ingles = limpio.startsWith('«') && limpio.endsWith('»');
      salida.add(TrozoHablado(
        ingles ? limpio.substring(1, limpio.length - 1) : limpio,
        ingles: ingles,
      ));
    }
    return salida;
  }

  /// Corta un texto por donde ya se respira al leerlo: comas, puntos y dos
  /// puntos. Es como se dicta un enunciado, no palabra a palabra.
  static List<String> enFrases(String texto) => texto
      .split(RegExp(r'(?<=[,.;:?!])\s+'))
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  /// Corta una frase en los trozos que se dicen de una tirada.
  ///
  /// Palabra a palabra, salvo las muy cortas —"a", "el", "en", "y"— que se
  /// pegan a la siguiente: dichas solas suenan a lista de la compra, y lo que
  /// se está dictando es una frase.
  static List<String> enTrozos(String texto) {
    final palabras =
        texto.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final trozos = <String>[];

    for (final palabra in palabras) {
      final anterior = trozos.isEmpty ? null : trozos.last;
      if (anterior != null && _esCortita(anterior)) {
        trozos[trozos.length - 1] = '$anterior $palabra';
      } else {
        trozos.add(palabra);
      }
    }
    return trozos;
  }

  /// Una palabra demasiado corta para ir sola. Se mira la última del trozo,
  /// que es la que quedaría colgando delante del silencio.
  static bool _esCortita(String trozo) {
    final ultima = trozo.split(' ').last.replaceAll(RegExp(r'[^\wáéíóúüñ]', caseSensitive: false), '');
    return ultima.length <= 2;
  }

  /// Dice el texto y no vuelve hasta que ha terminado de decirlo.
  ///
  /// Con un tope de tiempo: si el motor de voz falla (sin datos de voz, sin
  /// conexión para una voz de red, motor a medio instalar) `speak` puede no
  /// avisar nunca de que ha terminado, y entonces la actividad se queda
  /// congelada para siempre en el primer paso. Es preferible seguir en silencio
  /// —el texto está en pantalla— que dejar al niño mirando una pantalla muerta.
  Future<void> _hablar(String texto, double tasa, {bool ingles = false}) async {
    if (muda) return;
    _cancelado = false;
    await preparar();
    await _cambiarDeIdioma(ingles);
    await _tts.setSpeechRate(tasa);

    final estimada = duracionEstimada(texto, tasa);
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

    // Si a la frase la ha cortado un `parar()` —salir de la actividad, pasar a
    // corregir— ha durado dos décimas por buenos motivos, y eso no dice nada
    // de la voz. Sin esta salida, terminar una actividad hacía que la app
    // diera por muda una voz que iba perfectamente y se cambiara a la
    // siguiente de la lista: de ahí que en la segunda asignatura del día se
    // quedara callada.
    if (_cancelado) return;

    // Red de seguridad para el caso raro en que una voz marcada como
    // instalada devuelva el control al instante: se cambia de voz y se repite
    // la frase, para que el niño pierda un segundo y no el dictado entero.
    if (!_pareceMuda(texto, reloj.elapsed)) {
      _estaVozHaSonado = true;
      return;
    }
    if (await _probarSiguienteVoz()) {
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

  /// Un dictado se dice en varios trozos con silencios en medio. Si el niño
  /// sale de la actividad a mitad de frase, hay que dejar de hablar en el acto
  /// y no seguir con el resto de la frase desde una pantalla que ya no existe.
  bool _cancelado = false;

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

  /// En qué idioma está hablando ahora mismo el motor.
  bool _hablandoEnIngles = false;

  Future<void> _cambiarDeIdioma(bool ingles) async {
    if (ingles == _hablandoEnIngles) return;
    _hablandoEnIngles = ingles;

    final voz = ingles ? _vozInglesa : null;
    if (ingles && voz == null) return; // sin voz inglesa, se dice como se pueda

    await _tts.setLanguage(ingles ? (voz!['locale'] ?? 'en-GB') : 'es-ES');
    if (ingles) {
      await _tts.setVoice({'name': voz!['name']!, 'locale': voz['locale'] ?? 'en-GB'});
    } else if (vozElegida.isNotEmpty) {
      await _tts.setVoice({'name': vozElegida, 'locale': 'es-ES'});
    }
  }

  Future<void> parar() async {
    _cancelado = true;
    if (!muda) await _tts.stop();
  }

}
