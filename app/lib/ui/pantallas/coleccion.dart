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

class _PantallaColeccionState extends State<PantallaColeccion> {
  List<NounGuardado>? _nouns;

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
          ([], _) => const _Aviso(
            'Todavía no tienes ninguno.\n\n'
            'Termina las tres actividades de un día y te llevas uno.',
          ),
          (final lista?, final cat?) => _Rejilla(
            nouns: lista,
            catalogo: cat,
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

class _Rejilla extends StatelessWidget {
  const _Rejilla({
    required this.nouns,
    required this.catalogo,
    required this.onTocar,
  });

  final List<NounGuardado> nouns;
  final CatalogoNouns catalogo;
  final void Function(NounGuardado, Noun) onTocar;

  @override
  Widget build(BuildContext context) {
    // El resumen de arriba es la mitad de la gracia de tener una colección:
    // cuántos llevas y cuántos de los buenos.
    final porRareza = <Rareza, int>{};
    for (final n in nouns) {
      porRareza[n.rareza] = (porRareza[n.rareza] ?? 0) + 1;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
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
                      if ((porRareza[rareza] ?? 0) > 0)
                        _Cuenta(rareza, porRareza[rareza]!),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 130,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: nouns.length,
            itemBuilder: (contexto, i) {
              final guardado = nouns[i];
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
        ),
      ],
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Text(
          texto,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 19,
            height: 1.5,
          ),
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
    if (nouns.isEmpty) return const SizedBox.shrink();
    final ultimo = catalogo.desdeCodigo(nouns.first.codigo);

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
              VistaNoun(noun: ultimo, catalogo: catalogo, lado: 52, radio: 10),
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
                    nouns.length == 1 ? '1 dibujo' : '${nouns.length} dibujos',
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
