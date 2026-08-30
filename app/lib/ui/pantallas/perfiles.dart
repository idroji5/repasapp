import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../datos/modelos.dart';
import '../../dominio/asignaturas.dart';
import '../../estado.dart';
import '../tema.dart';
import '../widgets/botones.dart';
import 'alta_nino.dart';
import 'hoy.dart';
import 'padres.dart';

/// Primera pantalla: quién va a estudiar.
///
/// Es la única de la app pensada para que la use el niño solo, sin saber leer
/// mucho: nombres grandes, una tarjeta por hermano, y nada más.
class PantallaPerfiles extends StatelessWidget {
  const PantallaPerfiles({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<AppEstado>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('RepasApp'),
        actions: [
          IconButton(
            tooltip: 'Zona de padres',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PantallaPadres()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: estado.cargando
            ? const Center(child: CircularProgressIndicator())
            : estado.ninos.isEmpty
                ? const _SinNinos()
                : _ListaDeNinos(ninos: estado.ninos),
      ),
    );
  }
}

class _SinNinos extends StatelessWidget {
  const _SinNinos();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vamos a empezar', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          const Text(
            'Crea el perfil de tu hijo o hija. Necesito su curso para elegir el '
            'contenido, y su nivel en cada asignatura para saber cuánto exigirle.',
            style: TextStyle(fontSize: 17, height: 1.5, color: Tema.tintaSuave),
          ),
          const SizedBox(height: 32),
          BotonGrande(
            texto: 'Crear un perfil',
            icono: Icons.person_add_alt_1,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PantallaAltaNino()),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListaDeNinos extends StatelessWidget {
  const _ListaDeNinos({required this.ninos});

  final List<Nino> ninos;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text('¿Quién estudia hoy?', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 20),
        for (final nino in ninos) ...[
          _TarjetaNino(nino: nino),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PantallaAltaNino()),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Añadir otro perfil'),
          style: TextButton.styleFrom(
            foregroundColor: Tema.tintaSuave,
            minimumSize: const Size(0, 52),
          ),
        ),
      ],
    );
  }
}

class _TarjetaNino extends StatelessWidget {
  const _TarjetaNino({required this.nino});

  final Nino nino;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Tema.radio),
        onTap: () {
          context.read<AppEstado>().elegir(nino);
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PantallaHoy(nino: nino)),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: Tema.cajaTarjeta,
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Tema.accionSuave,
                child: Text(
                  nino.nombre.characters.first.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Tema.accion,
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nino.nombre, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      '${nino.curso}.º de Primaria · ${nino.minutosDiarios} min al día',
                      style: const TextStyle(color: Tema.tintaSuave, fontSize: 14.5),
                    ),
                    const SizedBox(height: 10),
                    // Los niveles se enseñan por separado a propósito: es la
                    // idea central del producto y conviene que se vea de un vistazo.
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final asignatura in Asignatura.values)
                          Pastilla(
                            '${asignatura.nombre} ${nino.nivelDe(asignatura)}/5',
                            color: Tema.colorDe(asignatura.name),
                            fondo: Tema.colorDe(asignatura.name).withValues(alpha: 0.10),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Tema.tintaSuave),
            ],
          ),
        ),
      ),
    );
  }
}
