import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repasapp/contenido/dictados.dart';
import 'package:repasapp/datos/bd.dart';
import 'package:repasapp/datos/modelos.dart';
import 'package:repasapp/datos/repositorio.dart';
import 'package:repasapp/dominio/asignaturas.dart';
import 'package:repasapp/dominio/planificador.dart';
import 'package:repasapp/estado.dart';
import 'package:repasapp/ui/pantallas/revision.dart';
import 'package:repasapp/ui/tema.dart';
import 'package:repasapp/voz/escucha.dart';
import 'package:repasapp/voz/locutora.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Prueba de humo de la pantalla de corrección: que el niño pueda recorrerla
/// entera y que lo que marca acabe guardado.
///
/// Sin cámara, esta pantalla es por donde pasa todo lo que la app aprende del
/// niño. Si se rompe, no se pierde una función: se pierden las estadísticas, el
/// nivel y el repaso.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    // Sin isolate: en una prueba de widget el tiempo es falso, y las respuestas
    // de un isolate de verdad no llegan nunca a este hilo.
    databaseFactory = databaseFactoryFfiNoIsolate;
    // El motor de voz no existe en un test; sus llamadas se quedan en nada y la
    // pantalla tiene que funcionar igual.
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  late Repositorio repo;
  late AppEstado estado;
  late int ninoId;

  setUp(() async {
    final db = await BaseDatos.abrir(rutaCompleta: inMemoryDatabasePath);
    repo = Repositorio(db, azar: Random(7));
    ninoId = await repo.crearNino(
      nombre: 'Pedro',
      curso: 5,
      minutosDiarios: 15,
      niveles: {Asignatura.matematicas: 3, Asignatura.dictado: 3},
    );
    estado = AppEstado(repo: repo, voz: Locutora(), oido: Escucha())
      ..elegir((await repo.nino(ninoId))!);
  });

  Future<ActividadGuardada> actividadDe(Asignatura asignatura) async {
    final sesion = await repo.sesionDeHoy(ninoId);
    return sesion.actividades.firstWhere((a) => a.asignatura == asignatura);
  }

  /// Deja pasar el tiempo que tarda en guardarse la corrección. Incluye el
  /// margen que la app se da para arrancar el motor de voz, que en una prueba
  /// no existe y agota su espera.
  Future<void> terminarDeGuardar(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 8));
    await tester.pump();
  }

  Future<void> abrir(WidgetTester tester, ActividadGuardada actividad) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppEstado>.value(
        value: estado,
        child: MaterialApp(
          theme: Tema.construir(),
          home: PantallaRevision(
            actividad: actividad,
            contenido: reconstruir(actividad.contenido, actividad.nivel),
            duracionSegundos: 200,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('en matemáticas se marca ejercicio por ejercicio', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final actividad = await actividadDe(Asignatura.matematicas);
    final operaciones =
        (reconstruir(actividad.contenido, actividad.nivel) as ContenidoOperaciones)
            .operaciones;
    await abrir(tester, actividad);

    // Sin marcar todo, no se puede corregir: media tanda corregida no dice nada.
    expect(find.text('Marca todas para seguir'), findsOneWidget);

    await tester.tap(find.text('Todas bien'));
    await tester.pump();

    // La primera se marca como fallada, para comprobar que la nota la lleva.
    final primerFallo = find.text('No me ha salido').first;
    await tester.ensureVisible(primerFallo);
    await tester.pump();
    await tester.tap(primerFallo);
    await tester.pump();

    await tester.tap(find.text('Corregir'));
    await terminarDeGuardar(tester);

    final guardada = (await repo.actividad(actividad.id))!;
    expect(guardada.estado, EstadoActividad.corregida);
    expect(guardada.total, operaciones.length);
    expect(guardada.aciertos, operaciones.length - 1);

    // Y la destreza del ejercicio fallado queda apuntada como floja.
    expect(await repo.destrezasFlojas(ninoId), contains(operaciones.first.destrezaId));
  });

  testWidgets('en el dictado se dicen las faltas y se marcan las palabras',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final actividad = await actividadDe(Asignatura.dictado);
    final dictado = dictadoPorId(actividad.contenido['dictadoId'] as String)!;
    await abrir(tester, actividad);

    expect(find.text('¿Cuántas faltas has tenido?'), findsOneWidget);
    await tester.tap(find.text('2'));
    await tester.pump();

    // Segunda pantalla: en cuáles.
    expect(find.text('¿En cuáles?'), findsOneWidget);
    await tester.tap(find.text(dictado.palabrasClave.first));
    await tester.pump();
    await tester.tap(find.text('Corregir'));
    await terminarDeGuardar(tester);

    final guardada = (await repo.actividad(actividad.id))!;
    expect(guardada.estado, EstadoActividad.corregida);
    expect(guardada.total, dictado.numeroDePalabras);
    expect(guardada.aciertos, dictado.numeroDePalabras - 2);
    expect(find.textContaining('de ${dictado.numeroDePalabras}'), findsOneWidget);
  });

  testWidgets('un dictado sin faltas no pregunta por palabras', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final actividad = await actividadDe(Asignatura.dictado);
    await abrir(tester, actividad);

    await tester.tap(find.text('0'));
    await terminarDeGuardar(tester);

    expect(find.text('¿En cuáles?'), findsNothing);
    expect(find.text('¡Sin ni un fallo!'), findsOneWidget);
  });
}
