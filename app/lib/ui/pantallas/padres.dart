import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../datos/modelos.dart';
import '../../dominio/asignaturas.dart';
import '../../estado.dart';
import '../tema.dart';
import '../widgets/botones.dart';

/// Zona de padres, detrás de un PIN.
///
/// El PIN no está para defenderse de un atacante: está porque el móvil lo tiene
/// el niño en la mano, y subirse el nivel o mirar las estadísticas de su
/// hermano no debería estar a un toque de distancia.
class PantallaPadres extends StatefulWidget {
  const PantallaPadres({super.key});

  @override
  State<PantallaPadres> createState() => _PantallaPadresState();
}

class _PantallaPadresState extends State<PantallaPadres> {
  bool _abierta = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zona de padres')),
      body: SafeArea(
        child: _abierta
            ? const _Panel()
            : _Cerrojo(onAbrir: () => setState(() => _abierta = true)),
      ),
    );
  }
}

class _Cerrojo extends StatefulWidget {
  const _Cerrojo({required this.onAbrir});
  final VoidCallback onAbrir;

  @override
  State<_Cerrojo> createState() => _CerrojoState();
}

class _CerrojoState extends State<_Cerrojo> {
  final _pin = TextEditingController();
  bool? _hayPin;
  String? _error;

  @override
  void initState() {
    super.initState();
    context.read<AppEstado>().repo.hayPin().then((v) {
      if (mounted) setState(() => _hayPin = v);
    });
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final repo = context.read<AppEstado>().repo;
    final pin = _pin.text;
    if (pin.length != 4) return;

    if (_hayPin == false) {
      await repo.fijarPin(pin);
      widget.onAbrir();
      return;
    }
    if (await repo.comprobarPin(pin)) {
      widget.onAbrir();
    } else {
      setState(() {
        _error = 'Ese PIN no es';
        _pin.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hayPin == null) return const Center(child: CircularProgressIndicator());
    final creando = _hayPin == false;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline_rounded, size: 44, color: Tema.tintaSuave),
          const SizedBox(height: 20),
          Text(
            creando ? 'Crea un PIN de 4 dígitos' : 'Escribe tu PIN',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          if (creando) ...[
            const SizedBox(height: 10),
            const Text(
              'Te lo pediré cada vez que quieras entrar aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Tema.tintaSuave, fontSize: 15.5),
            ),
          ],
          const SizedBox(height: 28),
          TextField(
            controller: _pin,
            autofocus: true,
            obscureText: true,
            maxLength: 4,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 34, letterSpacing: 16),
            decoration: InputDecoration(
              counterText: '',
              errorText: _error,
              filled: true,
              fillColor: Tema.tarjeta,
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Tema.borde),
              ),
            ),
            onChanged: (v) {
              setState(() => _error = null);
              if (v.length == 4) _enviar();
            },
          ),
          const SizedBox(height: 22),
          BotonGrande(
            texto: creando ? 'Guardar PIN' : 'Entrar',
            onPressed: _enviar,
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel();

  @override
  Widget build(BuildContext context) {
    final ninos = context.watch<AppEstado>().ninos;

    if (ninos.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Aún no hay ningún perfil creado.',
              style: TextStyle(fontSize: 17, color: Tema.tintaSuave)),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        for (final nino in ninos) ...[
          _FichaDeNino(nino: nino),
          const SizedBox(height: 20),
        ],
        const _SelectorDeVoz(),
      ],
    );
  }
}

class _FichaDeNino extends StatefulWidget {
  const _FichaDeNino({required this.nino});
  final Nino nino;

  @override
  State<_FichaDeNino> createState() => _FichaDeNinoState();
}

class _FichaDeNinoState extends State<_FichaDeNino> {
  Estadisticas? _stats;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final stats = await context.read<AppEstado>().repo.estadisticas(widget.nino.id);
    if (mounted) setState(() => _stats = stats);
  }

  @override
  Widget build(BuildContext context) {
    final nino = widget.nino;
    final stats = _stats;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: Tema.cajaTarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(nino.nombre, style: Theme.of(context).textTheme.titleLarge),
              ),
              if (stats != null && stats.racha > 0)
                Pastilla(
                  '${stats.racha} ${stats.racha == 1 ? "día" : "días"}',
                  icono: Icons.local_fire_department,
                  color: Tema.logro,
                  fondo: Tema.logroSuave,
                ),
            ],
          ),
          Text(
            '${nino.curso}.º de Primaria',
            style: const TextStyle(color: Tema.tintaSuave, fontSize: 14.5),
          ),

          const SizedBox(height: 22),
          const _Subtitulo('Nivel por asignatura'),
          const SizedBox(height: 4),
          const Text(
            'Se ajusta solo con los resultados. Si lo cambias a mano, queda fijado.',
            style: TextStyle(color: Tema.tintaSuave, fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: 12),
          for (final asignatura in Asignatura.values)
            _FilaNivel(
              nino: nino,
              asignatura: asignatura,
              resumen: stats?.porAsignatura
                  .where((r) => r.asignatura == asignatura)
                  .firstOrNull,
              onCambio: _cargar,
            ),

          if (stats != null && stats.erroresFrecuentes.isNotEmpty) ...[
            const SizedBox(height: 22),
            const _Subtitulo('En lo que más falla'),
            const SizedBox(height: 10),
            for (final e in stats.erroresFrecuentes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(e.nombre, style: const TextStyle(fontSize: 15))),
                    Text(
                      '${e.fallos}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: Tema.fallo, fontSize: 15),
                    ),
                  ],
                ),
              ),
          ],

          if (stats != null && stats.ultimosDias.isNotEmpty) ...[
            const SizedBox(height: 22),
            const _Subtitulo('Últimos 7 días'),
            const SizedBox(height: 12),
            _BarrasDeEstudio(dias: stats.ultimosDias),
          ],

          const SizedBox(height: 22),
          const _Subtitulo('Ajustes'),
          const SizedBox(height: 8),
          _AjusteMinutos(nino: nino),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: nino.modoPistas,
            activeThumbColor: Tema.accion,
            title: const Text('Dar pistas antes de la solución',
                style: TextStyle(fontSize: 15.5)),
            subtitle: const Text(
              'Si lo apagas, la app le dice directamente la respuesta correcta.',
              style: TextStyle(fontSize: 13, color: Tema.tintaSuave),
            ),
            onChanged: (v) =>
                context.read<AppEstado>().actualizarNino(nino.id, modoPistas: v),
          ),
        ],
      ),
    );
  }
}

class _FilaNivel extends StatelessWidget {
  const _FilaNivel({
    required this.nino,
    required this.asignatura,
    required this.resumen,
    required this.onCambio,
  });

  final Nino nino;
  final Asignatura asignatura;
  final ResumenAsignatura? resumen;
  final VoidCallback onCambio;

  @override
  Widget build(BuildContext context) {
    final nivel = nino.nivelDe(asignatura);
    final color = Tema.colorDe(asignatura.name);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(asignatura.nombre,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    if (resumen?.bloqueado ?? false) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.lock_outline, size: 14, color: Tema.tintaSuave),
                    ],
                  ],
                ),
                Text(
                  resumen == null || resumen!.actividades == 0
                      ? 'sin datos todavía'
                      : '${resumen!.actividades} actividades · '
                          '${resumen!.porcentajeAcierto ?? 0}% de acierto',
                  style: const TextStyle(color: Tema.tintaSuave, fontSize: 13),
                ),
              ],
            ),
          ),
          _StepperNivel(
            nivel: nivel,
            color: color,
            onCambio: (n) async {
              await context.read<AppEstado>().fijarNivel(nino.id, asignatura, n);
              onCambio();
            },
          ),
        ],
      ),
    );
  }
}

class _StepperNivel extends StatelessWidget {
  const _StepperNivel({
    required this.nivel,
    required this.color,
    required this.onCambio,
  });

  final int nivel;
  final Color color;
  final ValueChanged<int> onCambio;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: nivel > nivelMinimo ? () => onCambio(nivel - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
          color: Tema.tintaSuave,
        ),
        Container(
          width: 44,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$nivel/5',
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
        IconButton(
          onPressed: nivel < nivelMaximo ? () => onCambio(nivel + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
          color: Tema.tintaSuave,
        ),
      ],
    );
  }
}

class _AjusteMinutos extends StatelessWidget {
  const _AjusteMinutos({required this.nino});
  final Nino nino;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          flex: 3,
          child: Text('Minutos al día', style: TextStyle(fontSize: 15.5)),
        ),
        Expanded(
          flex: 5,
          child: Slider(
            value: nino.minutosDiarios.toDouble(),
            min: 5,
            max: 45,
            divisions: 8,
            activeColor: Tema.accion,
            label: '${nino.minutosDiarios} min',
            onChanged: (v) => context
                .read<AppEstado>()
                .actualizarNino(nino.id, minutosDiarios: v.round()),
          ),
        ),
        SizedBox(
          width: 56,
          child: Text('${nino.minutosDiarios} min',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ),
      ],
    );
  }
}

class _BarrasDeEstudio extends StatelessWidget {
  const _BarrasDeEstudio({required this.dias});
  final List<DiaDeEstudio> dias;

  static const _nombres = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final maximo = dias.map((d) => d.minutos).fold(1, (a, b) => a > b ? a : b);
    final hoy = DateTime.now();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var atras = 6; atras >= 0; atras--)
          Builder(builder: (context) {
            final dia = hoy.subtract(Duration(days: atras));
            final registro = dias
                .where((d) =>
                    d.dia.year == dia.year &&
                    d.dia.month == dia.month &&
                    d.dia.day == dia.day)
                .firstOrNull;
            final minutos = registro?.minutos ?? 0;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  minutos > 0 ? '$minutos' : '',
                  style: const TextStyle(fontSize: 11, color: Tema.tintaSuave),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 26,
                  height: 8 + (minutos / maximo) * 54,
                  decoration: BoxDecoration(
                    color: minutos > 0 ? Tema.accion : Tema.borde,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _nombres[dia.weekday - 1],
                  style: const TextStyle(fontSize: 12, color: Tema.tintaSuave),
                ),
              ],
            );
          }),
      ],
    );
  }
}

class _Subtitulo extends StatelessWidget {
  const _Subtitulo(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Text(
        texto.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Tema.tintaSuave,
        ),
      );
}


/// Elección de la voz de la app.
///
/// Existe porque no hay manera fiable de saber por código qué voz funciona en
/// un teléfono concreto: Android las anuncia todas como instaladas y de calidad
/// alta, incluidas las que no llegan a sonar. La única comprobación que vale es
/// que una persona la oiga, así que aquí se oye y se elige.
class _SelectorDeVoz extends StatefulWidget {
  const _SelectorDeVoz();

  @override
  State<_SelectorDeVoz> createState() => _SelectorDeVozState();
}

class _SelectorDeVozState extends State<_SelectorDeVoz> {
  String? _resultadoComprobacion;
  bool _comprobando = false;

  Future<void> _comprobar() async {
    setState(() {
      _comprobando = true;
      _resultadoComprobacion = null;
    });
    final suena = await context.read<AppEstado>().comprobarQueLaVozSuena();
    if (!mounted) return;
    setState(() {
      _comprobando = false;
      _resultadoComprobacion = suena
          ? 'La voz sí genera sonido. Si aun así no la oyes, el problema está '
              'en el volumen o en la salida de audio del teléfono.'
          : 'Esta voz no produce sonido en este teléfono. Elige otra de la lista.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<AppEstado>();
    final voces = estado.voz.vocesDisponibles;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: Tema.cajaTarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('La voz', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text(
            'Toca una para oírla. Elige la que mejor suene en este teléfono: la '
            'calidad cambia mucho de un móvil a otro, y alguna puede no sonar.',
            style: TextStyle(color: Tema.tintaSuave, fontSize: 14, height: 1.45),
          ),
          const SizedBox(height: 16),
          if (estado.voz.vozCastellanaAusente)
            const Text(
              'Este teléfono no tiene ninguna voz en español de España instalada. '
              'Instálala desde Ajustes → Idiomas → Texto a voz.',
              style: TextStyle(color: Tema.fallo, fontSize: 14, height: 1.45),
            )
          else if (voces.isEmpty)
            const Text('Abre una actividad primero para que se carguen las voces.',
                style: TextStyle(color: Tema.tintaSuave, fontSize: 14))
          else
            for (final v in voces)
              _FilaVoz(
                nombre: v['name'] ?? '',
                necesitaRed: v['network_required'] == '1',
                elegida: v['name'] == estado.voz.vozElegida,
                onTocar: () => estado.elegirVoz(v['name'] ?? ''),
              ),

          if (voces.isNotEmpty) ...[
            const Divider(height: 28),
            TextButton.icon(
              onPressed: _comprobando ? null : _comprobar,
              icon: _comprobando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.volume_off_outlined, size: 19),
              label: const Text('No oigo nada'),
              style: TextButton.styleFrom(
                foregroundColor: Tema.tintaSuave,
                minimumSize: const Size(0, 46),
              ),
            ),
            if (_resultadoComprobacion != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _resultadoComprobacion!,
                  style: const TextStyle(fontSize: 14, height: 1.45, color: Tema.tinta),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _FilaVoz extends StatelessWidget {
  const _FilaVoz({
    required this.nombre,
    required this.necesitaRed,
    required this.elegida,
    required this.onTocar,
  });

  final String nombre;
  final bool necesitaRed;
  final bool elegida;
  final VoidCallback onTocar;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTocar,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              elegida ? Icons.check_circle_rounded : Icons.play_circle_outline_rounded,
              color: elegida ? Tema.acierto : Tema.tintaSuave,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                nombre,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: elegida ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            if (necesitaRed)
              const Pastilla(
                'necesita wifi',
                icono: Icons.wifi,
                color: Tema.logro,
                fondo: Tema.logroSuave,
              ),
          ],
        ),
      ),
    );
  }
}
