import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../dominio/coleccion.dart';
import 'noun.dart';

/// El cromo.
///
/// Marco del color de su rareza, cartón claro dentro y la banda del título
/// teñida con el color que manda en el propio dibujo. Así no hay dos cromos
/// iguales aunque compartan rareza, que es lo que hace que apetezca tenerlos
/// todos.
///
/// Va en inglés, con los rasgos tal y como los nombra Nouns. Es a propósito:
/// un cromo con "square-black-eyes-red" impreso parece de una colección de
/// verdad, y "gafas negras de ojos rojos" parece la ficha de un catálogo.
class Cromo extends StatelessWidget {
  const Cromo({
    super.key,
    required this.noun,
    required this.catalogo,
    this.pie,
    this.pequeno = false,
  });

  final Noun noun;
  final CatalogoNouns catalogo;

  /// Lo que va abajo a la derecha: el código en grande, la fecha en el álbum.
  final String? pie;

  /// El cromo pequeño es el mismo cromo entero, no un recorte: en un álbum se
  /// leen las características sin tener que sacarlo de su hueco.
  final bool pequeno;

  static const _carton = Color(0xFFFBF4EA);
  static const _tinta = Color(0xFF2B2118);
  static const _tintaSuave = Color(0xFF7A6A5C);
  static const _tintaPie = Color(0xFFA2907F);

  @override
  Widget build(BuildContext context) {
    final rareza = noun.rareza;
    final color = colorDeRareza(rareza);
    final vivo = Color(0xFF000000 | catalogo.colorVivoDe(noun));
    final tintaCab = CatalogoNouns.esClaro(catalogo.colorVivoDe(noun))
        ? _tinta
        : Colors.white;

    final p = pequeno;

    return Container(
      padding: EdgeInsets.all(p ? 4 : 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(p ? 14 : 18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p ? 0.35 : 0.5),
            blurRadius: p ? 18 : 40,
            offset: Offset(0, p ? 6 : 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(p ? 10 : 13),
        child: ColoredBox(
          color: _carton,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _cabecera(rareza, color, vivo, tintaCab),
              _foto(),
              _caracteristicas(),
              if (pie != null) _pie(),
            ],
          ),
        ),
      ),
    );
  }

  /// El nombre y el sello. El nombre es una palabra, no un código, así que se
  /// escribe como una palabra: en la letra de la app y sin espaciar.
  Widget _cabecera(Rareza rareza, Color color, Color vivo, Color tintaCab) {
    final p = pequeno;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: p ? 7 : 10,
        vertical: p ? 5 : 7,
      ),
      color: vivo,
      child: Row(
        children: [
          // El nombre se lleva tres quintos y el sello dos, y el sello se
          // encoge antes que salirse: "EXTRA RARE" a 8 puntos no cabe en un
          // cromo pequeño de un móvil estrecho, y con el ancho a lo que pida
          // se comía la fila.
          Expanded(
            flex: 3,
            child: Text(
              catalogo.nombreDe(noun),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tintaCab,
                fontSize: p ? 13 : 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
          ),
          SizedBox(width: p ? 5 : 8),
          Flexible(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: p ? 6 : 8,
                  vertical: p ? 2 : 3,
                ),
                decoration: BoxDecoration(
                  color: _carton,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    FiguraRareza(rareza, lado: p ? 9 : 11, color: color),
                    SizedBox(width: p ? 3 : 4),
                    Text(
                      rareza.sello.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontSize: p ? 8 : 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// El dibujo, con el paspartú del color de su propio fondo.
  ///
  /// Nada pintado encima: se ve exactamente como lo dibuja Nouns. Lo que
  /// distingue a un cromo bueno es el marco, el sello y el pie.
  Widget _foto() {
    final p = pequeno;
    return Container(
      padding: EdgeInsets.all(p ? 5 : 8),
      color: Color(0xFF000000 | catalogo.colorDeFondo(noun)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(p ? 6 : 8),
          border: Border.all(
            color: _tinta.withValues(alpha: 0.18),
            width: p ? 1 : 2,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(p ? 1 : 2),
          child: VistaNoun(noun: noun, catalogo: catalogo, radio: p ? 5 : 6),
        ),
      ),
    );
  }

  /// Las cinco características, en tabla: es lo que se compara cromo contra
  /// cromo cuando dos niños los ponen uno al lado del otro.
  Widget _caracteristicas() {
    final p = pequeno;
    final filas = <(String, String, Rareza)>[
      for (final (capa, etiqueta) in CatalogoNouns.fichaCapas)
        (etiqueta, noun.rasgos[capa]!.clave, noun.rasgos[capa]!.rareza),
      ('Background', noun.fondoClave, Rareza.normal),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(p ? 5 : 8, p ? 5 : 7, p ? 5 : 8, p ? 2 : 4),
      child: Column(
        children: [
          for (final (i, (que, dato, rareza)) in filas.indexed)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: p ? 4 : 6,
                vertical: p ? 2 : 3,
              ),
              decoration: BoxDecoration(
                // Rayado de cebra: con cinco filas seguidas del mismo color no
                // se sigue la línea de un rasgo a su valor.
                color: i.isEven ? _tinta.withValues(alpha: 0.055) : null,
                borderRadius: BorderRadius.circular(p ? 4 : 6),
              ),
              child: Row(
                crossAxisAlignment: p
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: p ? 1 : 0),
                    child: Text(
                      que.toUpperCase(),
                      style: TextStyle(
                        color: _tintaSuave,
                        fontSize: p ? 8 : 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: p ? 0.4 : 0.7,
                      ),
                    ),
                  ),
                  SizedBox(width: p ? 6 : 8),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            dato,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              // El rasgo raro va de su color y con su figura:
                              // así se ve POR QUÉ el cromo es lo que es sin
                              // tener que explicarlo con una frase aparte.
                              color: rareza == Rareza.normal
                                  ? _tinta
                                  : colorDeRareza(rareza),
                              fontSize: p ? 10.5 : 12.5,
                              fontWeight: FontWeight.w700,
                              height: p ? 1.35 : 1.5,
                            ),
                          ),
                        ),
                        if (rareza != Rareza.normal) ...[
                          const SizedBox(width: 4),
                          FiguraRareza(rareza, lado: p ? 9 : 11),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _pie() {
    final p = pequeno;
    return Padding(
      padding: EdgeInsets.fromLTRB(p ? 8 : 12, 0, p ? 8 : 12, p ? 5 : 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Flexible con elipsis: el código de un cromo son cinco números y
          // cuatro guiones, y en un móvil estrecho se queda sin holgura.
          Flexible(
            child: Text(
              pie!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _tintaPie,
                fontSize: p ? 8.5 : 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// La figura de cada rareza: círculo, rombo, estrella, estrella con destello.
///
/// Va con la etiqueta y también junto al rasgo culpable. Es lo que permite
/// leer la rareza de lejos, o sin distinguir bien los colores.
class FiguraRareza extends StatelessWidget {
  const FiguraRareza(this.rareza, {super.key, this.lado = 11, this.color});

  final Rareza rareza;
  final double lado;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: lado,
    height: lado,
    child: CustomPaint(
      painter: _PintorFigura(rareza, color ?? colorDeRareza(rareza)),
    ),
  );
}

class _PintorFigura extends CustomPainter {
  const _PintorFigura(this.rareza, this.color);

  final Rareza rareza;
  final Color color;

  @override
  void paint(Canvas lienzo, Size tamano) {
    final pincel = Paint()..color = color;
    final u = tamano.width / 14;
    Offset p(double x, double y) => Offset(x * u, y * u);

    void poligono(List<Offset> puntos) {
      final camino = Path()..addPolygon(puntos, true);
      lienzo.drawPath(camino, pincel);
    }

    switch (rareza) {
      case Rareza.normal:
        lienzo.drawCircle(p(7, 7), 4.2 * u, pincel);
      case Rareza.raro:
        poligono([p(7, 1.6), p(12.4, 7), p(7, 12.4), p(1.6, 7)]);
      case Rareza.extraRaro:
        poligono(_estrella(p, 7, 6.9, 6.2, 2.6));
      case Rareza.especial:
        poligono(_estrella(p, 8.4, 6.8, 5.8, 2.4));
        // El destello de al lado. Es lo único que separa al especial del extra
        // raro de un vistazo, y tiene que notarse a 9 píxeles de ancho.
        poligono([
          p(2.6, 9.4),
          p(3.4, 11.2),
          p(5.2, 12),
          p(3.4, 12.8),
          p(2.6, 14.6),
          p(1.8, 12.8),
          p(0, 12),
          p(1.8, 11.2),
        ]);
    }
  }

  /// Los diez vértices de una estrella de cinco puntas.
  static List<Offset> _estrella(
    Offset Function(double, double) p,
    double cx,
    double cy,
    double fuera,
    double dentro,
  ) => [
    for (var i = 0; i < 10; i++)
      if ((i.isEven ? fuera : dentro) case final radio)
        if (-math.pi / 2 + i * math.pi / 5 case final angulo)
          p(cx + radio * math.cos(angulo), cy + radio * math.sin(angulo)),
  ];

  @override
  bool shouldRepaint(_PintorFigura anterior) =>
      anterior.rareza != rareza || anterior.color != color;
}
