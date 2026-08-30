import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:repasapp/datos/bd.dart';
import 'package:repasapp/datos/modelos.dart';
import 'package:repasapp/datos/repositorio.dart';
import 'package:repasapp/dominio/asignaturas.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Repositorio repo;

  /// Reloj de mentira: la app depende tanto del día que hay que poder moverlo.
  late DateTime ahora;

  setUp(() async {
    // Base de datos en memoria: cada prueba empieza de cero.
    final db = await BaseDatos.abrir(rutaCompleta: inMemoryDatabasePath);
    ahora = DateTime(2026, 3, 2, 17, 30);
    repo = Repositorio(db, azar: Random(7), reloj: () => ahora);
  });

  Future<int> crearPedro() => repo.crearNino(
        nombre: 'Pedro',
        curso: 4,
        anoNacimiento: 2017,
        minutosDiarios: 15,
        // El caso que justifica todo el diseño: avanzado en mates, refuerzo en
        // dictado, y el mismo niño.
        niveles: {Asignatura.matematicas: 4, Asignatura.dictado: 2},
      );

  test('el nivel se guarda por asignatura, no por niño', () async {
    final id = await crearPedro();
    final pedro = (await repo.nino(id))!;

    expect(pedro.nivelDe(Asignatura.matematicas), 4);
    expect(pedro.nivelDe(Asignatura.dictado), 2);
  });

  test('la sesión de hoy se crea sola y es la misma si se vuelve a pedir', () async {
    final id = await crearPedro();

    final primera = await repo.sesionDeHoy(id);
    expect(primera.actividades, isNotEmpty);
    expect(primera.minutos, 15);

    final segunda = await repo.sesionDeHoy(id);
    expect(segunda.id, primera.id);
    expect(segunda.actividades.length, primera.actividades.length);
  });

  test('cada actividad usa el nivel de SU asignatura', () async {
    final id = await crearPedro();
    final sesion = await repo.sesionDeHoy(id);

    for (final actividad in sesion.actividades) {
      final esperado = actividad.asignatura == Asignatura.matematicas ? 4 : 2;
      expect(actividad.nivel, esperado, reason: 'en ${actividad.asignatura.name}');
    }
  });

  test('guardar una corrección apunta las faltas y las destrezas flojas', () async {
    final id = await crearPedro();
    final sesion = await repo.sesionDeHoy(id);
    final actividad = sesion.actividades.first;

    await repo.guardarCorreccion(
      actividadId: actividad.id,
      ninoId: id,
      asignatura: actividad.asignatura,
      aciertos: 8,
      total: 10,
      faltas: const [
        FaltaGuardable(
            destrezaId: 'tilde_agudas', tipo: 'tilde', esperado: 'balón', escrito: 'balon'),
        FaltaGuardable(
            destrezaId: 'tilde_agudas', tipo: 'tilde', esperado: 'cayó', escrito: 'cayo'),
      ],
      duracionSegundos: 240,
    );

    final guardada = (await repo.actividad(actividad.id))!;
    expect(guardada.estado, EstadoActividad.corregida);
    expect(guardada.aciertos, 8);

    expect(await repo.destrezasFlojas(id), contains('tilde_agudas'));
  });

  test('tres días seguidos bordando el dictado suben el nivel', () async {
    final id = await crearPedro();
    final cambios = <CambioDeNivel?>[];

    for (var dia = 0; dia < 3; dia++) {
      ahora = ahora.add(const Duration(days: 1));
      final sesion = await repo.sesionDeHoy(id);

      for (final actividad in sesion.actividades) {
        cambios.add(await repo.guardarCorreccion(
          actividadId: actividad.id,
          ninoId: id,
          asignatura: actividad.asignatura,
          aciertos: 10,
          total: 10,
          faltas: const [],
        ));
      }
    }

    final subidasDeDictado = cambios
        .whereType<CambioDeNivel>()
        .where((c) => c.asignatura == Asignatura.dictado)
        .toList();

    expect(subidasDeDictado, hasLength(1), reason: 'un solo cambio por semana');
    expect(subidasDeDictado.single.antes, 2);
    expect(subidasDeDictado.single.despues, 3);
    expect((await repo.nino(id))!.nivelDe(Asignatura.dictado), 3);
  });

  test('dos días fallando la mitad bajan el nivel', () async {
    final id = await repo.crearNino(
      nombre: 'Lucía',
      curso: 4,
      niveles: {Asignatura.dictado: 3, Asignatura.matematicas: 3},
    );

    for (var dia = 0; dia < 2; dia++) {
      ahora = ahora.add(const Duration(days: 1));
      final sesion = await repo.sesionDeHoy(id);
      for (final actividad in sesion.actividades) {
        await repo.guardarCorreccion(
          actividadId: actividad.id,
          ninoId: id,
          asignatura: actividad.asignatura,
          aciertos: 3,
          total: 10,
          faltas: const [],
        );
      }
    }

    expect((await repo.nino(id))!.nivelDe(Asignatura.dictado), 2);
  });

  test('la racha cuenta los días seguidos de estudio', () async {
    final id = await crearPedro();

    for (var dia = 0; dia < 3; dia++) {
      ahora = ahora.add(const Duration(days: 1));
      final sesion = await repo.sesionDeHoy(id);
      await repo.guardarCorreccion(
        actividadId: sesion.actividades.first.id,
        ninoId: id,
        asignatura: sesion.actividades.first.asignatura,
        aciertos: 9,
        total: 10,
        faltas: const [],
      );
    }
    expect((await repo.estadisticas(id)).racha, 3);

    // Se salta dos días: la racha se rompe y vuelve a empezar.
    ahora = ahora.add(const Duration(days: 3));
    final sesion = await repo.sesionDeHoy(id);
    await repo.guardarCorreccion(
      actividadId: sesion.actividades.first.id,
      ninoId: id,
      asignatura: sesion.actividades.first.asignatura,
      aciertos: 9,
      total: 10,
      faltas: const [],
    );
    expect((await repo.estadisticas(id)).racha, 1);
  });

  test('el nivel que fija el padre queda bloqueado y el autoajuste no lo toca', () async {
    final id = await crearPedro();
    await repo.fijarNivel(id, Asignatura.dictado, 1);

    final sesion = await repo.sesionDeHoy(id);
    final dictado =
        sesion.actividades.where((a) => a.asignatura == Asignatura.dictado).first;

    final cambio = await repo.guardarCorreccion(
      actividadId: dictado.id,
      ninoId: id,
      asignatura: Asignatura.dictado,
      aciertos: 0,
      total: 10,
      faltas: const [],
    );

    expect(cambio, isNull);
    expect((await repo.nino(id))!.nivelDe(Asignatura.dictado), 1);
  });

  test('el PIN se guarda cifrado y solo lo abre el correcto', () async {
    expect(await repo.hayPin(), isFalse);

    await repo.fijarPin('1234');
    expect(await repo.hayPin(), isTrue);
    expect(await repo.comprobarPin('1234'), isTrue);
    expect(await repo.comprobarPin('0000'), isFalse);
  });

  test('las estadísticas resumen lo que un padre quiere saber', () async {
    final id = await crearPedro();
    final sesion = await repo.sesionDeHoy(id);
    final actividad = sesion.actividades.first;

    await repo.guardarCorreccion(
      actividadId: actividad.id,
      ninoId: id,
      asignatura: actividad.asignatura,
      aciertos: 7,
      total: 10,
      faltas: const [
        FaltaGuardable(destrezaId: 'b_v_reglas', tipo: 'b_v', esperado: 'bien', escrito: 'vien'),
      ],
      duracionSegundos: 300,
    );

    final e = await repo.estadisticas(id);
    expect(e.racha, 1);
    expect(e.porAsignatura.length, Asignatura.values.length);

    final resumen =
        e.porAsignatura.firstWhere((r) => r.asignatura == actividad.asignatura);
    expect(resumen.porcentajeAcierto, 70);
    expect(e.erroresFrecuentes.first.destrezaId, 'b_v_reglas');
    expect(e.erroresFrecuentes.first.nombre, 'Reglas generales de b y v');
  });
}
