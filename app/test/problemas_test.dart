import 'package:flutter_test/flutter_test.dart';
import 'package:repasapp/contenido/matematicas.dart';
import 'package:repasapp/contenido/numeros.dart';
import 'package:repasapp/contenido/problemas.dart';

/// El número que abre una respuesta: "36 lápices" → 36; "2,60 €" → 2.6.
num? valorDe(String respuesta) {
  final m = RegExp(r'-?\d+(?:,\d+)?').firstMatch(respuesta);
  return m == null ? null : num.parse(m.group(0)!.replaceAll(',', '.'));
}

/// Evalúa la cuenta a la que el problema tiene que llegar.
///
/// Se lee de izquierda a derecha, que es como están escritas: los problemas de
/// dos pasos empiezan siempre por la multiplicación.
num evaluar(String operacion) {
  final piezas = operacion.replaceAll('€', '').split(RegExp(r'\s+'))
    ..removeWhere((p) => p.isEmpty);

  var total = valorDe(piezas.first)!;
  for (var i = 1; i < piezas.length - 1; i += 2) {
    final siguiente = valorDe(piezas[i + 1])!;
    total = switch (piezas[i]) {
      '+' => total + siguiente,
      '-' => total - siguiente,
      '×' => total * siguiente,
      ':' => total / siguiente,
      _ => throw StateError('Operador desconocido en "$operacion"'),
    };
  }
  return total;
}

void main() {
  final destrezas = plantillasDeProblemas.keys.toList();

  /// Recorre todos los niveles con muchas semillas: los enunciados llevan
  /// números al azar y un solo caso no prueba nada.
  void paraTodosLosProblemas(void Function(Operacion op, int nivel) comprobar) {
    for (final destreza in destrezas) {
      for (var nivel = 1; nivel <= 5; nivel++) {
        for (var semilla = 0; semilla < 40; semilla++) {
          for (final op in generarTanda([destreza], nivel, 4, semilla * 7919 + nivel)) {
            comprobar(op, nivel);
          }
        }
      }
    }
  }

  test('todo problema trae enunciado, cuenta, respuesta y dos pistas', () {
    paraTodosLosProblemas((op, _) {
      expect(op.esProblema, isTrue, reason: op.destrezaId);
      expect(op.problema, isNotNull);
      expect(op.problema!.trim().endsWith('?'), isTrue, reason: op.problema);
      expect(op.enunciado, isNotEmpty);
      expect(op.respuesta, isNotEmpty);
      expect(op.pistas, hasLength(2));
      expect(op.explicacion, isNotEmpty);
    });
  });

  test('la respuesta es la que sale de hacer la cuenta', () {
    paraTodosLosProblemas((op, _) {
      final esperado = evaluar(op.enunciado);
      final dada = valorDe(op.respuesta);
      expect(dada, isNotNull, reason: op.respuesta);
      expect((dada! - esperado).abs() < 0.005, isTrue,
          reason: '${op.destrezaId}: "${op.problema}" '
              '→ ${op.enunciado} = ${op.respuesta}');
    });
  });

  test('nunca sale un resultado negativo ni un reparto con resto', () {
    paraTodosLosProblemas((op, _) {
      expect(valorDe(op.respuesta)!, greaterThan(0), reason: op.problema);
      if (op.enunciado.contains(' : ')) {
        expect(evaluar(op.enunciado) % 1, 0, reason: op.problema);
      }
    });
  });

  test('el enunciado está bien escrito', () {
    paraTodosLosProblemas((op, _) {
      final texto = op.problema!;
      expect(texto.contains('  '), isFalse, reason: 'espacio doble: "$texto"');
      expect(texto[0], texto[0].toUpperCase(), reason: 'sin mayúscula: "$texto"');
      // Concordancia: preguntar "¿Cuántos galletas?" enseña a escribir mal.
      expect(RegExp(r'Cuántos (galletas|canicas|flores|pegatinas|manzanas|fichas)')
          .hasMatch(texto), isFalse, reason: texto);
      expect(RegExp(r'Cuántas (cromos|lápices|caramelos|libros|globos|sellos)')
          .hasMatch(texto), isFalse, reason: texto);
    });
  });

  test('se dicta con los números en letras y se enseña con cifras', () {
    paraTodosLosProblemas((op, _) {
      expect(RegExp(r'\d').hasMatch(op.dictado), isFalse,
          reason: '${op.destrezaId} dicta cifras: "${op.dictado}"');
      expect(RegExp(r'\d').hasMatch(op.problema!), isTrue,
          reason: '${op.destrezaId} enseña letras: "${op.problema}"');
    });
  });

  test('los numerales concuerdan con lo que cuentan al leerlos', () {
    expect(numerosALetras('Hay 21 galletas y 208 más.', femenino: true),
        'Hay veintiuna galletas y doscientas ocho más.');
    expect(numerosALetras('Hay 21 cromos y 208 más.'),
        'Hay veintiún cromos y doscientos ocho más.');
    expect(numerosALetras('Cuesta 1 €.'), 'Cuesta un euro.');
  });

  test('los números de una frase se pasan a letras para leerlos', () {
    expect(numerosALetras('Compra 3 cajas de 12 lápices.'),
        'Compra tres cajas de doce lápices.');
    expect(numerosALetras('Cuesta 7 euros.'), 'Cuesta siete euros.');
    expect(numerosALetras('Paga con 5 € y le devuelven 2,40 €.'),
        'Paga con cinco euros y le devuelven dos euros con cuarenta céntimos.');
  });
}
