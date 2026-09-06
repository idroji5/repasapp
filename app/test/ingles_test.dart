import 'package:flutter_test/flutter_test.dart';
import 'package:repasapp/contenido/ingles.dart';
import 'package:repasapp/dominio/asignaturas.dart';
import 'package:repasapp/dominio/curriculo.dart';
import 'package:repasapp/voz/locutora.dart';

/// El banco de inglés está escrito a mano, así que lo que hay que comprobar no
/// es que las frases sean correctas —eso se revisa leyéndolas— sino que
/// ninguna se quede coja: sin respuesta, sin destreza, o sin poder decirse.
void main() {
  test('cada ejercicio tiene destreza conocida y de su asignatura', () {
    final deIngles = destrezas
        .where((d) => d.asignatura == Asignatura.ingles)
        .map((d) => d.id)
        .toSet();

    for (final item in ejerciciosDeIngles) {
      expect(deIngles, contains(item.destrezaId), reason: item.pide);
      expect(item.nivel, inInclusiveRange(1, 5), reason: item.pide);
      expect(item.pide.trim(), isNotEmpty);
      expect(item.respuesta.trim(), isNotEmpty);
    }
  });

  test('todas las destrezas de inglés del currículo tienen ejercicios', () {
    // Una destreza sin ejercicios es una promesa que la app no cumple: el
    // planificador la elegiría y saldría una tanda vacía.
    for (final d in destrezas.where((d) => d.asignatura == Asignatura.ingles)) {
      expect(hayEjerciciosDe(d.id), isTrue, reason: d.id);
    }
  });

  test('lo que va en inglés se marca para decirlo en inglés', () {
    for (final item in ejerciciosDeIngles) {
      final dicho = enunciadoHablado(item);
      if (item.pideEnIngles) {
        expect(dicho, contains('«'),
            reason: 'no se sabría en qué idioma decirlo: $dicho');
      }
      // Y lo marcado tiene que estar bien cerrado, o la voz se lía.
      expect('«'.allMatches(dicho).length, '»'.allMatches(dicho).length,
          reason: dicho);
    }
  });

  test('el hueco de completar no se dice dentro de la frase inglesa', () {
    final item = ejerciciosDeIngles
        .firstWhere((e) => e.tipo == TipoIngles.completar && e.pide.contains('('));
    final dicho = enunciadoHablado(item);

    // La ayuda del hueco está en castellano: metida dentro de las comillas,
    // sonaría a una palabra inglesa más.
    final ingles = Locutora.enIdiomas(dicho).where((t) => t.ingles).single;
    expect(ingles.texto, isNot(contains('(')));
    expect(dicho, contains('La palabra que falta es'));
  });

  test('cada ejercicio trae dos pistas y una explicación', () {
    for (final item in ejerciciosDeIngles) {
      expect(pistasDe(item), hasLength(2), reason: item.pide);
      for (final pista in pistasDe(item)) {
        expect(pista.trim(), isNotEmpty, reason: item.pide);
      }
    }
  });

  test('una tanda mezcla temas y no repite ejercicio', () {
    final delCurso = destrezasHasta(6, Asignatura.ingles).map((d) => d.id).toList();

    for (var semilla = 0; semilla < 30; semilla++) {
      final tanda = tandaDeIngles(delCurso, 3, 5, semilla);

      expect(tanda, hasLength(5), reason: 'semilla $semilla');
      expect(tanda.map((e) => e.enunciado).toSet(), hasLength(5));
      expect(tanda.map((e) => e.destrezaId).toSet().length, greaterThan(2),
          reason: 'cinco del mismo tema no es una tanda: $semilla');
      expect(tanda.map((e) => e.numero), [1, 2, 3, 4, 5]);
    }
  });

  test('la misma semilla da siempre la misma tanda', () {
    final delCurso = destrezasHasta(4, Asignatura.ingles).map((d) => d.id).toList();
    final a = tandaDeIngles(delCurso, 3, 5, 12345);
    final b = tandaDeIngles(delCurso, 3, 5, 12345);
    expect(a.map((e) => e.enunciado), b.map((e) => e.enunciado));
  });

  test('a un niño de 1.º no le sale el pasado simple', () {
    final dePrimero = destrezasHasta(1, Asignatura.ingles).map((d) => d.id).toList();
    final tanda = tandaDeIngles(dePrimero, 2, 5, 7);

    expect(tanda, isNotEmpty);
    for (final e in tanda) {
      expect(e.destrezaId, isIn(dePrimero));
    }
  });

  test('los ejercicios salen del nivel del niño, o de al lado', () {
    final delCurso = destrezasHasta(6, Asignatura.ingles).map((d) => d.id).toList();
    final tanda = tandaDeIngles(delCurso, 1, 5, 3);

    for (final e in tanda) {
      final item = ejerciciosDeIngles
          .firstWhere((i) => i.destrezaId == e.destrezaId && e.respuesta == i.respuesta);
      expect(item.nivel, lessThanOrEqualTo(2), reason: '${e.enunciado} (${item.nivel})');
    }
  });
}
