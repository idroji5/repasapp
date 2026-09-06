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

/// La corrección entera, de la primera marca a la nota guardada.
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
    estado = AppEstado(
      repo: repo,
      voz: Locutora.silenciosa(),
      oido: Escucha.sorda(),
    )..elegir((await repo.nino(ninoId))!);
  });

  Future<ActividadGuardada> actividadDe(Asignatura asignatura) async {
    final sesion = await repo.sesionDeHoy(ninoId);
    return sesion.actividades.firstWhere((a) => a.asignatura == asignatura);
  }

  Future<void> abrir(WidgetTester tester, ActividadGuardada actividad) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

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

  /// Toca algo, bajando por la pantalla si hace falta: la lista se construye a
  /// medida que se baja, así que lo de abajo del todo aún no existe.
  Future<void> tocar(WidgetTester tester, Finder que) async {
    if (que.evaluate().isEmpty) {
      await tester.scrollUntilVisible(que, 240);
    }
    await tester.ensureVisible(que);
    await tester.pump();
    await tester.tap(que);
    await tester.pump();
  }

  /// Deja pasar el tiempo que tarda en guardarse la corrección.
  Future<void> terminarDeGuardar(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 8));
    await tester.pump();
  }

  testWidgets('en matemáticas se marca ejercicio por ejercicio', (tester) async {
    final actividad = await actividadDe(Asignatura.matematicas);
    final operaciones =
        (reconstruir(actividad.contenido, actividad.nivel) as ContenidoOperaciones)
            .operaciones;
    await abrir(tester, actividad);

    // Sin marcar todo, no se puede corregir: media tanda corregida no dice nada.
    expect(find.text('Marca todas para seguir'), findsOneWidget);

    await tocar(tester, find.text('Todas bien'));
    // La primera se marca como fallada, para comprobar que la nota la lleva.
    await tocar(tester, find.text('No me ha salido').first);
    await tocar(tester, find.text('Corregir'));
    await terminarDeGuardar(tester);

    final guardada = (await repo.actividad(actividad.id))!;
    expect(guardada.estado, EstadoActividad.corregida);
    expect(guardada.total, operaciones.length);
    expect(guardada.aciertos, operaciones.length - 1);

    // Y la destreza del ejercicio fallado queda apuntada como floja.
    expect(await repo.destrezasFlojas(ninoId),
        contains(operaciones.first.destrezaId));
  });

  testWidgets('en el dictado se tocan las palabras falladas', (tester) async {
    final actividad = await actividadDe(Asignatura.dictado);
    final dictado = dictadoPorId(actividad.contenido['dictadoId'] as String)!;
    await abrir(tester, actividad);

    // Las palabras difíciles están todas ahí para tocarlas.
    await tester.scrollUntilVisible(find.text(dictado.palabrasClave.last), 240);
    for (final palabra in dictado.palabrasClave) {
      expect(find.text(palabra), findsWidgets, reason: palabra);
    }

    await tocar(tester, find.text(dictado.palabrasClave.first).last);
    await tocar(tester, find.text('Ya está'));

    // Y después, las que no estaban señaladas.
    expect(find.text('¿Alguna falta más?'), findsOneWidget);
    await tocar(tester, find.text('Ninguna'));
    await terminarDeGuardar(tester);

    final guardada = (await repo.actividad(actividad.id))!;
    expect(guardada.estado, EstadoActividad.corregida);
    expect(guardada.total, dictado.numeroDePalabras);
    expect(guardada.aciertos, dictado.numeroDePalabras - 1);

    // La palabra que ha fallado se explica en pantalla, con su regla.
    expect(find.text(dictado.palabrasClave.first), findsWidgets);
    expect(find.textContaining('de ${dictado.numeroDePalabras}'), findsOneWidget);
  });

  testWidgets('desde el resultado se puede volver a hacer lo fallado',
      (tester) async {
    final actividad = await actividadDe(Asignatura.matematicas);
    await abrir(tester, actividad);

    await tocar(tester, find.text('Todas bien'));
    await tocar(tester, find.text('No me ha salido').first);
    await tocar(tester, find.text('Corregir'));
    await terminarDeGuardar(tester);

    expect(find.text('Volver a hacer la que fallé'), findsOneWidget);
    await tocar(tester, find.text('Volver a hacer la que fallé'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Queda una actividad nueva en la sesión de hoy, con solo la fallada.
    final sesion = await repo.sesionDeHoy(ninoId);
    expect(sesion.actividades.last.contenido['solo'], [1]);
    expect(sesion.actividades.last.estado, EstadoActividad.enCurso);
  });

  testWidgets('sin fallos no se ofrece repetir nada', (tester) async {
    final actividad = await actividadDe(Asignatura.matematicas);
    await abrir(tester, actividad);

    await tocar(tester, find.text('Todas bien'));
    await tocar(tester, find.text('Corregir'));
    await terminarDeGuardar(tester);

    expect(find.textContaining('Volver a hacer'), findsNothing);
    expect(find.text('Terminar'), findsOneWidget);
  });

  testWidgets('las faltas de otras palabras se cuentan aparte', (tester) async {
    final actividad = await actividadDe(Asignatura.dictado);
    final dictado = dictadoPorId(actividad.contenido['dictadoId'] as String)!;
    await abrir(tester, actividad);

    await tocar(tester, find.text('No he fallado ninguna'));
    await tocar(tester, find.text('2'));
    await terminarDeGuardar(tester);

    final guardada = (await repo.actividad(actividad.id))!;
    expect(guardada.aciertos, dictado.numeroDePalabras - 2);
  });

  testWidgets('un dictado sin faltas es perfecto', (tester) async {
    final actividad = await actividadDe(Asignatura.dictado);
    await abrir(tester, actividad);

    await tocar(tester, find.text('No he fallado ninguna'));
    await tocar(tester, find.text('Ninguna'));
    await terminarDeGuardar(tester);

    expect(find.text('¡Sin ni un fallo!'), findsOneWidget);
  });
}
