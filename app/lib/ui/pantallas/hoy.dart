import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../datos/modelos.dart';
import '../../dominio/asignaturas.dart';
import '../../dominio/planificador.dart';
import '../../estado.dart';
import '../tema.dart';
import '../widgets/botones.dart';
import 'actividad.dart';

/// El plan de hoy.
///
/// Es la pantalla que decide si la app se usa o no: el niño la abre y ya tiene
/// el trabajo del día preparado. No hay catálogo, no hay que elegir nada.
class PantallaHoy extends StatefulWidget {
  const PantallaHoy({super.key, required this.nino});

  final Nino nino;

  @override
  State<PantallaHoy> createState() => _PantallaHoyState();
}

class _PantallaHoyState extends State<PantallaHoy> {
  SesionDelDia? _sesion;
  int _racha = 0;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final repo = context.read<AppEstado>().repo;
    final sesion = await repo.sesionDeHoy(widget.nino.id);
    final stats = await repo.estadisticas(widget.nino.id);
    if (!mounted) return;
    setState(() {
      _sesion = sesion;
      _racha = stats.racha;
      _cargando = false;
    });
  }

  ActividadGuardada? get _siguiente => _sesion?.actividades
      .where((a) => a.estado != EstadoActividad.corregida)
      .firstOrNull;

  Future<void> _empezar(ActividadGuardada actividad) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PantallaActividad(actividad: actividad)),
    );
    if (mounted) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    // El nombre puede haber cambiado en la zona de padres mientras tanto.
    final nino = context.watch<AppEstado>().ninos.firstWhere(
          (n) => n.id == widget.nino.id,
          orElse: () => widget.nino,
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(nino.nombre),
        actions: [
          if (_racha > 1)
            Padding(
              padding: const EdgeInsets.only(right: 16, top: 14, bottom: 14),
              child: Pastilla(
                '$_racha días seguidos',
                icono: Icons.local_fire_department,
                color: Tema.logro,
                fondo: Tema.logroSuave,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _contenido(context, nino),
      ),
    );
  }

  Widget _contenido(BuildContext context, Nino nino) {
    final sesion = _sesion!;
    final siguiente = _siguiente;

    if (sesion.actividades.isEmpty) {
      return const _Aviso(
        titulo: 'Hoy no hay nada preparado',
        detalle: 'Sube los minutos diarios en la zona de padres para que quepa '
            'al menos una actividad.',
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              Text(
                siguiente == null ? '¡Terminado por hoy!' : 'El plan de hoy',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                siguiente == null
                    ? 'Has hecho las ${sesion.actividades.length} actividades. Mañana seguimos.'
                    : '${sesion.minutos} minutos · ${sesion.hechas} de '
                        '${sesion.actividades.length} hechas',
                style: const TextStyle(color: Tema.tintaSuave, fontSize: 16),
              ),
              const SizedBox(height: 22),
              for (final actividad in sesion.actividades) ...[
                _TarjetaActividad(
                  actividad: actividad,
                  esSiguiente: actividad.id == siguiente?.id,
                  onPulsar: () => _empezar(actividad),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        if (siguiente != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: BotonGrande(
              texto: sesion.hechas == 0 ? 'Empezar' : 'Seguir',
              icono: Icons.play_arrow_rounded,
              onPressed: () => _empezar(siguiente),
            ),
          ),
      ],
    );
  }
}

class _TarjetaActividad extends StatelessWidget {
  const _TarjetaActividad({
    required this.actividad,
    required this.esSiguiente,
    required this.onPulsar,
  });

  final ActividadGuardada actividad;
  final bool esSiguiente;
  final VoidCallback onPulsar;

  @override
  Widget build(BuildContext context) {
    final color = Tema.colorDe(actividad.asignatura.name);
    final hecha = actividad.corregida;

    return Opacity(
      opacity: hecha ? 0.62 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(Tema.radio),
          onTap: hecha ? null : onPulsar,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: Tema.cajaTarjeta.copyWith(
              border: Border.all(
                color: esSiguiente ? color : Tema.borde,
                width: esSiguiente ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: hecha ? Tema.acierto.withValues(alpha: 0.12)
                                 : color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    hecha
                        ? Icons.check_rounded
                        : actividad.asignatura == Asignatura.dictado
                            ? Icons.hearing_rounded
                            : Icons.calculate_outlined,
                    color: hecha ? Tema.acierto : color,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        actividad.asignatura.nombre,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hecha && actividad.total != null
                            ? '${actividad.aciertos} de ${actividad.total} bien'
                            : '${tituloDe(actividad.contenido)} · nivel ${actividad.nivel}/5',
                        style: const TextStyle(color: Tema.tintaSuave, fontSize: 14.5),
                      ),
                    ],
                  ),
                ),
                if (!hecha) const Icon(Icons.chevron_right, color: Tema.tintaSuave),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.titulo, required this.detalle});

  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(titulo, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              Text(
                detalle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Tema.tintaSuave, fontSize: 16, height: 1.5),
              ),
            ],
          ),
        ),
      );
}
