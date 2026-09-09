import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../datos/modelos.dart';
import '../../dominio/coleccion.dart';
import '../../estado.dart';
import '../tema.dart';
import '../widgets/noun.dart';

/// La colección del niño.
///
/// Es la única pantalla de la app que no es papel y tinta, y lo es a
/// propósito: el premio consiste precisamente en salir de la calma del
/// cuaderno. Al trabajo no le sobra ni un color; aquí sí.
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
      backgroundColor: const Color(0xFF1A1420),
      appBar: AppBar(
        title: const Text('Mi colección'),
        backgroundColor: const Color(0xFF1A1420),
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: switch ((nouns, catalogo)) {
          (null, _) => const Center(child: CircularProgressIndicator()),
          (_, null) => const _Aviso('No he podido cargar los dibujos.'),
          (final lista?, final cat?) => _Album(
            nouns: lista,
            catalogo: cat,
            orden: _orden,
            onOrden: (orden) => setState(() => _orden = orden),
            onTocar: (guardado, noun) => _abrirFicha(cat, guardado, noun),
          ),
        },
      ),
    );
  }

  void _abrirFicha(CatalogoNouns catalogo, NounGuardado guardado, Noun noun) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF2A2334),
      showDragHandle: true,
      builder: (_) =>
          _Ficha(guardado: guardado, noun: noun, catalogo: catalogo),
    );
  }
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

    // Un álbum vacío se abre igual, con sus cuatro páginas por estrenar. Es
    // media gracia de tener uno: ver lo que falta antes de tenerlo.
    final vacio = nouns.isEmpty;

    return CustomScrollView(
      slivers: [
        if (vacio)
          const SliverToBoxAdapter(
            child: _Aviso(
              'Todavía no tienes ninguno.\n'
              'Termina las tres actividades de un día y te llevas uno.',
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: _Resumen(nouns: nouns, porRareza: porRareza),
          ),
          SliverToBoxAdapter(child: _Selector(orden: orden, onOrden: onOrden)),
        ],
        if (!vacio && orden == _Orden.fecha)
          _rejilla(nouns)
        else
          // De la más rara a la más común. Un álbum se abre por la página que
          // uno quiere enseñar, no por la que tiene repetida.
          for (final rareza in Rareza.values.reversed) ...[
            SliverToBoxAdapter(
              child: _Cabecera(
                rareza: rareza,
                cuantos: porRareza[rareza]!.length,
                unoDeCada: catalogo.unoDeCada(rareza),
              ),
            ),
            if (porRareza[rareza]!.isEmpty)
              SliverToBoxAdapter(child: _Hueco(rareza))
            else
              _rejilla(porRareza[rareza]!),
          ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _rejilla(List<NounGuardado> lista) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    sliver: SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 130,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: lista.length,
      itemBuilder: (contexto, i) {
        final guardado = lista[i];
        final noun = catalogo.desdeCodigo(guardado.codigo);
        if (noun == null) return const SizedBox.shrink();
        return _Casilla(
          guardado: guardado,
          noun: noun,
          catalogo: catalogo,
          onTocar: () => onTocar(guardado, noun),
        );
      },
    ),
  );
}

/// Cuántos llevas y cuántos de los buenos: la mitad de la gracia de tener una
/// colección.
class _Resumen extends StatelessWidget {
  const _Resumen({required this.nouns, required this.porRareza});

  final List<NounGuardado> nouns;
  final Map<Rareza, List<NounGuardado>> porRareza;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          Text(
            nouns.length == 1 ? '1 dibujo' : '${nouns.length} dibujos',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          // En Wrap y no en Row: con las cuatro rarezas y un número de tres
          // cifras, una fila se sale de un móvil estrecho.
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
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
}

/// Los dos órdenes del álbum.
class _Selector extends StatelessWidget {
  const _Selector({required this.orden, required this.onOrden});

  final _Orden orden;
  final ValueChanged<_Orden> onOrden;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      // A medias y no cada una a su ancho: así las dos son igual de grandes y
      // de fáciles de acertar, y ninguna se sale en un móvil estrecho.
      child: Row(
        children: [
          Expanded(
            child: _Pestana(
              texto: 'Por rareza',
              activa: orden == _Orden.rareza,
              onTocar: () => onOrden(_Orden.rareza),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Pestana(
              texto: 'Por fecha',
              activa: orden == _Orden.fecha,
              onTocar: () => onOrden(_Orden.fecha),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pestana extends StatelessWidget {
  const _Pestana({
    required this.texto,
    required this.activa,
    required this.onTocar,
  });

  final String texto;
  final bool activa;
  final VoidCallback onTocar;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTocar,
      // La zona de toque llega a los 44 puntos de alto aunque la píldora mida
      // menos: un dedo de siete años no apunta tan fino.
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: activa ? Colors.white : Colors.white10,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          texto,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: activa ? const Color(0xFF1A1420) : Colors.white70,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// La cabecera de una página del álbum.
class _Cabecera extends StatelessWidget {
  const _Cabecera({
    required this.rareza,
    required this.cuantos,
    required this.unoDeCada,
  });

  final Rareza rareza;
  final int cuantos;
  final int unoDeCada;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        children: [
          SelloRareza(rareza),
          const SizedBox(width: 10),
          Text(
            '$cuantos',
            style: TextStyle(
              color: colorDeRareza(rareza),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          // "1 de cada 1" no es un dato, así que del normal no se dice nada.
          if (rareza != Rareza.normal)
            Flexible(
              child: Text(
                '1 de cada $unoDeCada',
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white38, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }
}

/// Una página del álbum todavía sin estrenar.
///
/// El hueco se enseña en lugar de esconder la página: un álbum sin sitios
/// vacíos no da ninguna gana de seguir.
class _Hueco extends StatelessWidget {
  const _Hueco(this.rareza);

  final Rareza rareza;

  @override
  Widget build(BuildContext context) {
    final color = colorDeRareza(rareza);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        height: 76,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          'Todavía ninguno',
          style: TextStyle(
            color: color.withValues(alpha: 0.85),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _Cuenta extends StatelessWidget {
  const _Cuenta(this.rareza, this.cuantos);

  final Rareza rareza;
  final int cuantos;

  @override
  Widget build(BuildContext context) {
    final color = colorDeRareza(rareza);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          '$cuantos',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

class _Casilla extends StatelessWidget {
  const _Casilla({
    required this.guardado,
    required this.noun,
    required this.catalogo,
    required this.onTocar,
  });

  final NounGuardado guardado;
  final Noun noun;
  final CatalogoNouns catalogo;
  final VoidCallback onTocar;

  @override
  Widget build(BuildContext context) {
    final color = colorDeRareza(guardado.rareza);
    return GestureDetector(
      onTap: onTocar,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          // El marco es la rareza. Un niño aprende el código de colores en dos
          // días y ya no necesita abrir nada para saber cuáles son los buenos.
          border: Border.all(
            color: color,
            width: guardado.rareza == Rareza.normal ? 1 : 3,
          ),
        ),
        padding: const EdgeInsets.all(3),
        child: VistaNoun(noun: noun, catalogo: catalogo, radio: 12),
      ),
    );
  }
}

/// La ficha de un Noun: cómo se llama, qué es y cuánto cuesta que salga.
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
    final raro = noun.rasgoRaroQueExplicar;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VistaNoun(noun: noun, catalogo: catalogo, lado: 180, radio: 18),
          const SizedBox(height: 18),
          Text(
            noun.nombre,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SelloRareza(guardado.rareza, grande: true),
          if (guardado.rareza != Rareza.normal) ...[
            const SizedBox(height: 14),
            Text(
              'Sale 1 de cada ${catalogo.unoDeCada(guardado.rareza)}',
              style: const TextStyle(color: Colors.white70, fontSize: 17),
            ),
          ],
          if (raro != null) ...[
            const SizedBox(height: 6),
            Text(
              'Lo raro: ${raro.nombre}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorDeRareza(guardado.rareza),
                fontSize: 16,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'Lo ganaste el ${_fecha(guardado.dia)}',
            style: const TextStyle(color: Colors.white38, fontSize: 15),
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

class _Aviso extends StatelessWidget {
  const _Aviso(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 18,
          height: 1.5,
        ),
      ),
    );
  }
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
    // También sin dibujos, y con el mismo sitio y el mismo tamaño. Escondida
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
                    'Mi colección',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    switch (nouns.length) {
                      0 => 'Mira lo que puedes ganar',
                      1 => '1 dibujo',
                      final cuantos => '$cuantos dibujos',
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
