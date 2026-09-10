import 'package:flutter/material.dart';

/// El cuarto oscuro donde viven los cromos.
///
/// Es lo único de la app que no es papel y tinta, y lo es a propósito: el
/// premio consiste precisamente en salir de la calma del cuaderno. Al trabajo
/// no le sobra ni un color; aquí sí.
///
/// Dos capas debajo de todo: una rejilla del mismo paso con el que están
/// dibujados los Nouns, y un foco que se enciende del color de la rareza
/// cuando se abre la caja. El aura es lo que hace que el color salga del marco
/// del cromo y llegue a la pantalla entera.
class Sala extends StatelessWidget {
  const Sala({super.key, this.color, this.altoDelFoco});

  static const Color fondo = Color(0xFF1A1420);
  static const Color panel = Color(0xFF2A2334);

  /// El verde de siempre de la app, para los botones que no llevan el color de
  /// una rareza.
  static const Color accion = Color(0xFF0F766E);

  /// Con qué color está encendido el foco. Null es la luz de antes de abrir:
  /// fría y casi nada.
  final Color? color;

  /// Dónde se centra el foco, en la escala de `Alignment`: -1 arriba, 0 en
  /// medio. Null deja solo la rejilla, que es lo que necesita el álbum: allí
  /// la luz la ponen los cromos.
  final double? altoDelFoco;

  /// El paso de la rejilla. El mismo con el que están dibujados los Nouns y la
  /// caja: apenas se ve, se nota.
  static const double _paso = 16;

  @override
  Widget build(BuildContext context) {
    final foco = altoDelFoco;
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned.fill(
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (caja) => RadialGradient(
                  center: Alignment(0, foco ?? -1),
                  radius: foco == null ? 0.62 : 0.7,
                  colors: const [Colors.black, Colors.transparent],
                ).createShader(caja),
                child: const CustomPaint(painter: _Rejilla()),
              ),
            ),
            if (foco != null)
              // A pantalla completa y con el radio en fracción, no un círculo
              // de 620 puntos: metido en un hueco de 390 de ancho se recorta,
              // el resplandor se queda del tamaño del cromo y no se ve, porque
              // lo tapa el propio cromo.
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, foco),
                      radius: color == null ? 0.85 : 1.05,
                      colors: [
                        (color ?? const Color(0xFF9A90A8)).withValues(
                          alpha: color == null ? 0.14 : 0.42,
                        ),
                        const Color(0x00000000),
                      ],
                      stops: const [0, 0.72],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Rejilla extends CustomPainter {
  const _Rejilla();

  @override
  void paint(Canvas lienzo, Size tamano) {
    final pincel = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (var x = 0.0; x <= tamano.width; x += Sala._paso) {
      lienzo.drawLine(Offset(x, 0), Offset(x, tamano.height), pincel);
    }
    for (var y = 0.0; y <= tamano.height; y += Sala._paso) {
      lienzo.drawLine(Offset(0, y), Offset(tamano.width, y), pincel);
    }
  }

  @override
  bool shouldRepaint(_Rejilla anterior) => false;
}
