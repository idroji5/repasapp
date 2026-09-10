import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../datos/modelos.dart';
import '../../dominio/coleccion.dart';
import '../../estado.dart';
import '../tema.dart';
import '../widgets/cromo.dart';
import '../widgets/noun.dart';
import '../widgets/sala.dart';

/// El álbum de cromos del niño.
///
/// Cuatro páginas, de la más rara a la más común, y en cada hueco el cromo
/// entero: sus cinco características se leen sin sacarlo del álbum, que es lo
/// que se compara cuando dos niños los ponen uno al lado del otro.
class PantallaColeccion extends StatefulWidget {
  const PantallaColeccion({super.key, required this.nino});

  final Nino nino;

  @override
  State<PantallaColeccion> createState() => _PantallaColeccionState();
}

/// Cómo se ordena el álbum.
enum _Orden { rareza, fecha }

class _PantallaColeccionState extends State<PantallaColeccion> {
  List<NounGuardado>? _nouns;

  /// Por rareza de entrada: es el orden que hace que esto sea un álbum y no un
  /// historial. La fecha sigue a un toque, para el niño que quiere ver por
  /// dónde iba en abril.
  _Orden _orden = _Orden.rareza;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final nouns = await context.read<AppEstado>().repo.coleccion(
      widget.nino.id,
    );
    if (mounted) setState(() => _nouns = nouns);
  }

  @override
  Widget build(BuildContext context) {
    final catalogo = context.read<AppEstado>().catalogo;
    final nouns = _nouns;

    return Scaffold(
      backgroundColor: Sala.fondo,
      body: Stack(
        children: [
          // Sin aura: en el álbum la luz la ponen los cromos.
          const Sala(),
          SafeArea(
            child: Column(
              children: [
                const _Barra(),
                Expanded(
                  child: switch ((nouns, catalogo)) {
                    (null, _) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    (_, null) => const _Aviso(
                      'No he podido cargar los cromos.',
                    ),
                    (final lista?, final cat?) => _Album(
                      nouns: lista,
                      catalogo: cat,
                      orden: _orden,
                      onOrden: (orden) => setState(() => _orden = orden),
                      onTocar: (guardado, noun) =>
                          _abrirFicha(cat, guardado, noun),
                    ),
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _abrirFicha(CatalogoNouns catalogo, NounGuardado guardado, Noun noun) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Sala.panel,
      showDragHandle: true,
      builder: (_) =>
          _Ficha(guardado: guardado, noun: noun, catalogo: catalogo),
    );
  }
}

class _Barra extends StatelessWidget {
  const _Barra();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
    child: Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left_rounded, size: 30),
          color: Colors.white,
          tooltip: 'Volver',
        ),
        const Text(
          'Mi álbum',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ],
    ),
  );
}

class _Album extends StatelessWidget {
  const _Album({
    required this.nouns,
    required this.catalogo,
    required this.orden,
    required this.onOrden,
    required this.onTocar,
  });

  final List<NounGuardado> nouns;
  final CatalogoNouns catalogo;
  final _Orden orden;
  final ValueChanged<_Orden> onOrden;
  final void Function(NounGuardado, Noun) onTocar;

  @override
  Widget build(BuildContext context) {
    final porRareza = <Rareza, List<NounGuardado>>{
      for (final rareza in Rareza.values) rareza: <NounGuardado>[],
    };
    for (final n in nouns) {
      porRareza[n.rareza]!.add(n);
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _Resumen(total: nouns.length, porRareza: porRareza),
        ),
        SliverToBoxAdapter(
          child: _Segmentado(orden: orden, onOrden: onOrden),
        ),

        if (nouns.isEmpty)
          const SliverToBoxAdapter(
            child: _Aviso(
              'Termina las tres actividades de un día\ny te llevas el primero.',
            ),
          ),

        if (orden == _Orden.fecha)
          ..._paginaSuelta(nouns)
        else
          // De la más rara a la más común. Un álbum se abre por la página que
          // uno quiere enseñar, no por la que tiene repetida.
          for (final rareza in Rareza.values.reversed) ...[
            SliverToBoxAdapter(
              child: _CabeceraPagina(
                rareza: rareza,
                cuantos: porRareza[rareza]!.length,
              ),
            ),
            if (porRareza[rareza]!.isEmpty)
              SliverToBoxAdapter(child: _Huecos(rareza))
            else
              ..._paginaSuelta(porRareza[rareza]!),
          ],

        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );
  }

  /// Los cromos de a dos.
  ///
  /// En filas y no en rejilla: un cromo mide lo que miden sus cinco
  /// características, y una rejilla con proporción fija o los recorta o deja
  /// un hueco debajo de cada uno.
  List<Widget> _paginaSuelta(List<NounGuardado> lista) {
    final filas = <Widget>[];
    for (var i = 0; i < lista.length; i += 2) {
      final pareja = lista.skip(i).take(2).toList();
      filas.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (j, guardado) in pareja.indexed) ...[
                  if (j > 0) const SizedBox(width: 12),
                  Expanded(
                    child: _Casilla(
                      guardado: guardado,
                      catalogo: catalogo,
                      onTocar: onTocar,
                    ),
                  ),
                ],
                // Un cromo impar no se estira a lo ancho de la página: se
                // queda del tamaño de los demás, con su hueco al lado.
                if (pareja.length == 1) ...[
                  const SizedBox(width: 12),
                  const Spacer(),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return filas;
  }
}

/// Cuántos llevas y cuántos de los buenos: es lo primero que se mira.
class _Resumen extends StatelessWidget {
  const _Resumen({required this.total, required this.porRareza});

  final int total;
  final Map<Rareza, List<NounGuardado>> porRareza;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$total',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(width: 5),
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text(
            total == 1 ? 'cromo' : 'cromos',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // En Wrap y no en Row: con las cuatro rarezas y un número de tres
        // cifras, una fila se sale de un móvil estrecho.
        Expanded(
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final rareza in Rareza.values.reversed)
                if (porRareza[rareza]!.isNotEmpty)
                  _Cuenta(rareza, porRareza[rareza]!.length),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Cuenta extends StatelessWidget {
  const _Cuenta(this.rareza, this.cuantos);

  final Rareza rareza;
  final int cuantos;

  @override
  Widget build(BuildContext context) {
    final color = colorDeRareza(rareza);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FiguraRareza(rareza, lado: 11),
          const SizedBox(width: 5),
          Text(
            '$cuantos',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Los dos órdenes del álbum, con la pastilla que se desliza.
class _Segmentado extends StatelessWidget {
  const _Segmentado({required this.orden, required this.onOrden});

  final _Orden orden;
  final ValueChanged<_Orden> onOrden;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: orden == _Orden.rareza
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final (o, texto) in const [
                (_Orden.rareza, 'Por rareza'),
                (_Orden.fecha, 'Por fecha'),
              ])
                Expanded(
                  child: GestureDetector(
                    onTap: () => onOrden(o),
                    // La zona de toque llega a los 44 puntos de alto: un dedo
                    // de siete años no apunta tan fino.
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      height: 44,
                      child: Center(
                        child: Text(
                          texto,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: orden == o
                                ? Sala.fondo
                                : Colors.white.withValues(alpha: 0.65),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// La cabecera de una página del álbum.
class _CabeceraPagina extends StatelessWidget {
  const _CabeceraPagina({required this.rareza, required this.cuantos});

  final Rareza rareza;
  final int cuantos;

  @override
  Widget build(BuildContext context) {
    final color = colorDeRareza(rareza);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FiguraRareza(rareza, lado: 12),
                const SizedBox(width: 5),
                Text(
                  rareza.etiqueta,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$cuantos',
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          // La costura de la página: cierra la cabecera sin meter una línea a
          // todo lo ancho, que partiría el álbum en trozos.
          Expanded(
            child: Container(height: 1, color: color.withValues(alpha: 0.28)),
          ),
        ],
      ),
    );
  }
}

/// Los huecos de una página sin estrenar.
///
/// Se enseñan a propósito, en lugar de esconder la página: un álbum donde solo
/// salen las páginas llenas es un resumen, y lo que da ganas de seguir es ver
/// lo que falta.
class _Huecos extends StatelessWidget {
  const _Huecos(this.rareza);

  final Rareza rareza;

  @override
  Widget build(BuildContext context) {
    final color = colorDeRareza(rareza);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          for (var i = 0; i < 2; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(
              child: CustomPaint(
                painter: _BordeDePuntos(color.withValues(alpha: 0.4)),
                child: SizedBox(
                  height: 112,
                  child: Center(
                    child: Text(
                      '?',
                      style: TextStyle(
                        color: color.withValues(alpha: 0.7),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Un borde de puntos. Flutter no trae discontinuos, y un borde entero
/// convierte el hueco en una tarjeta vacía en lugar de en un sitio por llenar.
class _BordeDePuntos extends CustomPainter {
  const _BordeDePuntos(this.color);

  final Color color;

  @override
  void paint(Canvas lienzo, Size tamano) {
    final pincel = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final contorno = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(1, 1, tamano.width - 2, tamano.height - 2),
          const Radius.circular(14),
        ),
      );

    for (final tramo in contorno.computeMetrics()) {
      var d = 0.0;
      while (d < tramo.length) {
        final hasta = (d + 7).clamp(0.0, tramo.length);
        lienzo.drawPath(tramo.extractPath(d, hasta), pincel);
        d += 13;
      }
    }
  }

  @override
  bool shouldRepaint(_BordeDePuntos anterior) => anterior.color != color;
}

class _Casilla extends StatelessWidget {
  const _Casilla({
    required this.guardado,
    required this.catalogo,
    required this.onTocar,
  });

  final NounGuardado guardado;
  final CatalogoNouns catalogo;
  final void Function(NounGuardado, Noun) onTocar;

  @override
  Widget build(BuildContext context) {
    final noun = catalogo.desdeCodigo(guardado.codigo);
    if (noun == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => onTocar(guardado, noun),
      child: Cromo(
        noun: noun,
        catalogo: catalogo,
        pie: _fechaCorta(guardado.dia),
        pequeno: true,
      ),
    );
  }
}

/// El cromo en grande, al tocarlo en el álbum.
class _Ficha extends StatelessWidget {
  const _Ficha({
    required this.guardado,
    required this.noun,
    required this.catalogo,
  });

  final NounGuardado guardado;
  final Noun noun;
  final CatalogoNouns catalogo;

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: (ancho * 0.62).clamp(200.0, 264.0),
            child: Cromo(noun: noun, catalogo: catalogo, pie: noun.codigo),
          ),
          const SizedBox(height: 18),
          Text(
            'Lo ganaste el ${_fecha(guardado.dia)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

const _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

String _fecha(DateTime d) => '${d.day} de ${_meses[d.month - 1]}';

/// La fecha que cabe en el pie de un cromo pequeño.
String _fechaCorta(DateTime d) =>
    '${d.day} ${_meses[d.month - 1].substring(0, 3)}';

class _Aviso extends StatelessWidget {
  const _Aviso(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
    child: Text(
      texto,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.7),
        fontSize: 17,
        height: 1.5,
      ),
    ),
  );
}

/// La tarjeta del pie del plan de hoy: el último que ganó y cuántos lleva.
///
/// Es deliberadamente pequeña y va abajo del todo. La pantalla que el niño abre
/// para ponerse a trabajar no puede empezar con un premio: eso convierte los
/// deberes en el peaje del juego, que es justo al revés de lo que interesa.
class TarjetaColeccion extends StatelessWidget {
  const TarjetaColeccion({
    super.key,
    required this.nino,
    required this.nouns,
    required this.catalogo,
  });

  final Nino nino;
  final List<NounGuardado> nouns;
  final CatalogoNouns catalogo;

  @override
  Widget build(BuildContext context) {
    // También sin cromos, y con el mismo sitio y el mismo tamaño. Escondida
    // hasta el primer premio, el niño que aún no ha ganado ninguno —o el padre
    // que acaba de dar de alta a otro hijo— no tiene por dónde entrar a ver
    // qué es esto, y hay que hacerse un día entero de deberes para enterarse.
    final ultimo = nouns.isEmpty
        ? null
        : catalogo.desdeCodigo(nouns.first.codigo);

    return InkWell(
      borderRadius: BorderRadius.circular(Tema.radio),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => PantallaColeccion(nino: nino))),
      child: Container(
        decoration: Tema.cajaTarjeta,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            if (ultimo != null)
              VistaNoun(noun: ultimo, catalogo: catalogo, lado: 52, radio: 10)
            else
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Tema.logroSuave,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.card_giftcard,
                  color: Tema.logro,
                  size: 26,
                ),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mi álbum',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    switch (nouns.length) {
                      0 => 'Mira lo que puedes ganar',
                      1 => '1 cromo',
                      final cuantos => '$cuantos cromos',
                    },
                    style: const TextStyle(
                      fontSize: 15,
                      color: Tema.tintaSuave,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Tema.tintaSuave),
          ],
        ),
      ),
    );
  }
}
