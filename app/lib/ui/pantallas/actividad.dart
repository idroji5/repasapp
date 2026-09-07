import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../datos/modelos.dart';
import '../../dominio/actividades.dart';
import '../../dominio/asignaturas.dart';
import '../../dominio/guion.dart';
import '../../dominio/planificador.dart';
import '../../estado.dart';
import '../reproductor.dart';
import '../tema.dart';
import '../widgets/botones.dart';
import 'revision.dart';

/// La actividad en marcha. Es la pantalla que el niño mira de reojo mientras
/// escribe, así que enseña una sola cosa a la vez y con letra muy grande.
class PantallaActividad extends StatefulWidget {
  const PantallaActividad({super.key, required this.actividad});

  final ActividadGuardada actividad;

  @override
  State<PantallaActividad> createState() => _PantallaActividadState();
}

class _PantallaActividadState extends State<PantallaActividad> {
  late final ContenidoActividad _contenido;
  late final ReproductorGuion _reproductor;
  bool _reproductorCerrado = false;
  final _comenzado = DateTime.now();

  @override
  void initState() {
    super.initState();
    final estado = context.read<AppEstado>();

    _contenido = reconstruir(widget.actividad.contenido, widget.actividad.nivel);
    final guion = switch (_contenido) {
      ContenidoDictado(:final dictado) => guionDictado(dictado),
      ContenidoEjercicios(:final ejercicios) =>
        guionTanda(widget.actividad.asignatura, ejercicios),
    };

    _reproductor = ReproductorGuion(
      guion: guion,
      voz: estado.voz,
      alRevisar: _corregir,
    );

    estado.repo.marcarEnCurso(widget.actividad.id);
    _reproductor.arrancar();
  }

  @override
  void dispose() {
    _cerrarReproductor();
    super.dispose();
  }

  /// Calla la voz de esta actividad. Se puede llamar dos veces sin daño.
  void _cerrarReproductor() {
    if (_reproductorCerrado) return;
    _reproductorCerrado = true;
    _reproductor.dispose();
  }

  /// A corregir. No hay foto ni reconocimiento: el niño ve la solución en
  /// pantalla y compara con su cuaderno.
  Future<void> _corregir() async {
    if (!mounted) return;
    // Se calla la voz de la actividad ANTES de cambiar de pantalla. Esta
    // pantalla no se destruye hasta que termina la transición, y para entonces
    // la corrección ya lleva media frase dicha: su `dispose` la cortaba en
    // seco, y desde fuera eso es la voz perdiéndose al terminar la asignatura.
    _cerrarReproductor();
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PantallaRevision(
          actividad: widget.actividad,
          contenido: _contenido,
          duracionSegundos: DateTime.now().difference(_comenzado).inSeconds,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _reproductor,
      builder: (context, _) {
        final r = _reproductor;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (hecho, _) {
            if (!hecho) _confirmarSalida();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(r.guion.titulo),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _confirmarSalida,
              ),
              actions: [
                if (r.totalFragmentos > 0 && r.fragmentoActual > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 16, top: 14, bottom: 14),
                    child: Pastilla(
                      '${r.fragmentoActual} de ${r.totalFragmentos}',
                      color: Tema.colorDe(r.guion.asignatura.name),
                      fondo: Tema.colorDe(r.guion.asignatura.name)
                          .withValues(alpha: 0.10),
                    ),
                  ),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(child: _Escenario(reproductor: r)),
                  _Controles(reproductor: r),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmarSalida() async {
    final salir = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Dejamos la actividad?'),
        content: const Text('Podrás retomarla cuando quieras desde el plan de hoy.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Seguir'),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Dejarlo'),
          ),
        ],
      ),
    );
    if (salir == true && mounted) Navigator.of(context).pop();
  }
}

/// La zona grande: lo que se dice, o el aviso de que toca escribir.
class _Escenario extends StatelessWidget {
  const _Escenario({required this.reproductor});

  final ReproductorGuion reproductor;

  @override
  Widget build(BuildContext context) {
    final r = reproductor;

    if (r.fase == Fase.escribiendo) {
      return _Escribiendo(reproductor: r);
    }

    final visible = r.textoVisible;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            r.fase == Fase.hablando
                ? Icons.volume_up_rounded
                : Icons.touch_app_rounded,
            size: 44,
            color: Tema.colorDe(r.guion.asignatura.name),
          ),
          const SizedBox(height: 26),
          if (visible != null)
            Text(
              visible,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayMedium,
            )
          else
            // Durante el dictado el texto no se enseña: enseñarlo sería
            // convertir el ejercicio en una copia.
            const Text(
              'Escucha…',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 30, color: Tema.tintaSuave),
            ),
        ],
      ),
    );
  }
}

class _Escribiendo extends StatelessWidget {
  const _Escribiendo({required this.reproductor});

  final ReproductorGuion reproductor;

  @override
  Widget build(BuildContext context) {
    final r = reproductor;
    final color = Tema.colorDe(r.guion.asignatura.name);
    final dictando = r.guion.asignatura == Asignatura.dictado;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sin reloj y sin cuenta atrás: la app espera lo que haga falta.
          // Escribir de oído es un tiro único, y meter prisa a un niño de siete
          // años solo consigue que pierda la frase y abandone.
          Container(
            width: 168,
            height: 168,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.edit_outlined, size: 62, color: color),
          ),
          const SizedBox(height: 26),
          Text(
            dictando ? 'Escríbelo' : 'Cópiala y resuélvela',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Sin prisa. Cuando lo tengas, toca «Siguiente»',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Tema.tintaSuave, fontSize: 16),
          ),
          if (r.revelado) ...[
            const SizedBox(height: 24),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                r.escritoActual ?? r.texto,
                textAlign: TextAlign.center,
                style: r.escritoActual != null
                    ? Tema.deNumeros(tamano: 24, peso: FontWeight.w700)
                    : Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// La barra de abajo: todo lo que el niño puede hacer, en botones.
///
/// No hay micrófono. Se probó a escuchar "listo" o "repite" y el reconocedor de
/// Android pita cada vez que se pone a escuchar, justo mientras se dicta.
class _Controles extends StatelessWidget {
  const _Controles({required this.reproductor});

  final ReproductorGuion reproductor;

  @override
  Widget build(BuildContext context) {
    final r = reproductor;

    if (r.fase == Fase.revisar) {
      return _barra(
        principal: Comando.corregir,
        icono: Icons.check_circle_outline_rounded,
        r: r,
      );
    }

    final comandos = r.comandos;

    // Escribiendo, el paso adelante es "Siguiente" y se lleva el botón grande:
    // es lo único que hace falta encontrar sin mirar, con el lápiz en la mano.
    if (r.fase == Fase.escribiendo && comandos.contains(Comando.continua)) {
      return _barra(
        principal: Comando.continua,
        icono: Icons.arrow_forward_rounded,
        r: r,
      );
    }

    // "Estoy listo" es el otro paso adelante, y merece el mismo trato.
    if (comandos.contains(Comando.listo)) {
      return _barra(principal: Comando.listo, icono: Icons.check_rounded, r: r);
    }

    // Con una pista delante, contestar es lo que toca.
    if (comandos.contains(Comando.loTengo)) {
      return _barra(
        principal: Comando.loTengo,
        icono: Icons.lightbulb_outline_rounded,
        r: r,
      );
    }

    final otros = _secundarios(r, const []);
    if (otros == null) return const SizedBox(height: 24);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      child: otros,
    );
  }

  /// El botón grande de lo que toca hacer, y debajo el resto.
  Widget _barra({
    required Comando principal,
    required IconData icono,
    required ReproductorGuion r,
  }) {
    final otros = _secundarios(r, [principal]);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      child: Column(
        children: [
          if (otros != null) ...[otros, const SizedBox(height: 10)],
          BotonGrande(
            texto: principal.etiqueta,
            icono: icono,
            onPressed: () => r.responder(principal),
          ),
        ],
      ),
    );
  }

  /// Lo demás que se puede hacer ahora mismo, en botones pequeños. null si no
  /// hay nada más que ofrecer.
  Widget? _secundarios(ReproductorGuion r, List<Comando> excepto) {
    final otros = r.comandos.where((c) => !excepto.contains(c)).toList();
    if (otros.isEmpty && !(r.permiteRevelar && r.enFragmento && !r.revelado)) {
      return null;
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        for (final comando in otros)
          BotonComando(
            texto: comando.etiqueta,
            icono: _icono(comando),
            onPressed: () => r.responder(comando),
          ),
        if (r.permiteRevelar && r.enFragmento && !r.revelado)
          BotonComando(
            texto: 'Verlo escrito',
            icono: Icons.visibility_outlined,
            onPressed: r.revelar,
          ),
      ],
    );
  }

  static IconData _icono(Comando comando) => switch (comando) {
        Comando.repite => Icons.replay_rounded,
        Comando.masDespacio => Icons.slow_motion_video_rounded,
        Comando.masRapido => Icons.fast_forward_rounded,
        Comando.continua => Icons.arrow_forward_rounded,
        Comando.listo => Icons.check_rounded,
        Comando.corregir => Icons.check_circle_outline_rounded,
        Comando.loTengo => Icons.lightbulb_outline_rounded,
        Comando.otraPista => Icons.help_outline_rounded,
      };
}
