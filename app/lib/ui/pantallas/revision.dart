import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../correccion/alinear.dart';
import '../../correccion/interpretar.dart';
import '../../correccion/matematicas.dart' as mat;
import '../../correccion/ocr.dart';
import '../../datos/modelos.dart';
import '../../dominio/actividades.dart';
import '../../dominio/planificador.dart';
import '../../estado.dart';
import '../reproductor.dart';
import '../tema.dart';
import '../widgets/botones.dart';

/// Lee la foto del cuaderno, corrige y explica los fallos de viva voz.
///
/// La foto NO se guarda: se pasa por ML Kit, se saca el texto y se descarta.
/// De todo esto solo sobrevive el resultado (qué se escribió mal), que es lo
/// único que hace falta para enseñar y para las estadísticas del padre.
class PantallaRevision extends StatefulWidget {
  const PantallaRevision({
    super.key,
    required this.actividad,
    required this.contenido,
    required this.rutaFoto,
    required this.duracionSegundos,
  });

  final ActividadGuardada actividad;
  final ContenidoActividad contenido;
  final String rutaFoto;
  final int duracionSegundos;

  @override
  State<PantallaRevision> createState() => _PantallaRevisionState();
}

enum _Fase { leyendo, resultado, corrigiendoLectura, error }

class _PantallaRevisionState extends State<PantallaRevision> {
  _Fase _fase = _Fase.leyendo;
  String _mensajeError = '';

  /// Lo que el OCR ha leído. Editable: ML Kit se equivoca con la letra
  /// manuscrita y el niño tiene que poder decir "yo no escribí eso".
  late final TextEditingController _leido = TextEditingController();
  final Map<int, TextEditingController> _resultados = {};

  Correccion? _correccionDictado;
  List<mat.ResultadoOperacion>? _correccionMates;
  CambioDeNivel? _cambioNivel;
  ReproductorGuion? _repaso;

  @override
  void initState() {
    super.initState();
    _leerFoto();
  }

  @override
  void dispose() {
    _leido.dispose();
    for (final c in _resultados.values) {
      c.dispose();
    }
    _repaso?.dispose();
    super.dispose();
  }

  Future<void> _leerFoto() async {
    final ocr = OcrMlKit();
    try {
      final lineas = await ocr.leer(widget.rutaFoto);

      switch (widget.contenido) {
        case ContenidoDictado():
          _leido.text = transcripcionDeLineas(lineas);
        case ContenidoOperaciones(:final operaciones):
          for (final lectura in interpretarTanda(lineas, operaciones)) {
            _resultados[lectura.numero] =
                TextEditingController(text: lectura.resultadoEscrito);
          }
      }
      await _corregir();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fase = _Fase.error;
        _mensajeError = 'No he podido leer la foto. Prueba con más luz y '
            'que la hoja se vea entera.';
      });
    } finally {
      await ocr.cerrar();
    }
  }

  Future<void> _corregir() async {
    if (!mounted) return;
    final estado = context.read<AppEstado>();
    final nino = estado.activo;

    late final int aciertos;
    late final int total;
    late final List<FaltaGuardable> faltas;

    switch (widget.contenido) {
      case ContenidoDictado(:final dictado):
        final correccion = corregirDictado(dictado.texto, _leido.text);
        _correccionDictado = correccion;
        aciertos = correccion.aciertos;
        total = correccion.totalPalabras;
        faltas = [
          for (final f in correccion.faltas)
            if (f.destrezaId case final id?)
              FaltaGuardable(
                destrezaId: id,
                tipo: f.tipo.name,
                esperado: f.esperado,
                escrito: f.escrito,
              ),
        ];

      case ContenidoOperaciones(:final operaciones):
        final resultados = mat.corregirTanda(operaciones, [
          for (final op in operaciones)
            mat.LecturaEjercicio(
              numero: op.numero,
              operacionEscrita: op.enunciado,
              resultadoEscrito: _resultados[op.numero]?.text ?? '',
            ),
        ]);
        _correccionMates = resultados;
        aciertos = resultados.where((r) => r.correcta).length;
        total = resultados.length;
        faltas = [
          for (final r in resultados)
            if (!r.correcta)
              FaltaGuardable(
                destrezaId: r.operacion.destrezaId,
                tipo: r.motivo?.name ?? 'resultado',
                esperado: r.operacion.respuesta,
                escrito: r.escrito,
              ),
        ];
    }

    final cambio = await estado.repo.guardarCorreccion(
      actividadId: widget.actividad.id,
      ninoId: widget.actividad.ninoId,
      asignatura: widget.actividad.asignatura,
      aciertos: aciertos,
      total: total,
      faltas: faltas,
      duracionSegundos: widget.duracionSegundos,
    );
    await estado.cargar();
    if (!mounted) return;

    final guion = switch (widget.contenido) {
      ContenidoDictado() => guionRepasoDictado(_correccionDictado!),
      ContenidoOperaciones() => guionRepasoMatematicas(
          _correccionMates!,
          nino?.modoPistas ?? true,
        ),
    };

    _repaso?.dispose();
    _repaso = ReproductorGuion(guion: guion, voz: estado.voz, oido: estado.oido);

    setState(() {
      _cambioNivel = cambio ?? _cambioNivel;
      _fase = _Fase.resultado;
    });
    _repaso!.arrancar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Corrección'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: switch (_fase) {
          _Fase.leyendo => const _Leyendo(),
          _Fase.error => _Error(mensaje: _mensajeError, onSalir: _salir),
          _Fase.corrigiendoLectura => _EditorDeLectura(
              contenido: widget.contenido,
              leido: _leido,
              resultados: _resultados,
              onAceptar: () {
                setState(() => _fase = _Fase.leyendo);
                _repaso?.dispose();
                _repaso = null;
                _corregir();
              },
            ),
          _Fase.resultado => _Resultado(
              contenido: widget.contenido,
              dictado: _correccionDictado,
              mates: _correccionMates,
              cambioNivel: _cambioNivel,
              repaso: _repaso,
              onEditarLectura: () => setState(() => _fase = _Fase.corrigiendoLectura),
              onTerminar: _salir,
            ),
        },
      ),
    );
  }

  void _salir() => Navigator.of(context).pop();
}

class _Leyendo extends StatelessWidget {
  const _Leyendo();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 22),
            Text('Déjame mirarlo un momento…', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
}

class _Error extends StatelessWidget {
  const _Error({required this.mensaje, required this.onSalir});

  final String mensaje;
  final VoidCallback onSalir;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography_outlined, size: 48, color: Tema.tintaSuave),
            const SizedBox(height: 18),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, height: 1.5),
            ),
            const SizedBox(height: 28),
            BotonGrande(texto: 'Volver', onPressed: onSalir),
          ],
        ),
      );
}

/// Lo que ha salido, con la voz explicando los fallos uno a uno.
class _Resultado extends StatelessWidget {
  const _Resultado({
    required this.contenido,
    required this.dictado,
    required this.mates,
    required this.cambioNivel,
    required this.repaso,
    required this.onEditarLectura,
    required this.onTerminar,
  });

  final ContenidoActividad contenido;
  final Correccion? dictado;
  final List<mat.ResultadoOperacion>? mates;
  final CambioDeNivel? cambioNivel;
  final ReproductorGuion? repaso;
  final VoidCallback onEditarLectura;
  final VoidCallback onTerminar;

  int get _aciertos => dictado?.aciertos ?? mates!.where((r) => r.correcta).length;
  int get _total => dictado?.totalPalabras ?? mates!.length;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: [
              _Marcador(aciertos: _aciertos, total: _total),
              if (cambioNivel != null) ...[
                const SizedBox(height: 16),
                _AvisoNivel(cambio: cambioNivel!),
              ],
              const SizedBox(height: 20),

              // Lo que la voz está diciendo ahora mismo, escrito también: si el
              // niño se ha despistado, lo puede leer.
              if (repaso != null)
                ListenableBuilder(
                  listenable: repaso!,
                  builder: (context, _) => _LoQueDice(reproductor: repaso!),
                ),

              const SizedBox(height: 22),
              if (dictado != null) _FaltasDeDictado(correccion: dictado!),
              if (mates != null) _FaltasDeMates(resultados: mates!),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          child: Column(
            children: [
              BotonGrande(texto: 'Terminar', onPressed: onTerminar),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: onEditarLectura,
                icon: const Icon(Icons.edit_outlined, size: 19),
                label: const Text('Yo no escribí eso'),
                style: TextButton.styleFrom(
                  foregroundColor: Tema.tintaSuave,
                  minimumSize: const Size(0, 48),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Marcador extends StatelessWidget {
  const _Marcador({required this.aciertos, required this.total});

  final int aciertos;
  final int total;

  @override
  Widget build(BuildContext context) {
    final perfecto = aciertos == total;
    final color = perfecto ? Tema.acierto : Tema.tinta;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 22),
      decoration: Tema.cajaTarjeta,
      child: Column(
        children: [
          Text(
            '$aciertos de $total',
            style: TextStyle(fontSize: 42, fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            perfecto ? '¡Sin ni un fallo!' : 'bien',
            style: const TextStyle(color: Tema.tintaSuave, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _AvisoNivel extends StatelessWidget {
  const _AvisoNivel({required this.cambio});

  final CambioDeNivel cambio;

  @override
  Widget build(BuildContext context) {
    final color = cambio.sube ? Tema.logro : Tema.accion;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (cambio.sube ? Tema.logroSuave : Tema.accionSuave),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(cambio.sube ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cambio.sube
                      ? '${cambio.asignatura.nombre} sube a nivel ${cambio.despues}'
                      : '${cambio.asignatura.nombre} baja a nivel ${cambio.despues}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(cambio.motivo,
                    style: const TextStyle(color: Tema.tintaSuave, fontSize: 13.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoQueDice extends StatelessWidget {
  const _LoQueDice({required this.reproductor});

  final ReproductorGuion reproductor;

  @override
  Widget build(BuildContext context) {
    final r = reproductor;
    if (r.texto.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              r.fase == Fase.hablando ? Icons.volume_up_rounded : Icons.hearing_rounded,
              size: 20,
              color: Tema.accion,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(r.texto, style: Theme.of(context).textTheme.bodyLarge),
            ),
          ],
        ),
        if (r.comandos.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final comando in r.comandos)
                BotonComando(
                  texto: comando.etiqueta,
                  onPressed: () => r.responder(comando),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _FaltasDeDictado extends StatelessWidget {
  const _FaltasDeDictado({required this.correccion});

  final Correccion correccion;

  @override
  Widget build(BuildContext context) {
    if (correccion.faltas.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Lo que hay que repasar',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        for (final falta in correccion.faltas)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Tema.falloSuave,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                if (falta.escrito.isNotEmpty)
                  Text(
                    falta.escrito,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Tema.fallo,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                if (falta.escrito.isNotEmpty && falta.esperado.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.arrow_forward_rounded, size: 17, color: Tema.tintaSuave),
                  ),
                Text(
                  falta.esperado.isEmpty ? '(sobra)' : falta.esperado,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Tema.acierto,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FaltasDeMates extends StatelessWidget {
  const _FaltasDeMates({required this.resultados});

  final List<mat.ResultadoOperacion> resultados;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Las operaciones', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        for (final r in resultados)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: r.correcta ? Tema.tarjeta : Tema.falloSuave,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: r.correcta ? Tema.borde : Tema.falloSuave),
            ),
            child: Row(
              children: [
                Icon(
                  r.correcta ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: r.correcta ? Tema.acierto : Tema.fallo,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    r.operacion.enunciado,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                if (!r.correcta)
                  Text(
                    r.motivo == mat.MotivoFallo.sinHacer
                        ? 'sin hacer'
                        : '${r.escrito.isEmpty ? "—" : r.escrito} → ${r.operacion.respuesta}',
                    style: const TextStyle(fontSize: 15.5, color: Tema.fallo),
                  )
                else
                  Text(r.operacion.respuesta,
                      style: const TextStyle(fontSize: 16, color: Tema.tintaSuave)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Arreglar lo que el OCR leyó mal.
///
/// ML Kit está hecho para texto impreso: con letra ligada se equivoca a menudo.
/// Sin esta pantalla, un fallo del reconocimiento se convertiría en una falta
/// de ortografía que el niño no ha cometido, y eso destruye la confianza en la
/// app mucho más rápido que cualquier otra cosa.
class _EditorDeLectura extends StatelessWidget {
  const _EditorDeLectura({
    required this.contenido,
    required this.leido,
    required this.resultados,
    required this.onAceptar,
  });

  final ContenidoActividad contenido;
  final TextEditingController leido;
  final Map<int, TextEditingController> resultados;
  final VoidCallback onAceptar;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              Text('Esto es lo que he leído',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text(
                'Escríbelo igual que está en tu hoja, con las faltas incluidas. '
                'Así te corrijo bien.',
                style: TextStyle(color: Tema.tintaSuave, fontSize: 15.5, height: 1.45),
              ),
              const SizedBox(height: 20),
              switch (contenido) {
                ContenidoDictado() => TextField(
                    controller: leido,
                    maxLines: null,
                    minLines: 6,
                    style: const TextStyle(fontSize: 18, height: 1.5),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Tema.tarjeta,
                      contentPadding: const EdgeInsets.all(16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Tema.borde),
                      ),
                    ),
                  ),
                ContenidoOperaciones(:final operaciones) => Column(
                    children: [
                      for (final op in operaciones)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${op.numero}.  ${op.enunciado}',
                                  style: const TextStyle(
                                      fontSize: 17, fontWeight: FontWeight.w600),
                                ),
                              ),
                              SizedBox(
                                width: 130,
                                child: TextField(
                                  controller: resultados[op.numero],
                                  textAlign: TextAlign.center,
                                  keyboardType: const TextInputType.numberWithOptions(
                                    signed: true,
                                    decimal: true,
                                  ),
                                  style: const TextStyle(fontSize: 18),
                                  decoration: InputDecoration(
                                    hintText: '—',
                                    filled: true,
                                    fillColor: Tema.tarjeta,
                                    contentPadding:
                                        const EdgeInsets.symmetric(vertical: 14),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(color: Tema.borde),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
              },
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: BotonGrande(texto: 'Corregir otra vez', onPressed: onAceptar),
        ),
      ],
    );
  }
}
