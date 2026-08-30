import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'datos/bd.dart';
import 'datos/repositorio.dart';
import 'estado.dart';
import 'ui/pantallas/perfiles.dart';
import 'ui/tema.dart';
import 'voz/escucha.dart';
import 'voz/locutora.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Vertical y nada más: el niño la usa apoyada en la mesa, junto al cuaderno.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final bd = await BaseDatos.abrir();
  final estado = AppEstado(
    repo: Repositorio(bd),
    voz: Locutora(),
    oido: Escucha(),
  );
  await estado.cargar();

  runApp(RepasApp(estado: estado));
}

class RepasApp extends StatelessWidget {
  const RepasApp({super.key, required this.estado});

  final AppEstado estado;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: estado,
      child: MaterialApp(
        title: 'RepasApp',
        debugShowCheckedModeBanner: false,
        theme: Tema.construir(),
        home: const PantallaPerfiles(),
      ),
    );
  }
}
