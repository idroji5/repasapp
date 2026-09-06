import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../datos/modelos.dart';
import '../../dominio/actividades.dart';
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
  final _comenzado = DateTime.now();

  @override
  void initState() {
    super.initState();
    final estado = context.read<AppEstado>();

    _contenido = reconstruir(widget.actividad.contenido, widget.actividad.nivel);
    final guion = switch (_contenido) {
      ContenidoDictado(:final dictado) => guionDictado(dictado),
      ContenidoOperaciones(:final operaciones) => guionMatematicas(operaciones),
    };

    _reproductor = ReproductorGuion(
      guion: guion,
      voz: estado.voz,
      oido: estado.oido,
      // Da igual si ha dicho "corregir" o si ha tocado el botón: el reproductor
      // avisa cuando la actividad ha terminado, por donde sea.
      alRevisar: _corregir,
    );

    estado.repo.marcarEnCurso(widget.actividad.id);
    _reproductor.arrancar();
  }

  @override
  void dispose() {
    _reproductor.dispose();
    super.dispose();
  }

  /// A corregir. No hay foto ni reconocimiento: el niño ve la solución en
  /// pantalla y compara con su cuaderno.
  Future<void> _corregir() async {
    if (!mounted) return;
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
                  _Controles(reproductor: r, onCorregir: _corregir),
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

/// La zona grande: lo que se dice, o el reloj de la pausa para escribir.
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
            r.fase == Fase.hablando ? Icons.volume_up_rounded : Icons.hearing_rounded,
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

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (r.esperaAlNino)
            // Sin reloj: la app espera lo que haga falta. Copiar una cuenta de
            // oído es un tiro único, y meter prisa solo consigue perderla.
            Container(
              width: 168,
              height: 168,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.edit_outlined, size: 62, color: color),
            )
          else
            SizedBox(
              width: 168,
              height: 168,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: r.pausaTotal == 0
                          ? 0
                          : (r.segundosRestantes / r.pausaTotal).clamp(0.0, 1.0),
                      strokeWidth: 10,
                      backgroundColor: Tema.borde,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${r.segundosRestantes}',
                        style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w700),
                      ),
                      const Text('segundos', style: TextStyle(color: Tema.tintaSuave)),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 26),
          Text(
            r.esperaAlNino ? 'Cópiala y resuélvela' : 'Escríbelo',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            r.esperaAlNino
                ? 'Sin prisa. Di «continúa» cuando la tengas'
                : 'Cuando lo tengas, di «continúa»',
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

/// La barra de abajo: botones para todo lo que también se puede decir en voz
/// alta. La voz es un atajo; el botón es la garantía.
class _Controles extends StatelessWidget {
  const _Controles({required this.reproductor, required this.onCorregir});

  final ReproductorGuion reproductor;
  final VoidCallback onCorregir;

  @override
  Widget build(BuildContext context) {
    final r = reproductor;

    if (r.fase == Fase.revisar) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          children: [
            SePuedeDecir(comandos: const [Comando.corregir], seEscucha: r.oido.disponible),
            BotonGrande(
              texto: 'Corregir',
              icono: Icons.check_circle_outline_rounded,
              onPressed: () => r.responder(Comando.corregir),
            ),
          ],
        ),
      );
    }

    final comandos = r.comandos;
    if (comandos.isEmpty) return const SizedBox(height: 24);

    // "Estoy listo" es el paso adelante y merece el botón grande, aunque haya
    // otras cosas que se puedan decir en ese momento.
    if (comandos.contains(Comando.listo)) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          children: [
            SePuedeDecir(comandos: comandos, seEscucha: r.oido.disponible),
            BotonGrande(
              texto: Comando.listo.etiqueta!,
              icono: Icons.check_rounded,
              onPressed: () => r.responder(Comando.listo),
            ),
          ],
        ),
      );
    }

    // Solo llegan a la barra los comandos con botón. Los demás —cambiar la
    // velocidad— se dicen, y se recuerdan como texto justo encima.
    final conBoton = comandos.where((c) => c.tieneBoton).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      child: Column(
        children: [
          SePuedeDecir(comandos: comandos, seEscucha: r.oido.disponible),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (final comando in conBoton)
                BotonComando(
                  texto: comando.etiqueta!,
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
          ),
        ],
      ),
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
