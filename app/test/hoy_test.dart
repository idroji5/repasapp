import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repasapp/datos/bd.dart';
import 'package:repasapp/datos/modelos.dart';
import 'package:repasapp/datos/repositorio.dart';
import 'package:repasapp/dominio/asignaturas.dart';
import 'package:repasapp/estado.dart';
import 'package:repasapp/ui/pantallas/hoy.dart';
import 'package:repasapp/ui/tema.dart';
import 'package:repasapp/voz/escucha.dart';
import 'package:repasapp/voz/locutora.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// El plan de hoy, y sobre todo poder repetir lo que ya se ha hecho.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  late Repositorio repo;
  late AppEstado estado;
  late Nino nino;

  setUp(() async {
    final db = await BaseDatos.abrir(rutaCompleta: inMemoryDatabasePath);
    repo = Repositorio(db, azar: Random(7));
    final id = await repo.crearNino(
      nombre: 'Pedro',
      curso: 5,
      minutosDiarios: 15,
      niveles: {Asignatura.matematicas: 3, Asignatura.dictado: 3},
    );
    nino = (await repo.nino(id))!;
    estado = AppEstado(
      repo: repo,
      voz: Locutora.silenciosa(),
      oido: Escucha.sorda(),
    )..elegir(nino);
    await estado.cargar();
  });

  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppEstado>.value(
        value: estado,
        child: MaterialApp(theme: Tema.construir(), home: PantallaHoy(nino: nino)),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Da por corregida la primera actividad del día.
  Future<ActividadGuardada> darPorHecha() async {
    final sesion = await repo.sesionDeHoy(nino.id);
    final actividad = sesion.actividades.first;
    await repo.guardarCorreccion(
      actividadId: actividad.id,
      ninoId: nino.id,
      asignatura: actividad.asignatura,
      aciertos: 8,
      total: 10,
      faltas: const [],
      duracionSegundos: 120,
    );
    return actividad;
  }

  testWidgets('lo ya hecho se puede volver a hacer', (tester) async {
    final hecha = await darPorHecha();
    await abrir(tester);

    expect(find.text('8 de 10 bien'), findsOneWidget);

    // Antes esto no se podía ni tocar.
    await tester.tap(find.text('8 de 10 bien'));
    await tester.pumpAndSettle();

    expect(find.text('¿Lo vuelves a hacer?'), findsOneWidget);
    await tester.tap(find.text('Volver a hacerlo'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final sesion = await repo.sesionDeHoy(nino.id);
    final nueva = sesion.actividades.last;
    expect(nueva.id, isNot(hecha.id));
    expect(nueva.asignatura, hecha.asignatura);
    expect(nueva.estado, isNot(EstadoActividad.corregida));
  });

  testWidgets('se puede dejar para otro rato', (tester) async {
    await darPorHecha();
    await abrir(tester);

    final antes = (await repo.sesionDeHoy(nino.id)).actividades.length;
    await tester.tap(find.text('8 de 10 bien'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();

    expect(find.text('¿Lo vuelves a hacer?'), findsNothing);
    expect((await repo.sesionDeHoy(nino.id)).actividades.length, antes);
  });

  testWidgets('con todo hecho, se invita a repetir', (tester) async {
    final sesion = await repo.sesionDeHoy(nino.id);
    for (final a in sesion.actividades) {
      await repo.guardarCorreccion(
        actividadId: a.id,
        ninoId: nino.id,
        asignatura: a.asignatura,
        aciertos: 5,
        total: 5,
        faltas: const [],
      );
    }
    await abrir(tester);

    expect(find.text('¡Terminado por hoy!'), findsOneWidget);
    expect(find.textContaining('toca una para repetirla'), findsOneWidget);
  });
}
