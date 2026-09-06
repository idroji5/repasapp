import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../contenido/dictados.dart';
import '../../contenido/matematicas.dart';
import '../../correccion/dictado.dart';
import '../../correccion/tanda.dart';
import '../../correccion/ortografia.dart';
import '../../datos/modelos.dart';
import '../../dominio/actividades.dart';
import '../../dominio/planificador.dart';
import '../../estado.dart';
import '../../voz/frases.dart';
import '../reproductor.dart';
import '../tema.dart';
import '../widgets/botones.dart';
import 'actividad.dart';

/// Corrección: el niño ve en pantalla lo que tenía que salir y dice qué le ha
/// salido a él.
///
/// Aquí no hay cámara ni reconocimiento de escritura. Se probó y el planteamiento no
/// era la precisión: era que cuando el reconocimiento fallaba, la app acusaba
/// al niño de faltas que no había cometido, y eso destruye la confianza más
/// rápido que cualquier otra cosa. Enseñarle la solución con letra de cuaderno
/// y que sea él quien compare es más simple, no se equivoca nunca, y comparar
/// su hoja con la buena ya es parte de aprender a corregirse.
class PantallaRevision extends StatefulWidget {
  const PantallaRevision({
    super.key,
    required this.actividad,
    required this.contenido,
    required this.duracionSegundos,
  });

  final ActividadGuardada actividad;
  final ContenidoActividad contenido;
  final int duracionSegundos;

  @override
  State<PantallaRevision> createState() => _PantallaRevisionState();
}

enum _Fase { marcando, guardando, resultado }

class _PantallaRevisionState extends State<PantallaRevision> {
  _Fase _fase = _Fase.marcando;

  /// Dictado: en qué palabras del texto ha pinchado.
  ///
  /// Se guarda la posición y no la palabra: en "la ventana del salón" hay dos
  /// "la", y tachar una no puede tachar la otra.
  final Set<int> _tachadas = {};
  CorreccionDictado? _correccionDictado;

  /// Matemáticas: qué ejercicios dice que le han salido bien.
  final Map<int, bool> _marcas = {};
  List<ResultadoEjercicio>? _correccionMates;

  CambioDeNivel? _cambioNivel;
  ReproductorGuion? _repaso;

  @override
  void initState() {
    super.initState();
    // Se lee la instrucción en voz alta: el niño sigue con el cuaderno delante
    // y la pantalla es lo que mira de reojo.
    final voz = context.read<AppEstado>().voz;
    unawaited(voz.decir(switch (widget.contenido) {
      ContenidoDictado() => Frases.comparaDictado,
      ContenidoEjercicios() => Frases.comparaOperaciones,
    }));
  }

  @override
  void dispose() {
    _repaso?.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- corregir ---

  Future<void> _corregir() async {
    // Guardar tarda lo que tarde la base de datos y el motor de voz en
    // responder. Sin este estado, el niño puede volver a tocar "Corregir" y
    // arrancar dos repasos que hablan a la vez.
    if (_fase == _Fase.guardando) return;
    setState(() => _fase = _Fase.guardando);

    final estado = context.read<AppEstado>();
    final nino = estado.activo;

    late final int aciertos;
    late final int total;
    late final List<FaltaGuardable> faltas;

    switch (widget.contenido) {
      case ContenidoDictado(:final dictado):
        final correccion = corregirDictadoMarcado(
          dictado,
          [for (final i in _tachadas.toList()..sort()) palabrasDe(dictado.texto)[i]],
        );
        _correccionDictado = correccion;
        aciertos = correccion.aciertos;
        total = correccion.totalPalabras;
        faltas = [
          for (final f in correccion.explicadas)
            if (f.destrezaId case final id?)
              FaltaGuardable(destrezaId: id, tipo: f.tipo.name, esperado: f.esperado),
        ];

      case ContenidoEjercicios(:final ejercicios):
        final resultados = corregirTanda(
          ejercicios,
          {
            for (final entrada in _marcas.entries)
              if (!entrada.value) entrada.key,
          },
        );
        _correccionMates = resultados;
        aciertos = resultados.where((r) => r.correcta).length;
        total = resultados.length;
        faltas = [
          for (final r in resultados)
            if (!r.correcta)
              FaltaGuardable(
                destrezaId: r.ejercicio.destrezaId,
                tipo: 'resultado',
                esperado: r.ejercicio.respuesta,
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
      ContenidoEjercicios() => guionRepasoTanda(
          widget.actividad.asignatura,
          _correccionMates!,
          nino?.modoPistas ?? true,
        ),
    };

    // Por si la instrucción de arriba aún estaba sonando: el repaso empieza
    // hablando y dos voces a la vez no se entienden. Con tope, porque un motor
    // de voz atascado no puede dejar la corrección a medias con el niño
    // esperando delante de la pantalla.
    await estado.voz
        .parar()
        .timeout(const Duration(seconds: 1), onTimeout: () {});
    if (!mounted) return;

    _repaso?.dispose();
    _repaso = ReproductorGuion(guion: guion, voz: estado.voz, oido: estado.oido);

    setState(() {
      _cambioNivel = cambio;
      _fase = _Fase.resultado;
    });
    _repaso!.arrancar();
  }

  /// Volver a hacer lo que ha salido mal.
  ///
  /// Corregir sin poder arreglarlo se queda a medias: lo que enseña de verdad
  /// es volver a la hoja y que esta vez salga. Se crea una actividad nueva en
  /// la sesión de hoy en lugar de reescribir la de antes, para que se vea que
  /// la segunda fue mejor que la primera.
  Future<void> _volverAIntentarlo() async {
    final estado = context.read<AppEstado>();
    final contenido = contenidoRepetido(
      widget.actividad.contenido,
      soloEstos: switch (widget.contenido) {
        ContenidoDictado() => null,
        ContenidoEjercicios() => [
            for (final r in _correccionMates!)
              if (!r.correcta) r.ejercicio.numero,
          ],
      },
    );

    final nueva = await estado.repo.crearActividadExtra(
      ninoId: widget.actividad.ninoId,
      asignatura: widget.actividad.asignatura,
      nivel: widget.actividad.nivel,
      contenido: contenido,
    );
    if (!mounted) return;

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => PantallaActividad(actividad: nueva)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Corrección'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(child: _cuerpo()),
    );
  }

  Widget _cuerpo() {
    if (_fase == _Fase.guardando) {
      return const Center(
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

    if (_fase == _Fase.resultado) {
      return _Resultado(
        dictado: _correccionDictado,
        mates: _correccionMates,
        cambioNivel: _cambioNivel,
        repaso: _repaso,
        onTerminar: () => Navigator.of(context).pop(),
        onRepetir: _volverAIntentarlo,
      );
    }

    return switch (widget.contenido) {
      ContenidoDictado(:final dictado) => _MarcarDictado(
          dictado: dictado,
          tachadas: _tachadas,
          onTachar: (posicion) => setState(() {
            _tachadas.contains(posicion)
                ? _tachadas.remove(posicion)
                : _tachadas.add(posicion);
          }),
          onListo: _corregir,
        ),
      ContenidoEjercicios(:final ejercicios) => _MarcarTanda(
          ejercicios: ejercicios,
          marcas: _marcas,
          onMarcar: (numero, correcta) => setState(() => _marcas[numero] = correcta),
          onTodasBien: () => setState(() {
            for (final op in ejercicios) {
              _marcas[op.numero] = true;
            }
          }),
          onCorregir: _corregir,
        ),
    };
  }
}

// ------------------------------------------------------ marcar el dictado ---

/// El dictado con letra de cuaderno, palabra por palabra y cada una tocable.
///
/// Se corrige sobre el texto y no en una lista aparte, que es como se corrige
/// una hoja de verdad: se tacha lo que está mal, donde está. Y así se puede
/// marcar cualquier palabra, no solo las difíciles, que era lo que obligaba a
/// preguntar después "¿alguna falta más?" y a fiarse de un número.
class _TextoDelDictado extends StatelessWidget {
  const _TextoDelDictado({
    required this.dictado,
    required this.tachadas,
    this.onTachar,
  });

  final Dictado dictado;

  /// Posiciones de las palabras tachadas dentro del texto.
  final Set<int> tachadas;

  /// Si es null, el texto solo se lee: es el de después de corregir.
  final void Function(int posicion)? onTachar;

  @override
  Widget build(BuildContext context) {
    // La numeración tiene que coincidir con la de palabrasDe(texto), que es de
    // donde sale luego la palabra que se corrige.
    var posicion = -1;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 20),
      decoration: Tema.cajaTarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final frase in dictado.fragmentos)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final trozo in frase.split(RegExp(r'\s+')))
                    if (palabrasDe(trozo).isNotEmpty)
                      _Palabra(
                        trozo: trozo,
                        tachada: tachadas.contains(++posicion),
                        dificil:
                            dictado.palabrasClave.any((p) => _esLaMisma(trozo, p)),
                        onTocar: onTachar == null
                            ? null
                            : _alTocar(onTachar!, posicion),
                      ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// La posición hay que atraparla ahora: cuando se ejecute el callback, el
  /// contador ya estará en otra palabra.
  static VoidCallback _alTocar(void Function(int) onTachar, int posicion) =>
      () => onTachar(posicion);
}

/// Una palabra del dictado. Tocarla la tacha; volver a tocarla la destacha.
class _Palabra extends StatelessWidget {
  const _Palabra({
    required this.trozo,
    required this.tachada,
    required this.dificil,
    required this.onTocar,
  });

  final String trozo;
  final bool tachada;

  /// Una de las palabras que este dictado pone a prueba. Va en negrita: es un
  /// "mira bien esta", no un botón distinto de los demás.
  final bool dificil;

  final VoidCallback? onTocar;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTocar,
      behavior: HitTestBehavior.opaque,
      child: Container(
        // El hueco que se toca es más grande que la palabra: un niño apunta con
        // el dedo, no con un ratón.
        margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        decoration: tachada
            ? BoxDecoration(
                color: Tema.falloSuave,
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Text(
          trozo,
          style: Tema.deCuaderno(
            tamano: 32,
            color: tachada ? Tema.fallo : Tema.tinta,
            peso: dificil ? FontWeight.w700 : FontWeight.w400,
            decoracion: tachada ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }
}

/// Compara una palabra suelta del texto con una palabra clave, sin que la
/// puntuación pegada estropee la comparación ("campo." es "campo").
bool _esLaMisma(String enElTexto, String clave) {
  final limpia = palabrasDe(enElTexto).join(' ').toLowerCase();
  return limpia == clave.toLowerCase();
}

/// La hoja del dictado, para tachar encima lo que ha salido mal.
class _MarcarDictado extends StatelessWidget {
  const _MarcarDictado({
    required this.dictado,
    required this.tachadas,
    required this.onTachar,
    required this.onListo,
  });

  final Dictado dictado;
  final Set<int> tachadas;
  final void Function(int posicion) onTachar;
  final VoidCallback onListo;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              Text(dictado.titulo, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              const Text(
                'Compáralo con tu hoja y toca las palabras que hayas escrito mal.',
                style: TextStyle(color: Tema.tintaSuave, fontSize: 16, height: 1.4),
              ),
              const SizedBox(height: 18),
              _TextoDelDictado(
                dictado: dictado,
                tachadas: tachadas,
                onTachar: onTachar,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          child: BotonGrande(
            texto: switch (tachadas.length) {
              0 => 'No he fallado ninguna',
              1 => 'Corregir, con una falta',
              final n => 'Corregir, con $n faltas',
            },
            onPressed: onListo,
          ),
        ),
      ],
    );
  }
}

class _MarcarTanda extends StatelessWidget {
  const _MarcarTanda({
    required this.ejercicios,
    required this.marcas,
    required this.onMarcar,
    required this.onTodasBien,
    required this.onCorregir,
  });

  final List<Ejercicio> ejercicios;
  final Map<int, bool> marcas;
  final void Function(int numero, bool correcta) onMarcar;
  final VoidCallback onTodasBien;
  final VoidCallback onCorregir;

  @override
  Widget build(BuildContext context) {
    final faltanPorMarcar = ejercicios.any((op) => !marcas.containsKey(op.numero));

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Las soluciones',
                            style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 6),
                        const Text(
                          'Mira tu cuaderno y marca cuáles te han salido.',
                          style: TextStyle(color: Tema.tintaSuave, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  if (faltanPorMarcar)
                    TextButton(
                      onPressed: onTodasBien,
                      style: TextButton.styleFrom(foregroundColor: Tema.acierto),
                      child: const Text('Todas bien'),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              for (final op in ejercicios)
                _TarjetaSolucion(
                  ejercicio: op,
                  marca: marcas[op.numero],
                  onMarcar: (correcta) => onMarcar(op.numero, correcta),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          child: BotonGrande(
            texto: faltanPorMarcar ? 'Marca todas para seguir' : 'Corregir',
            onPressed: faltanPorMarcar ? null : onCorregir,
          ),
        ),
      ],
    );
  }
}

/// Un ejercicio con su solución, y los dos botones para decir si salió.
class _TarjetaSolucion extends StatelessWidget {
  const _TarjetaSolucion({
    required this.ejercicio,
    required this.marca,
    required this.onMarcar,
  });

  final Ejercicio ejercicio;
  final bool? marca;
  final void Function(bool correcta) onMarcar;

  @override
  Widget build(BuildContext context) {
    final color = switch (marca) {
      true => Tema.acierto,
      false => Tema.fallo,
      null => Tema.borde,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: Tema.tarjeta,
        borderRadius: BorderRadius.circular(Tema.radio),
        border: Border.all(color: color, width: marca == null ? 1 : 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${ejercicio.numero}',
              style: const TextStyle(
                color: Tema.tintaSuave,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              )),
          if (ejercicio.planteamiento case final enunciado?) ...[
            const SizedBox(height: 6),
            Text(enunciado, style: Tema.deCuaderno(tamano: 26)),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
          // Cuenta y resultado en un solo párrafo: la respuesta puede llevar
          // unidad ("55 euros", "32 resto 12") y en columnas separadas se parte
          // por donde no debe.
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: ejercicio.enunciado,
                  style: Tema.deNumeros(tamano: 28, peso: FontWeight.w700),
                ),
                TextSpan(
                  text: '  =  ',
                  style: Tema.deNumeros(tamano: 28, color: Tema.tintaSuave),
                ),
                TextSpan(
                  text: ejercicio.respuesta,
                  style: Tema.deNumeros(
                    tamano: 28,
                    peso: FontWeight.w700,
                    color: Tema.acierto,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _BotonMarca(
                  texto: 'Me ha salido',
                  icono: Icons.check_rounded,
                  color: Tema.acierto,
                  activo: marca == true,
                  onPressed: () => onMarcar(true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BotonMarca(
                  texto: 'No me ha salido',
                  icono: Icons.close_rounded,
                  color: Tema.fallo,
                  activo: marca == false,
                  onPressed: () => onMarcar(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BotonMarca extends StatelessWidget {
  const _BotonMarca({
    required this.texto,
    required this.icono,
    required this.color,
    required this.activo,
    required this.onPressed,
  });

  final String texto;
  final IconData icono;
  final Color color;
  final bool activo;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icono, size: 22),
      label: Text(texto, textAlign: TextAlign.center),
      style: OutlinedButton.styleFrom(
        foregroundColor: activo ? Colors.white : color,
        backgroundColor: activo ? color : Tema.tarjeta,
        minimumSize: const Size(0, 54),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        side: BorderSide(color: color, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ------------------------------------------------------------- resultado ---

/// Lo que ha salido, con la voz explicando los fallos uno a uno.
class _Resultado extends StatelessWidget {
  const _Resultado({
    required this.dictado,
    required this.mates,
    required this.cambioNivel,
    required this.repaso,
    required this.onTerminar,
    required this.onRepetir,
  });

  final CorreccionDictado? dictado;
  final List<ResultadoEjercicio>? mates;
  final CambioDeNivel? cambioNivel;
  final ReproductorGuion? repaso;
  final VoidCallback onTerminar;
  final VoidCallback onRepetir;

  /// Cuántos fallos hay que arreglar. Si no hay ninguno, no hay nada que
  /// repetir y ofrecerlo solo sería ruido.
  int get _fallos =>
      dictado?.faltas ?? mates!.where((r) => !r.correcta).length;

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
              if (_fallos > 0) ...[
                BotonComando(
                  texto: dictado != null
                      ? 'Repetir el dictado'
                      : (_fallos == 1
                          ? 'Volver a hacer la que fallé'
                          : 'Volver a hacer las que fallé'),
                  icono: Icons.replay_rounded,
                  onPressed: onRepetir,
                ),
                const SizedBox(height: 10),
              ],
              BotonGrande(texto: 'Terminar', onPressed: onTerminar),
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
            style: Tema.deNumeros(tamano: 44, peso: FontWeight.w700, color: color),
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
          SePuedeDecir(comandos: r.comandos, seEscucha: r.oido.disponible),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final comando in r.comandos)
                if (comando.tieneBoton)
                  BotonComando(
                    texto: comando.etiqueta!,
                    onPressed: () => r.responder(comando),
                  ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Las palabras que ha marcado, con la regla que explica cada una.
class _FaltasDeDictado extends StatelessWidget {
  const _FaltasDeDictado({required this.correccion});

  final CorreccionDictado correccion;

  @override
  Widget build(BuildContext context) {
    if (correccion.explicadas.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cómo se escriben', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        for (final falta in correccion.explicadas)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Tema.falloSuave,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  falta.esperado,
                  style: Tema.deCuaderno(
                    tamano: 34,
                    peso: FontWeight.w700,
                    color: Tema.acierto,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _capitalizar(razonDe(falta)),
                  style: const TextStyle(fontSize: 15.5, height: 1.4, color: Tema.tinta),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String _capitalizar(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

class _FaltasDeMates extends StatelessWidget {
  const _FaltasDeMates({required this.resultados});

  final List<ResultadoEjercicio> resultados;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Los ejercicios', style: Theme.of(context).textTheme.titleMedium),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  r.correcta ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: r.correcta ? Tema.acierto : Tema.fallo,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${r.ejercicio.enunciado}  =  ',
                          style: Tema.deNumeros(tamano: 21, peso: FontWeight.w700),
                        ),
                        TextSpan(
                          text: r.ejercicio.respuesta,
                          style: Tema.deNumeros(
                            tamano: 21,
                            color: r.correcta ? Tema.tintaSuave : Tema.fallo,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
