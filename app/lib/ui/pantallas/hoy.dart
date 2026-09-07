import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../datos/modelos.dart';
import '../../dominio/asignaturas.dart';
import '../../dominio/planificador.dart';
import '../../estado.dart';
import '../navegacion.dart';
import '../tema.dart';
import '../widgets/botones.dart';
import 'actividad.dart';
import 'coleccion.dart';

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

class _PantallaHoyState extends State<PantallaHoy> with RouteAware {
  SesionDelDia? _sesion;
  int _racha = 0;
  List<NounGuardado> _nouns = const [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ruta = ModalRoute.of(context);
    if (ruta is PageRoute) observadorDeRutas.subscribe(this, ruta);
  }

  @override
  void dispose() {
    observadorDeRutas.unsubscribe(this);
    super.dispose();
  }

  /// Se ha cerrado lo que había encima y esta pantalla vuelve a verse.
  ///
  /// Es el único momento fiable para recargar. Esperar a que termine el
  /// `push` de la actividad no vale: la actividad se sustituye a sí misma por
  /// la pantalla de corrección, y eso ya da por terminada la espera. La nota se
  /// guardaba después, así que la lista se refrescaba con los datos de antes y
  /// la asignatura recién hecha seguía saliendo como pendiente.
  @override
  void didPopNext() => _cargar();

  Future<void> _cargar() async {
    final repo = context.read<AppEstado>().repo;
    final sesion = await repo.sesionDeHoy(widget.nino.id);
    final stats = await repo.estadisticas(widget.nino.id);
    final nouns = await repo.coleccion(widget.nino.id);
    if (!mounted) return;
    setState(() {
      _sesion = sesion;
      _racha = stats.racha;
      _nouns = nouns;
      _cargando = false;
    });
  }

  ActividadGuardada? get _siguiente => _sesion?.actividades
      .where((a) => a.estado != EstadoActividad.corregida)
      .firstOrNull;

  Future<void> _empezar(ActividadGuardada actividad) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaActividad(actividad: actividad),
      ),
    );
    if (mounted) _cargar();
  }

  /// Volver a hacer algo que ya se ha hecho hoy.
  ///
  /// Repetir un dictado que ha salido regular, o las cuentas del lunes, es de
  /// las cosas más útiles que puede hacer un niño con esta app, y hasta ahora
  /// la tarjeta de una actividad terminada sencillamente no se dejaba tocar.
  ///
  /// Se crea una actividad nueva en lugar de reabrir la de antes: así el primer
  /// resultado no se pierde y en la zona de padres se ve la mejora.
  Future<void> _repetir(ActividadGuardada actividad) async {
    final repetir = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Lo vuelves a hacer?'),
        content: Text(
          actividad.total == null
              ? 'Ya lo hiciste hoy.'
              : 'Hoy te salieron ${actividad.aciertos} de ${actividad.total}. '
                    'Puedes volver a hacerlo y ver si mejoras.',
          style: const TextStyle(fontSize: 16, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Ahora no'),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Volver a hacerlo'),
          ),
        ],
      ),
    );
    if (repetir != true || !mounted) return;

    final repo = context.read<AppEstado>().repo;
    final nueva = await repo.crearActividadExtra(
      ninoId: actividad.ninoId,
      asignatura: actividad.asignatura,
      nivel: actividad.nivel,
      contenido: contenidoRepetido(actividad.contenido),
    );
    if (!mounted) return;
    await _empezar(nueva);
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
        detalle:
            'Sube los minutos diarios en la zona de padres para que quepa '
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
                    ? 'Has hecho las ${sesion.actividades.length} actividades. '
                          'Si quieres, toca una para repetirla.'
                    : '${sesion.minutos} minutos · ${sesion.hechas} de '
                          '${sesion.actividades.length} hechas',
                style: const TextStyle(color: Tema.tintaSuave, fontSize: 16),
              ),
              const SizedBox(height: 22),
              for (final actividad in sesion.actividades) ...[
                _TarjetaActividad(
                  actividad: actividad,
                  esSiguiente: actividad.id == siguiente?.id,
                  onPulsar: () => actividad.corregida
                      ? _repetir(actividad)
                      : _empezar(actividad),
                ),
                const SizedBox(height: 12),
              ],
              // Al final de la lista y en pequeño, a propósito: la pantalla
              // que el niño abre para ponerse a trabajar no puede empezar con
              // un premio, o los deberes se vuelven el peaje del juego.
              if (context.read<AppEstado>().catalogo case final catalogo?) ...[
                const SizedBox(height: 10),
                TarjetaColeccion(nino: nino, nouns: _nouns, catalogo: catalogo),
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Tema.radio),
        onTap: onPulsar,
        child: Container(
          padding: const EdgeInsets.all(18),
          // Lo hecho se pinta de verde entero, no solo con una marca pequeña:
          // el niño mira la lista de lejos, desde el cuaderno, y lo que tiene
          // que ver de un vistazo es qué lleva hecho y qué le queda.
          decoration: Tema.cajaTarjeta.copyWith(
            color: hecha ? Tema.aciertoSuave : Tema.tarjeta,
            border: Border.all(
              color: hecha ? Tema.acierto : (esSiguiente ? color : Tema.borde),
              width: hecha || esSiguiente ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: hecha ? Tema.acierto : color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  hecha ? Icons.check_rounded : _icono(actividad.asignatura),
                  color: hecha ? Colors.white : color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      actividad.asignatura.nombre,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: hecha ? Tema.acierto : null,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hecha && actividad.total != null
                          ? '${actividad.aciertos} de ${actividad.total} bien'
                          : '${tituloDe(actividad.contenido)} · nivel ${actividad.nivel}/5',
                      style: TextStyle(
                        color: hecha ? Tema.acierto : Tema.tintaSuave,
                        fontSize: 14.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                hecha ? Icons.replay_rounded : Icons.chevron_right,
                color: hecha ? Tema.acierto : Tema.tintaSuave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _icono(Asignatura asignatura) => switch (asignatura) {
  Asignatura.dictado => Icons.hearing_rounded,
  Asignatura.matematicas => Icons.calculate_outlined,
  Asignatura.ingles => Icons.translate_rounded,
};

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
            style: const TextStyle(
              color: Tema.tintaSuave,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    ),
  );
}
