import 'dart:async';

import 'package:flutter/foundation.dart';

import '../dominio/asignaturas.dart';
import '../dominio/guion.dart';
import '../voz/locutora.dart';

enum Fase { inicial, hablando, escribiendo, esperando, preguntando, revisar, terminado }

/// Recorre un guion: dice cada paso, calla lo que haga falta y espera a que el
/// niño pulse.
///
/// La pantalla no sabe nada de pedagogía; solo pinta [fase], [texto] y
/// [comandos]. Toda la lógica de qué se dice y cuándo vive aquí y en el guion.
///
/// Nada avanza solo. La app dice lo suyo y se queda quieta hasta que el niño
/// toca un botón: no hay cuenta atrás, no hay siguiente frase por sorpresa y no
/// hay micrófono escuchando. Un niño que escribe despacio no tiene por qué
/// perder el dictado por eso.
class ReproductorGuion extends ChangeNotifier {
  ReproductorGuion({
    required this.guion,
    required this.voz,
    this.alRevisar,
    this.alTerminar,
  });

  final Guion guion;
  final Locutora voz;
  final VoidCallback? alRevisar;
  final VoidCallback? alTerminar;

  Fase fase = Fase.inicial;

  /// Lo que la voz está diciendo ahora mismo.
  String texto = '';

  /// Comandos disponibles en este instante, como botones.
  List<Comando> comandos = const [];

  int fragmentoActual = 0;
  int totalFragmentos = 0;

  /// En un dictado, enseñar el texto sería hacerle la trampa al niño. En una
  /// tanda de cuentas o de inglés no: lo que se practica es resolverlo, no
  /// retenerlo de oído, así que ahí sí se puede revelar si se atasca.
  bool get permiteRevelar => guion.asignatura != Asignatura.dictado;
  bool revelado = false;

  /// true mientras se dicta un fragmento. Su texto no se enseña salvo que el
  /// niño lo revele, y revelar solo se permite donde no es hacer trampa.
  bool enFragmento = false;

  /// Cómo se escribe lo que se está dictando, cuando no se escribe igual que
  /// se dice. Es lo que se enseña al revelar: al cuaderno va "742 : 7", no
  /// "setecientos cuarenta y dos entre siete".
  String? escritoActual;

  /// Lo que se está diciendo, o null si no debe verse.
  String? get textoVisible =>
      (!enFragmento || revelado) ? (escritoActual ?? texto) : null;

  bool _cancelado = false;
  Completer<_AccionPausa>? _pausa;
  Completer<Comando>? _respuesta;

  Future<void> arrancar() async {
    totalFragmentos = guion.pasos.whereType<Fragmento>().length;
    await voz.preparar();
    if (guion.velocidadInicial case final ritmo?) voz.velocidad = ritmo;
    await _ejecutarLista(guion.pasos);

    if (_cancelado) return;
    if (fase != Fase.revisar) {
      _cambiar(Fase.terminado);
      alTerminar?.call();
    }
  }

  Future<void> _ejecutarLista(List<Paso> pasos) async {
    for (final paso in pasos) {
      if (_cancelado) return;
      await _ejecutar(paso);
    }
  }

  Future<void> _ejecutar(Paso paso) async {
    switch (paso) {
      case Habla(:final texto):
        enFragmento = false;
        escritoActual = null;
        await _decir(texto, Fase.hablando, const []);

      case Fragmento(
          :final texto,
          :final indice,
          :final veces,
          :final escrito,
          :final palabraAPalabra
        ):
        fragmentoActual = indice + 1;
        revelado = false;
        enFragmento = true;
        escritoActual = escrito;

        // Se repite tantas veces como el niño pida, cada vez a la velocidad
        // que tenga puesta en ese momento.
        var repetir = true;
        while (repetir && !_cancelado) {
          await _leerFragmento(texto, veces, palabraAPalabra);
          if (_cancelado) return;
          final accion = await _pausaParaEscribir();
          repetir = accion == _AccionPausa.repetir;
        }

      case Espera(:final texto, :final comandos):
        enFragmento = false;
        escritoActual = null;
        await _preguntar(texto, comandos, Fase.esperando);

      case Pregunta(:final texto, :final opciones):
        enFragmento = false;
        escritoActual = null;
        final posibles = opciones.map((o) => o.comando).toList();

        final elegido = await _preguntar(texto, posibles, Fase.preguntando);
        if (_cancelado) return;
        final rama = opciones.firstWhere(
          (o) => o.comando == elegido,
          orElse: () => opciones.first,
        );
        await _ejecutarLista(rama.pasos);

      case Revisar(:final texto):
        enFragmento = false;
        escritoActual = null;
        await _decir(texto, Fase.revisar, const [Comando.corregir]);
        if (_cancelado) return;
        await _esperarComando(const [Comando.corregir], Fase.revisar);
        if (_cancelado) return;
        alRevisar?.call();
    }
  }

  /// Cuánto se calla entre las dos lecturas de la misma frase. Lo justo para
  /// que el niño oiga que empieza otra vez y no las junte en una sola, y para
  /// que le dé tiempo a escribir el principio antes de que vuelva a sonar.
  static const Duration _respiroEntreLecturas = Duration(seconds: 3);

  /// Dicta una frase [veces] veces seguidas.
  ///
  /// La segunda va un punto más despacio que la primera: así es como repite
  /// quien dicta de verdad, y así la repetición sirve para escribir y no solo
  /// para volver a oír lo mismo al mismo ritmo.
  Future<void> _leerFragmento(String queDecir, int veces, bool palabraAPalabra) async {
    for (var vez = 0; vez < veces && !_cancelado; vez++) {
      texto = queDecir;
      // Mientras la voz está diciendo la frase solo se ofrece lo que de verdad
      // hace algo: cambiar el ritmo. "Repite" y "Siguiente" son respuestas a la
      // pausa, y un botón que no hace nada al pulsarlo es peor que no tenerlo.
      comandos = guion.comandosGlobales
          .where((c) => c == Comando.masDespacio || c == Comando.masRapido)
          .toList();
      _cambiar(Fase.hablando);
      // Esto es lo único que se dicta: lo que el niño tiene que escribir.
      await voz.dictar(
        queDecir,
        a: vez == 0 ? null : voz.velocidad.masLenta,
        corte: palabraAPalabra ? Corte.palabras : Corte.frases,
      );

      if (vez + 1 < veces && !_cancelado) {
        await Future<void>.delayed(_respiroEntreLecturas);
      }
    }
  }

  /// Lo que la app explica —instrucciones, preguntas, correcciones— va a ritmo
  /// de conversación. Dicho a ritmo de dictado se hace eterno.
  Future<void> _decir(String queDecir, Fase nueva, List<Comando> disponibles) async {
    texto = queDecir;
    comandos = disponibles;
    _cambiar(nueva);
    await voz.decir(queDecir);
  }

  // ------------------------------------------------- pausa para escribir ---

  /// Se calla y espera. Sin reloj y sin límite: hasta que el niño pulse.
  ///
  /// Antes había cuenta atrás en el dictado y la frase siguiente entraba sola
  /// al agotarse. Para un niño que empieza a escribir eso es una carrera
  /// perdida: se queda a media palabra, oye que ya va otra frase y abandona.
  Future<_AccionPausa> _pausaParaEscribir() async {
    comandos = guion.comandosGlobales;
    _cambiar(Fase.escribiendo);

    final pausa = _pausa = Completer<_AccionPausa>();
    return pausa.future;
  }

  void _cerrarPausa(_AccionPausa accion) {
    if (_pausa?.isCompleted == false) _pausa!.complete(accion);
  }

  // --------------------------------------------------- esperar respuesta ---

  /// Dice algo y espera a que conteste, repitiéndolo tantas veces como pida.
  ///
  /// "Repite" vale en cualquier pregunta, no solo dictando: una pregunta que
  /// no se ha oído bien deja al niño mirando la pantalla sin saber qué le han
  /// preguntado, y entonces la voz deja de servir para nada.
  Future<Comando> _preguntar(
    String texto,
    List<Comando> posibles,
    Fase fase,
  ) async {
    final conRepite = [...posibles, Comando.repite];
    while (!_cancelado) {
      await _decir(texto, fase, conRepite);
      if (_cancelado) break;
      final dicho = await _esperarComando(conRepite, fase);
      if (dicho != Comando.repite) return dicho;
    }
    return posibles.first;
  }

  Future<Comando> _esperarComando(List<Comando> posibles, Fase enFase) async {
    comandos = posibles;
    _cambiar(enFase);

    final respuesta = _respuesta = Completer<Comando>();
    return respuesta.future;
  }

  // ------------------------------------------------------------ acciones ---

  /// Lo que llega desde un botón de la pantalla.
  void responder(Comando comando) {
    switch (comando) {
      case Comando.masDespacio:
        voz.velocidad = voz.velocidad.masLenta;
        _cerrarPausa(_AccionPausa.repetir);
      case Comando.masRapido:
        voz.velocidad = voz.velocidad.masRapida;
        _cerrarPausa(_AccionPausa.repetir);
      case Comando.repite:
        // Dictando, repetir es volver a decir el fragmento; en una pregunta,
        // volver a hacerla. Son dos esperas distintas y solo hay una activa.
        if (_respuesta?.isCompleted == false) {
          _respuesta!.complete(Comando.repite);
        } else {
          _cerrarPausa(_AccionPausa.repetir);
        }
      case Comando.continua:
        _cerrarPausa(_AccionPausa.seguir);
      case Comando.listo ||
            Comando.corregir ||
            Comando.loTengo ||
            Comando.otraPista:
        if (_respuesta?.isCompleted == false) _respuesta!.complete(comando);
    }
    notifyListeners();
  }

  /// Enseña el enunciado en pantalla. Solo en matemáticas; ver [permiteRevelar].
  void revelar() {
    if (!permiteRevelar) return;
    revelado = true;
    notifyListeners();
  }

  /// Da por buena la pausa y pasa al siguiente fragmento.
  void seguir() => responder(Comando.continua);

  void _cambiar(Fase nueva) {
    fase = nueva;
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelado = true;
    if (_pausa?.isCompleted == false) _pausa!.complete(_AccionPausa.seguir);
    if (_respuesta?.isCompleted == false) _respuesta!.complete(Comando.continua);
    unawaited(voz.parar());
    super.dispose();
  }
}

enum _AccionPausa { seguir, repetir }
