import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:repasapp/datos/bd.dart';
import 'package:repasapp/datos/modelos.dart';
import 'package:repasapp/datos/repositorio.dart';
import 'package:repasapp/dominio/asignaturas.dart';
import 'package:repasapp/dominio/planificador.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Volver a hacer lo que ha salido mal.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const tanda = {
    'tipo': 'tanda_operaciones',
    'destrezas': ['suma_3cifras', 'resta_3cifras', 'mult_3x2'],
    'cuantas': 5,
    'semilla': 4242,
  };

  test('repetir se queda con las falladas y las renumera', () {
    final completa =
        reconstruir(Map<String, dynamic>.from(tanda), 3) as ContenidoOperaciones;
    final repeticion = reconstruir(
      {...tanda, 'solo': [2, 5]},
      3,
    ) as ContenidoOperaciones;

    expect(repeticion.operaciones, hasLength(2));
    // Son exactamente las mismas cuentas, no otras nuevas.
    expect(repeticion.operaciones[0].enunciado, completa.operaciones[1].enunciado);
    expect(repeticion.operaciones[1].enunciado, completa.operaciones[4].enunciado);
    // Pero renumeradas: la voz dirá "la primera" y será la primera.
    expect(repeticion.operaciones.map((o) => o.numero), [1, 2]);
    // Y con su destreza intacta, que es lo que va a las estadísticas.
    expect(repeticion.operaciones[0].destrezaId, completa.operaciones[1].destrezaId);
  });

  test('repetir un recorte traduce los números a la tanda original', () {
    final primera = contenidoRepetido(Map<String, dynamic>.from(tanda),
        soloEstos: [2, 5]);
    expect(primera['solo'], [2, 5]);
    expect(primera['repetido'], isTrue);

    // De esas dos vuelve a fallar la segunda, que en la tanda original es la 5.
    final segunda = contenidoRepetido(primera, soloEstos: [2]);
    expect(segunda['solo'], [5]);
  });

  test('la repetición se llama por lo que es', () {
    expect(tituloDe(Map<String, dynamic>.from(tanda)), '5 operaciones');
    expect(tituloDe({...tanda, 'solo': [2, 5]}), 'Las 2 que fallaron');
    expect(tituloDe({...tanda, 'solo': [2]}), 'La que falló, otra vez');
    expect(
      tituloDe({'tipo': 'dictado', 'dictadoId': 'dic-101', 'repetido': true}),
      'En el campo (otra vez)',
    );
  });

  test('repetir no sube de nivel: ya ha visto las soluciones', () async {
    final db = await BaseDatos.abrir(rutaCompleta: inMemoryDatabasePath);
    final repo = Repositorio(db, azar: Random(3));
    final ninoId = await repo.crearNino(
      nombre: 'Pedro',
      curso: 5,
      minutosDiarios: 15,
      niveles: {Asignatura.matematicas: 3, Asignatura.dictado: 3},
    );
    final sesion = await repo.sesionDeHoy(ninoId);
    final original = sesion.actividades
        .firstWhere((a) => a.asignatura == Asignatura.matematicas);

    // Tres actividades bordadas suben el nivel... si son de verdad.
    for (var i = 0; i < 3; i++) {
      final repetida = await repo.crearActividadExtra(
        ninoId: ninoId,
        asignatura: Asignatura.matematicas,
        nivel: original.nivel,
        contenido: contenidoRepetido(original.contenido, soloEstos: [1]),
      );
      final cambio = await repo.guardarCorreccion(
        actividadId: repetida.id,
        ninoId: ninoId,
        asignatura: Asignatura.matematicas,
        aciertos: 5,
        total: 5,
        faltas: const [],
      );
      expect(cambio, isNull, reason: 'una repetición no mueve el nivel');
    }

    final nino = (await repo.nino(ninoId))!;
    expect(nino.nivelDe(Asignatura.matematicas), 3);
  });

  test('la actividad repetida se guarda aparte, sin pisar la primera', () async {
    final db = await BaseDatos.abrir(rutaCompleta: inMemoryDatabasePath);
    final repo = Repositorio(db, azar: Random(7));
    final ninoId = await repo.crearNino(
      nombre: 'Pedro',
      curso: 5,
      minutosDiarios: 15,
      niveles: {Asignatura.matematicas: 3, Asignatura.dictado: 3},
    );

    final antes = await repo.sesionDeHoy(ninoId);
    final original = antes.actividades
        .firstWhere((a) => a.asignatura == Asignatura.matematicas);

    final repetida = await repo.crearActividadExtra(
      ninoId: ninoId,
      asignatura: Asignatura.matematicas,
      nivel: original.nivel,
      contenido: {...original.contenido, 'solo': [1, 3]},
    );

    expect(repetida.id, isNot(original.id));
    expect(repetida.estado, EstadoActividad.pendiente);
    expect(repetida.contenido['solo'], [1, 3]);

    final despues = await repo.sesionDeHoy(ninoId);
    expect(despues.id, antes.id, reason: 'es la sesión de hoy, no una nueva');
    expect(despues.actividades.length, antes.actividades.length + 1);
    expect(despues.actividades.last.id, repetida.id, reason: 'va la última');
  });
}
