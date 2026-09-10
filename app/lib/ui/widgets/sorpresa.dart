import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../dominio/coleccion.dart';
import 'noun.dart';

/// El regalo que hay que abrir.
///
/// El dibujo no se enseña de entrada. Se enseña una caja cerrada, y el niño la
/// toca. Es la diferencia entre recibir algo y abrirlo: medio segundo de "qué
/// habrá" vale más que el dibujo, y además hace que el premio dependa de un
/// gesto suyo y no de que la pantalla se lo suelte.
///
/// El color de la rareza no aparece hasta que se abre. Si la caja ya fuera
/// dorada no habría sorpresa que dar.
class Sorpresa extends StatefulWidget {
  const Sorpresa({
    super.key,
    required this.rareza,
    required this.lado,
    required this.dentro,
    this.onAbierta,
  });

  final Rareza rareza;

  /// El lado de la caja. Lo que sale de dentro puede ser más alto: un cromo
  /// con sus cinco características lo es.
  final double lado;

  /// Lo que hay dentro. La caja no sabe qué es: le da igual que sea un cromo,
  /// y así se puede abrir con cualquier cosa dentro.
  final Widget dentro;

  /// Se llama al empezar a abrirse, para que la pantalla saque el nombre y los
  /// botones cuando toca y no antes.
  final VoidCallback? onAbierta;

  @override
  State<Sorpresa> createState() => _SorpresaState();
}

class _SorpresaState extends State<Sorpresa> with TickerProviderStateMixin {
  /// La caja quieta respira, para que se vea que hay que tocarla.
  late final AnimationController _respiracion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  late final AnimationController _apertura = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  );

  bool _abierta = false;

  @override
  void dispose() {
    _respiracion.dispose();
    _apertura.dispose();
    super.dispose();
  }

  void _abrir() {
    if (_abierta) return;
    setState(() => _abierta = true);
    _respiracion.stop();
    HapticFeedback.mediumImpact();
    _apertura.forward();
    widget.onAbierta?.call();
  }

  /// Tramos de la apertura. Van solapados a propósito: el Noun ya está
  /// creciendo mientras la tapa sale volando, y así parece que sale de dentro
  /// en lugar de aparecer después.
  double _tramo(double desde, double hasta, [Curve curva = Curves.linear]) =>
      curva.transform(
        ((_apertura.value - desde) / (hasta - desde)).clamp(0.0, 1.0),
      );

  @override
  Widget build(BuildContext context) {
    final color = colorDeRareza(widget.rareza);

    return GestureDetector(
      onTap: _abrir,
      child: AnimatedBuilder(
        animation: Listenable.merge([_apertura, _respiracion]),
        builder: (contexto, _) {
          final sacude = _tramo(0, 0.16);
          final tapa = _tramo(0.14, 0.40, Curves.easeOutCubic);
          final caja = _tramo(0.14, 0.34);
          final estallido = _tramo(0.18, 0.62, Curves.easeOutCubic);
          final sale = _tramo(0.26, 0.72, Curves.easeOutBack);

          // Tres bandazos y para. Es el "un momento, que va a pasar algo".
          final vaiven = sacude > 0 && sacude < 1
              ? sin(sacude * pi * 6) * 0.07 * (1 - sacude)
              : 0.0;
          final flotar = _abierta ? 0.0 : sin(_respiracion.value * pi) * 4 - 2;

          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // La sombra del suelo: es lo que hace que la caja esté posada
              // en algún sitio en vez de flotando sobre un fondo plano.
              if (caja < 1)
                Positioned(
                  bottom: 0,
                  child: Opacity(
                    opacity: (1 - caja) * (0.85 + 0.15 * _respiracion.value),
                    child: Transform.scale(
                      scaleX: 0.97 + 0.06 * _respiracion.value,
                      child: _Sombra(ancho: widget.lado * 1.15),
                    ),
                  ),
                ),

              if (estallido > 0 && estallido < 1)
                _Estallido(avance: estallido, color: color, lado: widget.lado),

              if (sale > 0)
                Transform.scale(
                  scale: sale,
                  child: Opacity(
                    opacity: _tramo(0.26, 0.42).clamp(0.0, 1.0),
                    child: widget.dentro,
                  ),
                ),

              if (caja < 1)
                Transform.translate(
                  offset: Offset(0, flotar),
                  child: Transform.rotate(
                    angle: vaiven,
                    child: Opacity(
                      opacity: 1 - caja,
                      child: CustomPaint(
                        size: Size.square(widget.lado),
                        painter: const _PintorCaja(tapa: false),
                      ),
                    ),
                  ),
                ),

              // La tapa sale disparada hacia arriba girando.
              if (tapa < 1)
                Transform.translate(
                  offset: Offset(0, flotar - tapa * widget.lado * 0.9),
                  child: Transform.rotate(
                    angle: vaiven + tapa * 0.7,
                    child: Opacity(
                      opacity: 1 - tapa * tapa,
                      child: CustomPaint(
                        size: Size.square(widget.lado),
                        painter: const _PintorCaja(tapa: true),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// La sombra del suelo, difuminada a mano.
///
/// Un `BoxShadow` no vale: pinta la sombra de una caja, y aquí hace falta la
/// mancha sola, sin caja encima.
class _Sombra extends StatelessWidget {
  const _Sombra({required this.ancho});

  final double ancho;

  @override
  Widget build(BuildContext context) => Container(
    width: ancho,
    height: ancho * 0.13,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.all(Radius.elliptical(ancho, ancho * 0.13)),
      gradient: RadialGradient(
        colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
        stops: const [0.35, 1],
      ),
    ),
  );
}

/// La caja, rectángulo a rectángulo sobre una rejilla de 16.
///
/// Son los mismos rectángulos del diseño, con las mismas coordenadas: el lazo
/// es una cinta de verdad, con sus dos bucles y su nudo, y eso no sale de
/// cuatro cuadrados grandes. Se pinta en dos pasadas —tapa y cuerpo por
/// separado— porque la tapa tiene que poder salir volando sin llevarse la caja
/// con ella.
class _PintorCaja extends CustomPainter {
  const _PintorCaja({required this.tapa});

  final bool tapa;

  /// (x, y, ancho, alto, color) en la rejilla de 16.
  static const List<(double, double, double, double, Color)> _cuerpo = [
    (1.2, 6.9, 13.6, 8.9, Color(0xFF1A1420)),
    (1.6, 7.3, 12.8, 8.1, Color(0xFFF2E9DC)),
    (1.6, 13.6, 12.8, 1.8, Color(0xFFD9CBB6)),
    (6.6, 6.9, 2.8, 8.9, Color(0xFF1A1420)),
    (7.0, 7.3, 2.0, 8.1, Color(0xFFC33246)),
  ];

  static const List<(double, double, double, double, Color)> _tapa = [
    (0.2, 3.6, 15.6, 3.8, Color(0xFF1A1420)),
    (0.6, 4.0, 14.8, 3.0, Color(0xFFF2E9DC)),
    (0.6, 6.2, 14.8, 0.8, Color(0xFFD9CBB6)),
    (6.6, 3.6, 2.8, 3.8, Color(0xFF1A1420)),
    (7.0, 4.0, 2.0, 3.0, Color(0xFFC33246)),
    (2.6, -0.1, 2.7, 1.35, Color(0xFF1A1420)),
    (2.6, 0.45, 3.5, 1.35, Color(0xFF1A1420)),
    (2.9, 1.0, 3.9, 1.35, Color(0xFF1A1420)),
    (3.6, 1.55, 4.0, 1.35, Color(0xFF1A1420)),
    (4.8, 2.1, 2.8, 1.35, Color(0xFF1A1420)),
    (10.7, -0.1, 2.7, 1.35, Color(0xFF1A1420)),
    (9.9, 0.45, 3.5, 1.35, Color(0xFF1A1420)),
    (9.2, 1.0, 3.9, 1.35, Color(0xFF1A1420)),
    (8.4, 1.55, 4.0, 1.35, Color(0xFF1A1420)),
    (8.4, 2.1, 2.8, 1.35, Color(0xFF1A1420)),
    (3.0, 0.3, 1.9, 0.55, Color(0xFFC33246)),
    (3.0, 0.85, 2.7, 0.55, Color(0xFFC33246)),
    (3.3, 1.4, 3.1, 0.55, Color(0xFFC33246)),
    (4.0, 1.95, 3.2, 0.55, Color(0xFFC33246)),
    (5.2, 2.5, 2.0, 0.55, Color(0xFFC33246)),
    (11.1, 0.3, 1.9, 0.55, Color(0xFFC33246)),
    (10.3, 0.85, 2.7, 0.55, Color(0xFFC33246)),
    (9.6, 1.4, 3.1, 0.55, Color(0xFFC33246)),
    (8.8, 1.95, 3.2, 0.55, Color(0xFFC33246)),
    (8.8, 2.5, 2.0, 0.55, Color(0xFFC33246)),
    (3.9, 0.95, 1.3, 0.85, Color(0xFF1A1420)),
    (10.8, 0.95, 1.3, 0.85, Color(0xFF1A1420)),
    (6.5, 1.5, 3.0, 2.3, Color(0xFF1A1420)),
    (6.9, 1.9, 2.2, 1.5, Color(0xFF9E2537)),
    (5.8, 2.9, 2.0, 1.3, Color(0xFF1A1420)),
    (5.1, 3.3, 1.9, 1.3, Color(0xFF1A1420)),
    (8.2, 2.9, 2.0, 1.3, Color(0xFF1A1420)),
    (9.0, 3.3, 1.9, 1.3, Color(0xFF1A1420)),
    (6.2, 3.3, 1.2, 0.5, Color(0xFFC33246)),
    (5.5, 3.7, 1.1, 0.5, Color(0xFFC33246)),
    (8.6, 3.3, 1.2, 0.5, Color(0xFFC33246)),
    (9.4, 3.7, 1.1, 0.5, Color(0xFFC33246)),
  ];

  @override
  void paint(Canvas lienzo, Size tamano) {
    final u = tamano.width / 16;
    for (final (x, y, ancho, alto, color) in tapa ? _tapa : _cuerpo) {
      lienzo.drawRect(
        Rect.fromLTWH(x * u, y * u, ancho * u, alto * u),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_PintorCaja anterior) => anterior.tapa != tapa;
}

/// El fogonazo del momento de abrirla: un anillo que se abre y doce chispas.
class _Estallido extends StatelessWidget {
  const _Estallido({
    required this.avance,
    required this.color,
    required this.lado,
  });

  final double avance;
  final Color color;
  final double lado;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(lado),
    painter: _PintorEstallido(avance: avance, color: color),
  );
}

class _PintorEstallido extends CustomPainter {
  const _PintorEstallido({required this.avance, required this.color});

  final double avance;
  final Color color;

  static const _chispas = 12;

  @override
  void paint(Canvas lienzo, Size tamano) {
    final centro = tamano.center(Offset.zero);
    final desvanece = (1 - avance).clamp(0.0, 1.0);
    final u = tamano.width / 16;

    lienzo.drawCircle(
      centro,
      tamano.width * (0.18 + avance * 0.62),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * (1.4 * desvanece)
        ..color = color.withValues(alpha: desvanece * 0.9),
    );

    // Cuadrados, no puntos: es lo que las hace parecer píxeles y no confeti.
    final pincel = Paint()..color = color.withValues(alpha: desvanece);
    for (var i = 0; i < _chispas; i++) {
      final angulo = i * 2 * pi / _chispas;
      final radio = tamano.width * (0.22 + avance * 0.55);
      final lado = u * (1.1 * desvanece);
      lienzo.drawRect(
        Rect.fromCenter(
          center: centro + Offset(cos(angulo), sin(angulo)) * radio,
          width: lado,
          height: lado,
        ),
        pincel,
      );
    }
  }

  @override
  bool shouldRepaint(_PintorEstallido anterior) =>
      anterior.avance != avance || anterior.color != color;
}
