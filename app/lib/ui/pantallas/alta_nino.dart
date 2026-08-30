import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../dominio/asignaturas.dart';
import '../../estado.dart';
import '../tema.dart';
import '../widgets/botones.dart';

/// Alta de un perfil. La pantalla más "de padre" de toda la app.
///
/// El nivel se pide por asignatura, no uno solo para todo el niño: es lo que
/// permite que vaya avanzado en Matemáticas y de refuerzo en Dictado. Si se
/// deja como está, todas empiezan en 3 y la app lo va ajustando sola.
class PantallaAltaNino extends StatefulWidget {
  const PantallaAltaNino({super.key});

  @override
  State<PantallaAltaNino> createState() => _PantallaAltaNinoState();
}

class _PantallaAltaNinoState extends State<PantallaAltaNino> {
  final _nombre = TextEditingController();
  int _curso = 4;
  int _minutos = 15;
  final Map<Asignatura, int> _niveles = {
    for (final a in Asignatura.values) a: 3,
  };

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) return;

    await context.read<AppEstado>().crearNino(
          nombre: nombre,
          curso: _curso,
          minutosDiarios: _minutos,
          niveles: _niveles,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo perfil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            const _Etiqueta('Nombre'),
            TextField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 19),
              decoration: InputDecoration(
                hintText: 'Pedro',
                filled: true,
                fillColor: Tema.tarjeta,
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Tema.borde),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Tema.borde),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),

            const _Etiqueta('Curso'),
            const _Ayuda('Marca qué contenidos ya ha dado en clase.'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var curso = 1; curso <= 6; curso++)
                  ChoiceChip(
                    label: Text('$curso.º'),
                    selected: _curso == curso,
                    onSelected: (_) => setState(() => _curso = curso),
                    labelStyle: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _curso == curso ? Colors.white : Tema.tinta,
                    ),
                    selectedColor: Tema.accion,
                    backgroundColor: Tema.tarjeta,
                    side: const BorderSide(color: Tema.borde),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
              ],
            ),

            const _Etiqueta('Minutos al día'),
            const _Ayuda('Con esto preparo la sesión diaria automáticamente.'),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _minutos.toDouble(),
                    min: 5,
                    max: 45,
                    divisions: 8,
                    activeColor: Tema.accion,
                    label: '$_minutos min',
                    onChanged: (v) => setState(() => _minutos = v.round()),
                  ),
                ),
                SizedBox(
                  width: 68,
                  child: Text(
                    '$_minutos min',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ],
            ),

            const _Etiqueta('Nivel en cada asignatura'),
            const _Ayuda(
              'La edad no es la dificultad. Puede ir avanzado en unas cosas y '
              'necesitar refuerzo en otras. Si no lo tienes claro, déjalo en 3: '
              'la app lo ajusta sola según los resultados.',
            ),
            const SizedBox(height: 14),
            for (final asignatura in Asignatura.values) ...[
              _SelectorNivel(
                asignatura: asignatura,
                nivel: _niveles[asignatura]!,
                onCambio: (n) => setState(() => _niveles[asignatura] = n),
              ),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 20),
            BotonGrande(
              texto: 'Crear perfil',
              onPressed: _nombre.text.trim().isEmpty ? null : _guardar,
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectorNivel extends StatelessWidget {
  const _SelectorNivel({
    required this.asignatura,
    required this.nivel,
    required this.onCambio,
  });

  final Asignatura asignatura;
  final int nivel;
  final ValueChanged<int> onCambio;

  static const List<String> _nombres = [
    'Refuerzo', 'Va justo', 'Normal', 'Va bien', 'Avanzado',
  ];

  @override
  Widget build(BuildContext context) {
    final color = Tema.colorDe(asignatura.name);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: Tema.cajaTarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(asignatura.nombre, style: Theme.of(context).textTheme.titleMedium),
              Text(
                _nombres[nivel - 1],
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14.5),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var n = nivelMinimo; n <= nivelMaximo; n++)
                Expanded(
                  child: GestureDetector(
                    onTap: () => onCambio(n),
                    child: Container(
                      height: 46,
                      margin: EdgeInsets.only(right: n == nivelMaximo ? 0 : 6),
                      decoration: BoxDecoration(
                        color: n <= nivel ? color : Tema.fondo,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: n <= nivel ? color : Tema.borde),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$n',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: n <= nivel ? Colors.white : Tema.tintaSuave,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 26, bottom: 8),
        child: Text(texto, style: Theme.of(context).textTheme.titleMedium),
      );
}

class _Ayuda extends StatelessWidget {
  const _Ayuda(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Text(
        texto,
        style: const TextStyle(color: Tema.tintaSuave, fontSize: 14.5, height: 1.45),
      );
}
