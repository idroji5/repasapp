import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../contenido/dictados.dart';
import '../../contenido/matematicas.dart';
import '../../correccion/dictado.dart';
import '../../correccion/matematicas.dart' as mat;
import '../../correccion/ortografia.dart';
import '../../datos/modelos.dart';
import '../../dominio/actividades.dart';
import '../../dominio/planificador.dart';
import '../../estado.dart';
import '../../voz/frases.dart';
import '../reproductor.dart';
import '../tema.dart';
import '../widgets/botones.dart';

/// Corrección: el niño ve en pantalla lo que tenía que salir y dice qué le ha
/// salido a él.
///
/// Aquí no hay cámara ni reconocimiento de escritura. Se probó y el problema no
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

enum _Fase { marcando, faltasSueltas, guardando, resultado }

/// Tope de la pregunta "¿cuántas faltas más?". Por encima de esto el número
/// exacto da igual: lo que toca es repetir el dictado otro día, no contar.
const int _maxFaltasQuePregunta = 5;

class _PantallaRevisionState extends State<PantallaRevision> {
  _Fase _fase = _Fase.marcando;

  /// Dictado: qué palabras dice haber fallado, y cuántas faltas más ha tenido
  /// en palabras que la app no señala.
  final Set<String> _palabrasFalladas = {};
  int _faltasSueltas = 0;
  CorreccionDictado? _correccionDictado;

  /// Matemáticas: qué ejercicios dice que le han salido bien.
  final Map<int, bool> _marcas = {};
  List<mat.ResultadoOperacion>? _correccionMates;

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
      ContenidoOperaciones() => Frases.comparaOperaciones,
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
          _palabrasFalladas.length + _faltasSueltas,
          _palabrasFalladas.toList(),
        );
        _correccionDictado = correccion;
        aciertos = correccion.aciertos;
        total = correccion.totalPalabras;
        faltas = [
          for (final f in correccion.explicadas)
            if (f.destrezaId case final id?)
              FaltaGuardable(destrezaId: id, tipo: f.tipo.name, esperado: f.esperado),
        ];

      case ContenidoOperaciones(:final operaciones):
        final resultados = mat.corregirTanda(
          operaciones,
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
                destrezaId: r.operacion.destrezaId,
                tipo: 'resultado',
                esperado: r.operacion.respuesta,
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

  /// Marcadas las palabras, queda saber si se le ha escapado alguna más: las
  /// palabras señaladas son las trampas del dictado, no todas las palabras.
  void _preguntarPorLasDemas() {
    setState(() => _fase = _Fase.faltasSueltas);
    unawaited(context.read<AppEstado>().voz.decir(Frases.algunaFaltaMas));
  }

  void _responderFaltasSueltas(int cuantas) {
    _faltasSueltas = cuantas;
    _corregir();
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
      );
    }

    if (_fase == _Fase.faltasSueltas) {
      return _FaltasSueltas(onResponder: _responderFaltasSueltas);
    }

    return switch (widget.contenido) {
      ContenidoDictado(:final dictado) => _MarcarDictado(
          dictado: dictado,
          seleccionadas: _palabrasFalladas,
          onCambiar: (palabra, marcada) => setState(() {
            marcada ? _palabrasFalladas.add(palabra) : _palabrasFalladas.remove(palabra);
          }),
          onListo: _preguntarPorLasDemas,
        ),
      ContenidoOperaciones(:final operaciones) => _MarcarOperaciones(
          operaciones: operaciones,
          marcas: _marcas,
          onMarcar: (numero, correcta) => setState(() => _marcas[numero] = correcta),
          onTodasBien: () => setState(() {
            for (final op in operaciones) {
              _marcas[op.numero] = true;
            }
          }),
          onCorregir: _corregir,
        ),
    };
  }
}

// ------------------------------------------------------ marcar el dictado ---

/// El dictado escrito con letra de cuaderno, para compararlo con la hoja.
class _TextoDelDictado extends StatelessWidget {
  const _TextoDelDictado({required this.dictado, this.resaltadas = const {}});

  final Dictado dictado;

  /// Palabras que se pintan en rojo: las que el niño ha dicho que falló.
  final Set<String> resaltadas;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      decoration: Tema.cajaTarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final frase in dictado.fragmentos)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _Frase(
                frase: frase,
                clave: dictado.palabrasClave,
                resaltadas: resaltadas,
              ),
            ),
        ],
      ),
    );
  }
}

/// Una frase del dictado. Las palabras difíciles van subrayadas —son las que la
/// app sabe explicar— y las que el niño marca como falladas, en rojo.
class _Frase extends StatelessWidget {
  const _Frase({required this.frase, required this.clave, required this.resaltadas});

  final String frase;
  final List<String> clave;
  final Set<String> resaltadas;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: [for (final trozo in frase.split(' ')) _palabra(trozo)]),
    );
  }

  /// Las palabras difíciles van subrayadas —son las que hay que marcar— y las
  /// que el niño ha marcado, en rojo.
  TextSpan _palabra(String trozo) {
    final normal = Tema.deCuaderno(tamano: 32);
    if (!clave.any((p) => _esLaMisma(trozo, p))) {
      return TextSpan(text: '$trozo ', style: normal);
    }

    // El subrayado señala la palabra, no la coma que va detrás.
    final partes = _signosSueltos.firstMatch(trozo)!;
    return TextSpan(children: [
      TextSpan(text: partes.group(1), style: normal),
      TextSpan(
        text: partes.group(2),
        style: Tema.deCuaderno(
          tamano: 32,
          color: resaltadas.any((p) => _esLaMisma(trozo, p))
              ? Tema.fallo
              : Tema.tinta,
          peso: FontWeight.w700,
          subrayado: TextDecoration.underline,
        ),
      ),
      TextSpan(text: '${partes.group(3)} ', style: normal),
    ]);
  }
}

/// Los signos pegados a una palabra, delante y detrás.
final RegExp _signosSueltos = RegExp(r'^([¿¡«"(]*)(.*?)([.,;:!?»")]*)$');

/// Compara una palabra suelta del texto con una palabra clave, sin que la
/// puntuación pegada estropee la comparación ("campo." es "campo").
bool _esLaMisma(String enElTexto, String clave) {
  final limpia = palabrasDe(enElTexto).join(' ').toLowerCase();
  return limpia == clave.toLowerCase();
}

/// El dictado con sus palabras difíciles, para tocar las que haya fallado.
///
/// Todo a la vez y sin prisa: lee su hoja, la compara con la pantalla y va
/// tocando. Se pregunta por las palabras y no por un número de faltas porque
/// una palabra se puede explicar —"había lleva hache"— y un número no.
class _MarcarDictado extends StatelessWidget {
  const _MarcarDictado({
    required this.dictado,
    required this.seleccionadas,
    required this.onCambiar,
    required this.onListo,
  });

  final Dictado dictado;
  final Set<String> seleccionadas;
  final void Function(String palabra, bool marcada) onCambiar;
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
                'Compáralo con tu hoja, sin prisa.',
                style: TextStyle(color: Tema.tintaSuave, fontSize: 16),
              ),
              const SizedBox(height: 18),
              _TextoDelDictado(dictado: dictado, resaltadas: seleccionadas),
              const SizedBox(height: 24),
              Text(
                'Toca las que hayas escrito mal',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final palabra in dictado.palabrasClave)
                    _ChipPalabra(
                      palabra: palabra,
                      marcada: seleccionadas.contains(palabra),
                      onCambiar: (v) => onCambiar(palabra, v),
                    ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          child: BotonGrande(
            texto: seleccionadas.isEmpty ? 'No he fallado ninguna' : 'Ya está',
            onPressed: onListo,
          ),
        ),
      ],
    );
  }
}

/// Las faltas en palabras que la app no señala.
///
/// Las palabras clave son las trampas del dictado, pero no son todas: sin esta
/// pregunta, quien se deja una tilde en cualquier otra palabra saca un diez.
class _FaltasSueltas extends StatelessWidget {
  const _FaltasSueltas({required this.onResponder});

  final void Function(int cuantas) onResponder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '¿Alguna falta más?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'En otras palabras, de las que no te he señalado.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Tema.tintaSuave, fontSize: 16, height: 1.4),
          ),
          const SizedBox(height: 26),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              BotonComando(
                texto: 'Ninguna',
                icono: Icons.check_rounded,
                onPressed: () => onResponder(0),
              ),
              for (var i = 1; i <= _maxFaltasQuePregunta; i++)
                _BotonNumero(numero: i, onPressed: () => onResponder(i)),
              BotonComando(
                texto: 'Más de $_maxFaltasQuePregunta',
                onPressed: () => onResponder(_maxFaltasQuePregunta + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BotonNumero extends StatelessWidget {
  const _BotonNumero({required this.numero, required this.onPressed});

  final int numero;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      height: 68,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: Tema.tarjeta,
          side: const BorderSide(color: Tema.borde, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          '$numero',
          style: Tema.deNumeros(tamano: 28, peso: FontWeight.w700),
        ),
      ),
    );
  }
}

class _ChipPalabra extends StatelessWidget {
  const _ChipPalabra({
    required this.palabra,
    required this.marcada,
    required this.onCambiar,
  });

  final String palabra;
  final bool marcada;
  final ValueChanged<bool> onCambiar;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onCambiar(!marcada),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: marcada ? Tema.falloSuave : Tema.tarjeta,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: marcada ? Tema.fallo : Tema.borde,
            width: marcada ? 2 : 1.5,
          ),
        ),
        child: Text(
          palabra,
          style: Tema.deCuaderno(
            tamano: 28,
            color: marcada ? Tema.fallo : Tema.tinta,
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------- marcar las operaciones ---

class _MarcarOperaciones extends StatelessWidget {
  const _MarcarOperaciones({
    required this.operaciones,
    required this.marcas,
    required this.onMarcar,
    required this.onTodasBien,
    required this.onCorregir,
  });

  final List<Operacion> operaciones;
  final Map<int, bool> marcas;
  final void Function(int numero, bool correcta) onMarcar;
  final VoidCallback onTodasBien;
  final VoidCallback onCorregir;

  @override
  Widget build(BuildContext context) {
    final faltanPorMarcar = operaciones.any((op) => !marcas.containsKey(op.numero));

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
              for (final op in operaciones)
                _TarjetaSolucion(
                  operacion: op,
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
    required this.operacion,
    required this.marca,
    required this.onMarcar,
  });

  final Operacion operacion;
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
          Text('${operacion.numero}',
              style: const TextStyle(
                color: Tema.tintaSuave,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              )),
          if (operacion.problema case final enunciado?) ...[
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
                  text: operacion.enunciado,
                  style: Tema.deNumeros(tamano: 28, peso: FontWeight.w700),
                ),
                TextSpan(
                  text: '  =  ',
                  style: Tema.deNumeros(tamano: 28, color: Tema.tintaSuave),
                ),
                TextSpan(
                  text: operacion.respuesta,
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
  });

  final CorreccionDictado? dictado;
  final List<mat.ResultadoOperacion>? mates;
  final CambioDeNivel? cambioNivel;
  final ReproductorGuion? repaso;
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
          child: BotonGrande(texto: 'Terminar', onPressed: onTerminar),
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

  final List<mat.ResultadoOperacion> resultados;

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
                          text: '${r.operacion.enunciado}  =  ',
                          style: Tema.deNumeros(tamano: 21, peso: FontWeight.w700),
                        ),
                        TextSpan(
                          text: r.operacion.respuesta,
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
