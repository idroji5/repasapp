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
    required this.noun,
    required this.rareza,
    required this.catalogo,
    required this.lado,
    this.onAbierta,
  });

  final Noun noun;
  final Rareza rareza;
  final CatalogoNouns catalogo;
  final double lado;

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
      child: SizedBox(
        width: widget.lado,
        height: widget.lado,
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
            final flotar = _abierta
                ? 0.0
                : sin(_respiracion.value * pi) * 4 - 2;

            return Stack(
              alignment: Alignment.center,
              children: [
                if (estallido > 0 && estallido < 1)
                  _Estallido(
                    avance: estallido,
                    color: color,
                    lado: widget.lado,
                  ),

                if (sale > 0)
                  Transform.scale(
                    scale: sale,
                    child: Opacity(
                      opacity: _tramo(0.26, 0.42).clamp(0.0, 1.0),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: color, width: 4),
                        ),
                        child: VistaNoun(
                          noun: widget.noun,
                          catalogo: widget.catalogo,
                          lado: widget.lado - 18,
                          radio: 22,
                        ),
                      ),
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
      ),
    );
  }
}

/// La caja, dibujada a cuadros gordos para que pegue con los Nouns.
///
/// Se pinta en dos pasadas —tapa y cuerpo por separado— porque la tapa tiene
/// que poder salir volando sin llevarse la caja con ella.
class _PintorCaja extends CustomPainter {
  const _PintorCaja({required this.tapa});

  final bool tapa;

  static const _tinta = Color(0xFF1A1420);
  static const _lazo = Color(0xFFC33246);
  static const _lazoOscuro = Color(0xFF7A1E2B);
  static const _papel = Color(0xFFF2E9DC);
  static const _papelOscuro = Color(0xFFD9CBB6);

  @override
  void paint(Canvas lienzo, Size tamano) {
    // Todo se mide en una rejilla de 16, así que los bordes caen siempre en
    // el mismo sitio y no salen píxeles a medias.
    final u = tamano.width / 16;
    final borde = u * 0.5;

    void bloque(double x, double y, double ancho, double alto, Color color) {
      final caja = Rect.fromLTWH(x * u, y * u, ancho * u, alto * u);
      lienzo.drawRect(caja.inflate(borde), Paint()..color = _tinta);
      lienzo.drawRect(caja, Paint()..color = color);
    }

    if (tapa) {
      // El lazo: dos bucles y el nudo en medio. Sin el nudo se quedaba en dos
      // cuadrados rojos flotando encima de una caja.
      bloque(2.5, 0.5, 4, 3.5, _lazo);
      bloque(9.5, 0.5, 4, 3.5, _lazo);
      bloque(6.5, 2, 3, 2.5, _lazoOscuro);
      bloque(0.5, 4.5, 15, 3.5, _papel);
      bloque(6.5, 4.5, 3, 3.5, _lazo); // la cinta cruzando la tapa
      return;
    }

    bloque(1.5, 8, 13, 7.5, _papel);
    bloque(1.5, 13.5, 13, 2, _papelOscuro); // el canto de abajo, en sombra
    bloque(6.5, 8, 3, 7.5, _lazo); // la cinta bajando por delante
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
