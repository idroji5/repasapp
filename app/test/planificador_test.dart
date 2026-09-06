import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:repasapp/contenido/matematicas.dart';
import 'package:repasapp/dominio/asignaturas.dart';
import 'package:repasapp/dominio/curriculo.dart';
import 'package:repasapp/dominio/planificador.dart';

List<String> matesDe(int curso) => destrezasHasta(curso, Asignatura.matematicas)
    .map((d) => d.id)
    .where(tienePlantilla)
    .toList();

void main() {
  test('una tanda no son cinco divisiones seguidas', () {
    // Es exactamente lo que pasaba antes: se cogían las dos destrezas más
    // avanzadas del curso, que en 5.º son dividir y decimales, y al niño le
    // salía la misma cuenta un día detrás de otro.
    for (var curso = 4; curso <= 6; curso++) {
      for (var semilla = 0; semilla < 50; semilla++) {
        final elegidas =
            elegirDestrezasDeMates(matesDe(curso), const [], 5, Random(semilla));
        final familias = elegidas.map(familiaDe).toList();

        expect(elegidas, hasLength(5), reason: 'curso $curso');
        expect(familias.toSet().length, familias.length,
            reason: 'curso $curso, semilla $semilla: familia repetida $elegidas');
      }
    }
  });

  test('dividir sigue saliendo a menudo, solo que no siempre', () {
    // Con más familias que huecos, cada día toca una combinación distinta. Lo
    // que no puede pasar es que una familia desaparezca del reparto.
    final tandas = [
      for (var semilla = 0; semilla < 50; semilla++)
        elegirDestrezasDeMates(matesDe(5), const [], 5, Random(semilla)),
    ];
    final conDivision =
        tandas.where((t) => t.any((id) => familiaDe(id) == 'division')).length;

    expect(conDivision, greaterThan(10));
    expect(conDivision, lessThan(50));
  });

  test('siempre entra un problema con enunciado en cuanto el curso lo permite', () {
    for (var curso = 2; curso <= 6; curso++) {
      for (var semilla = 0; semilla < 30; semilla++) {
        final elegidas =
            elegirDestrezasDeMates(matesDe(curso), const [], 5, Random(semilla));
        expect(elegidas.where((id) => familiaDe(id) == 'problema').length, 1,
            reason: 'curso $curso: $elegidas');
      }
    }
  });

  test('en 1.º todavía no hay problemas, y la tanda se planifica igual', () {
    final elegidas = elegirDestrezasDeMates(matesDe(1), const [], 5, Random(3));
    expect(elegidas, isNotEmpty);
    expect(elegidas.any((id) => familiaDe(id) == 'problema'), isFalse);
    expect(elegidas.toSet().length, elegidas.length, reason: 'sin repetidas');
  });

  test('lo que falla entra primero, pero no llena la tanda entera', () {
    final flojas = ['suma_2cifras', 'resta_2cifras', 'tablas_basicas'];
    final elegidas = elegirDestrezasDeMates(matesDe(6), flojas, 5, Random(1));

    expect(elegidas.where(flojas.contains).length, 2);
    expect(elegidas.take(2).every(flojas.contains), isTrue);
  });

  test('una tanda corta no repite destreza', () {
    for (var cuantas = 2; cuantas <= 5; cuantas++) {
      final elegidas =
          elegirDestrezasDeMates(matesDe(5), const [], cuantas, Random(cuantas));
      expect(elegidas, hasLength(cuantas));
      expect(elegidas.toSet().length, cuantas);
    }
  });

  test('la sesión del día trae una tanda variada de verdad', () {
    final plan = planificarSesion(
      const ContextoPlan(
        curso: 5,
        minutosDiarios: 30,
        niveles: {Asignatura.matematicas: 3, Asignatura.dictado: 3},
      ),
      azar: Random(11),
    );

    final mates = plan.firstWhere((p) => p.asignatura == Asignatura.matematicas);
    final destrezas = (mates.contenido['destrezas'] as List).cast<String>();
    final tanda = generarTanda(
      destrezas,
      mates.nivel,
      mates.contenido['cuantas'] as int,
      mates.contenido['semilla'] as int,
    );

    expect(tanda.map((op) => op.destrezaId).toSet().length, greaterThan(2));
    expect(tanda.any((op) => op.esProblema), isTrue);
  });
}
