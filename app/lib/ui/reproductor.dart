import 'dart:async';

import 'package:flutter/foundation.dart';

import '../dominio/asignaturas.dart';
import '../dominio/guion.dart';
import '../voz/escucha.dart';
import '../voz/locutora.dart';

enum Fase { inicial, hablando, escribiendo, esperando, preguntando, foto, terminado }

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
    this.alPedirFoto,
    this.alTerminar,
  });

  final Guion guion;
  final Locutora voz;
  final Escucha oido;
  final VoidCallback? alPedirFoto;
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
  /// tanda de operaciones no: lo que se practica es la cuenta, no copiarla al
  /// oído, así que ahí sí se puede revelar si se atasca.
  bool get permiteRevelar => guion.asignatura == Asignatura.matematicas;
  bool revelado = false;

  /// true mientras se dicta un fragmento. Su texto no se enseña salvo que el
  /// niño lo revele, y revelar solo se permite donde no es hacer trampa.
  bool enFragmento = false;

  /// Lo que se está diciendo, o null si no debe verse.
  String? get textoVisible => (!enFragmento || revelado) ? texto : null;

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
    if (fase != Fase.foto) {
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
        await _decir(texto, Fase.hablando, const []);

      case Fragmento(:final texto, :final indice, :final pausaSegundos, :final avanzaSolo):
        fragmentoActual = indice + 1;
        revelado = false;
        enFragmento = true;

        // Se repite tantas veces como el niño pida, cada vez a la velocidad
        // que tenga puesta en ese momento.
        var repetir = true;
        while (repetir && !_cancelado) {
          await _decir(texto, Fase.hablando, guion.comandosGlobales);
          if (_cancelado) return;
          final accion = await _pausaParaEscribir(pausaSegundos, avanzaSolo);
          repetir = accion == _AccionPausa.repetir;
        }

      case Espera(:final texto, :final comandos):
        enFragmento = false;
        await _decir(texto, Fase.esperando, comandos);
        if (_cancelado) return;
        await _esperarComando(comandos, Fase.esperando);

      case Pregunta(:final texto, :final opciones):
        enFragmento = false;
        final posibles = opciones.map((o) => o.comando).toList();
        await _decir(texto, Fase.preguntando, posibles);
        if (_cancelado) return;

        final elegido = await _esperarComando(posibles, Fase.preguntando);
        final rama = opciones.firstWhere(
          (o) => o.comando == elegido,
          orElse: () => opciones.first,
        );
        await _ejecutarLista(rama.pasos);

      case PedirFoto(:final texto):
        enFragmento = false;
        await _decir(texto, Fase.hablando, const []);
        if (_cancelado) return;
        _cambiar(Fase.foto);
        alPedirFoto?.call();
    }
  }

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
        _cerrarPausa(_AccionPausa.repetir);
      case Comando.continua:
        _cerrarPausa(_AccionPausa.seguir);
      case Comando.listo || Comando.loTengo || Comando.otraPista:
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
