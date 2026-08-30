import 'package:flutter_test/flutter_test.dart';
import 'package:repasapp/contenido/matematicas.dart';

/// Cuántas cifras tiene cada operando del enunciado.
List<int> _cifras(String enunciado) => RegExp(r'\d+')
    .allMatches(enunciado)
    .map((m) => m.group(0)!.length)
    .toList();

/// Recorre todos los niveles con muchas semillas: los rangos son aleatorios y
/// un solo caso no prueba nada.
void paraTodaLaTanda(String destreza, void Function(Operacion op, int nivel) comprobar) {
  for (var nivel = 1; nivel <= 5; nivel++) {
    for (var semilla = 0; semilla < 60; semilla++) {
      for (final op in generarTanda([destreza], nivel, 5, semilla * 7919 + nivel)) {
        comprobar(op, nivel);
      }
    }
  }
}

void main() {
  group('una destreza no puede salirse de lo que promete su nombre', () {
    test('multiplicar por dos cifras son tres cifras por dos, en todos los niveles', () {
      paraTodaLaTanda('mult_3x2', (op, nivel) {
        final c = _cifras(op.enunciado);
        expect(c[0], lessThanOrEqualTo(3),
            reason: 'nivel $nivel: "${op.enunciado}" tiene un multiplicando de ${c[0]} cifras');
        expect(c[1], lessThanOrEqualTo(2),
            reason: 'nivel $nivel: "${op.enunciado}" multiplica por ${c[1]} cifras');
      });
    });

    test('multiplicar por una cifra: dos cifras por una', () {
      paraTodaLaTanda('mult_2x1', (op, nivel) {
        final c = _cifras(op.enunciado);
        expect(c[0], lessThanOrEqualTo(2), reason: 'nivel $nivel: "${op.enunciado}"');
        expect(c[1], 1, reason: 'nivel $nivel: "${op.enunciado}"');
      });
    });

    test('sumas y restas de dos cifras se quedan en dos cifras', () {
      for (final destreza in ['suma_2cifras', 'resta_2cifras', 'suma_llevada', 'resta_llevada']) {
        paraTodaLaTanda(destreza, (op, nivel) {
          for (final cifras in _cifras(op.enunciado)) {
            expect(cifras, lessThanOrEqualTo(2),
                reason: '$destreza nivel $nivel: "${op.enunciado}"');
          }
        });
      }
    });

    test('sumas y restas de tres cifras se quedan en tres cifras', () {
      for (final destreza in ['suma_3cifras', 'resta_3cifras']) {
        paraTodaLaTanda(destreza, (op, nivel) {
          for (final cifras in _cifras(op.enunciado)) {
            expect(cifras, lessThanOrEqualTo(3),
                reason: '$destreza nivel $nivel: "${op.enunciado}"');
          }
        });
      }
    });

    test('dividir entre una cifra: el divisor tiene una cifra', () {
      for (final destreza in ['div_exacta_1cifra', 'div_resto_1cifra']) {
        paraTodaLaTanda(destreza, (op, nivel) {
          final c = _cifras(op.enunciado);
          expect(c[1], 1, reason: '$destreza nivel $nivel: "${op.enunciado}"');
          expect(c[0], lessThanOrEqualTo(4), reason: '$destreza nivel $nivel: "${op.enunciado}"');
        });
      }
    });

    test('dividir entre dos cifras: el divisor tiene dos cifras', () {
      paraTodaLaTanda('div_2cifras', (op, nivel) {
        expect(_cifras(op.enunciado)[1], 2, reason: 'nivel $nivel: "${op.enunciado}"');
      });
    });
  });

  group('las operaciones son correctas y decibles', () {
    test('la división exacta no deja resto y la de resto sí', () {
      paraTodaLaTanda('div_exacta_1cifra', (op, _) {
        expect(op.respuesta, isNot(contains('resto')), reason: op.enunciado);
      });
      paraTodaLaTanda('div_resto_1cifra', (op, _) {
        expect(op.respuesta, contains('resto'), reason: op.enunciado);
      });
    });

    test('cada operación se puede decir en voz alta y explicar', () {
      for (final destreza in destrezasConPlantilla) {
        paraTodaLaTanda(destreza, (op, _) {
          expect(op.dictado, isNotEmpty, reason: '$destreza: ${op.enunciado}');
          expect(op.explicacion, isNotEmpty, reason: '$destreza: ${op.enunciado}');
          expect(op.pistas, hasLength(2));
          // No se le puede leer un número en cifras al niño.
          expect(RegExp(r'\d').hasMatch(op.dictado), isFalse,
              reason: '$destreza dicta cifras en vez de letras: "${op.dictado}"');
        });
      }
    });

    test('la misma semilla da siempre la misma tanda', () {
      final a = generarTanda(['mult_3x2', 'div_resto_1cifra'], 4, 5, 1422718876);
      final b = generarTanda(['mult_3x2', 'div_resto_1cifra'], 4, 5, 1422718876);
      expect(a.map((o) => o.enunciado).toList(), b.map((o) => o.enunciado).toList());
    });
  });
}
