import 'dart:async';

import 'package:flutter/foundation.dart';

import '../dominio/asignaturas.dart';
import '../dominio/guion.dart';
import '../voz/escucha.dart';
import '../voz/locutora.dart';

enum Fase { inicial, hablando, escribiendo, esperando, preguntando, revisar, terminado }

/// Recorre un guion: dice cada paso, calla lo que haga falta y atiende a lo que
/// el niño pida por voz o por botón.
///
/// La pantalla no sabe nada de pedagogía; solo pinta [fase], [texto] y
/// [comandos]. Toda la lógica de qué se dice y cuándo vive aquí y en el guion.
class ReproductorGuion extends ChangeNotifier {
  ReproductorGuion({
    required this.guion,
    required this.voz,
    required this.oido,
    this.alRevisar,
    this.alTerminar,
  });

  final Guion guion;
  final Locutora voz;
  final Escucha oido;
  final VoidCallback? alRevisar;
  final VoidCallback? alTerminar;

  Fase fase = Fase.inicial;

  /// Lo que la voz está diciendo ahora mismo.
  String texto = '';

  /// Comandos disponibles en este instante, como botones y como palabras.
  List<Comando> comandos = const [];

  /// Segundos que quedan de la pausa para escribir.
  int segundosRestantes = 0;
  int pausaTotal = 0;

  int fragmentoActual = 0;
  int totalFragmentos = 0;

  /// true cuando la app está parada esperando al niño, sin cuenta atrás.
  bool esperaAlNino = false;

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
  Timer? _cuentaAtras;
  Completer<_AccionPausa>? _pausa;
  Completer<Comando>? _respuesta;

  Future<void> arrancar() async {
    totalFragmentos = guion.pasos.whereType<Fragmento>().length;
    await voz.preparar();
    await oido.preparar();
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
          :final pausaSegundos,
          :final avanzaSolo,
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
          final accion = await _pausaParaEscribir(pausaSegundos, avanzaSolo);
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
        // Se queda escuchando "corregir" en vez de esperar a que toque el
        // botón: el niño acaba de soltar el lápiz y tiene la hoja en la mano.
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
  static const Duration _respiroEntreLecturas = Duration(seconds: 2);

  /// Dicta una frase [veces] veces seguidas.
  ///
  /// La segunda va un punto más despacio que la primera: así es como repite
  /// quien dicta de verdad, y así la repetición sirve para escribir y no solo
  /// para volver a oír lo mismo al mismo ritmo.
  Future<void> _leerFragmento(String queDecir, int veces, bool palabraAPalabra) async {
    for (var vez = 0; vez < veces && !_cancelado; vez++) {
      texto = queDecir;
      comandos = guion.comandosGlobales;
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

  Future<_AccionPausa> _pausaParaEscribir(int segundos, bool avanzaSolo) async {
    // Sin cuenta atrás, `pausaTotal` es 0 y la pantalla enseña otra cosa: no
    // hay reloj que mirar porque nadie mete prisa.
    pausaTotal = avanzaSolo ? segundos : 0;
    segundosRestantes = avanzaSolo ? segundos : 0;
    esperaAlNino = !avanzaSolo;
    comandos = guion.comandosGlobales;
    _cambiar(Fase.escribiendo);

    final pausa = _pausa = Completer<_AccionPausa>();

    if (avanzaSolo) {
      _cuentaAtras = Timer.periodic(const Duration(seconds: 1), (_) {
        segundosRestantes--;
        if (segundosRestantes <= 0) {
          _cerrarPausa(_AccionPausa.seguir);
        } else {
          notifyListeners();
        }
      });
    }

    // Se escucha en paralelo: el niño puede decir "repite" sin soltar el lápiz.
    unawaited(_escucharDeFondo(guion.comandosGlobales));

    final accion = await pausa.future;
    _cuentaAtras?.cancel();
    await oido.parar();
    esperaAlNino = false;
    return accion;
  }

  void _cerrarPausa(_AccionPausa accion) {
    _cuentaAtras?.cancel();
    if (_pausa?.isCompleted == false) _pausa!.complete(accion);
  }

  Future<void> _escucharDeFondo(List<Comando> posibles) async {
    if (!oido.disponible || posibles.isEmpty) return;
    // Mientras la app espera al niño hay que seguir escuchando: si la escucha
    // se agotara, "continúa" dejaría de funcionar y solo quedaría el botón.
    while (!_cancelado && _pausa?.isCompleted == false) {
      final dicho = await oido.escucharComando(
        posibles,
        limite: Duration(seconds: segundosRestantes > 0 ? segundosRestantes + 5 : 40),
      );
      if (_cancelado) return;
      if (dicho != null) {
        responder(dicho);
        return;
      }
      if (!esperaAlNino) return; // con cuenta atrás basta un intento
    }
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

    // Se reintenta la escucha mientras no conteste: un solo `listen` se agota a
    // los 30 segundos, y un niño puede tardar bastante más en tener el papel
    // preparado. Sin el reintento, decir "listo" tarde dejaba de funcionar.
    unawaited(() async {
      if (!oido.disponible) return;
      while (!respuesta.isCompleted && !_cancelado) {
        final dicho = await oido.escucharComando(posibles);
        if (dicho != null && !respuesta.isCompleted) {
          respuesta.complete(dicho);
          return;
        }
      }
    }());

    final comando = await respuesta.future;
    await oido.parar();
    return comando;
  }

  // ------------------------------------------------------------ acciones ---

  /// Lo que llega desde un botón de la pantalla o desde el micrófono.
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
    _cuentaAtras?.cancel();
    if (_pausa?.isCompleted == false) _pausa!.complete(_AccionPausa.seguir);
    if (_respuesta?.isCompleted == false) _respuesta!.complete(Comando.continua);
    unawaited(voz.parar());
    unawaited(oido.parar());
    super.dispose();
  }
}

enum _AccionPausa { seguir, repetir }
