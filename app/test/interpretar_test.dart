import 'package:flutter_test/flutter_test.dart';
import 'package:repasapp/contenido/matematicas.dart';
import 'package:repasapp/correccion/interpretar.dart';
import 'package:repasapp/correccion/matematicas.dart';
import 'package:repasapp/correccion/ocr.dart';

/// Línea de cuaderno de prueba, con la geometría que tendría en la foto.
LineaOcr linea(String texto, {double x = 100, required double y, double alto = 40}) =>
    LineaOcr(texto: texto, x: x, y: y, ancho: 30.0 * texto.length, alto: alto);

Operacion op(int numero, String enunciado, String respuesta) => Operacion(
      numero: numero,
      destrezaId: 'div_exacta_1cifra',
      enunciado: enunciado,
      dictado: '',
      respuesta: respuesta,
      pistas: const ['', ''],
      explicacion: '',
    );

void main() {
  group('dictado', () {
    test('une las líneas de arriba abajo', () {
      final texto = transcripcionDeLineas([
        linea('vive en el campo.', y: 160),
        linea('Mi abuelo', y: 100),
      ]);
      expect(texto, 'Mi abuelo vive en el campo.');
    });

    test('dos trozos a la misma altura se leen de izquierda a derecha', () {
      final texto = transcripcionDeLineas([
        linea('el campo.', x: 400, y: 105),
        linea('Mi abuelo vive en', x: 100, y: 100),
      ]);
      expect(texto, 'Mi abuelo vive en el campo.');
    });
  });

  group('agrupar en bloques', () {
    test('las líneas pegadas forman un bloque y las separadas no', () {
      final bloques = agruparEnBloques([
        linea('47', y: 100),
        linea('+ 25', y: 145),
        linea('72', y: 190),
        linea('88', y: 600), // otro ejercicio, mucho más abajo
      ]);
      expect(bloques.length, 2);
      expect(bloques.first.lineas.length, 3);
    });

    test('dos ejercicios en columnas paralelas no se mezclan', () {
      final bloques = agruparEnBloques([
        linea('47', x: 100, y: 100),
        linea('88', x: 900, y: 140),
      ]);
      expect(bloques.length, 2);
    });
  });

  group('emparejar la hoja con lo dictado', () {
    test('operación en línea con el resultado tras el igual', () {
      final lectura = interpretarTanda(
        [linea('742 : 7 = 106', y: 100)],
        [op(1, '742 : 7', '106')],
      );
      expect(lectura.single.resultadoEscrito, '106');
    });

    test('resultado escrito debajo, en cuenta de columna', () {
      final lectura = interpretarTanda(
        [linea('47', y: 100), linea('+ 25', y: 145), linea('72', y: 190)],
        [op(1, '47 + 25', '72')],
      );
      expect(lectura.single.resultadoEscrito, '72');
    });

    test('ignora el número con el que el niño enumeró el ejercicio', () {
      final lectura = interpretarTanda(
        [linea('2) 47 + 25 = 72', y: 100)],
        [op(2, '47 + 25', '72')],
      );
      expect(lectura.single.resultadoEscrito, '72');
    });

    test('recoge cociente y resto cuando la respuesta lleva los dos', () {
      final lectura = interpretarTanda(
        [linea('45 : 7 = 6 resto 3', y: 100)],
        [op(1, '45 : 7', '6 resto 3')],
      );
      expect(lectura.single.resultadoEscrito, '6 3');
      expect(mismaRespuesta('6 resto 3', lectura.single.resultadoEscrito), isTrue);
    });

    test('varias operaciones en la misma hoja van cada una a su bloque', () {
      final lectura = interpretarTanda(
        [
          linea('1) 742 : 7 = 106', y: 100),
          linea('2) 47 + 25 = 72', y: 400),
        ],
        [op(1, '742 : 7', '106'), op(2, '47 + 25', '72')],
      );
      expect(lectura[0].resultadoEscrito, '106');
      expect(lectura[1].resultadoEscrito, '72');
    });

    test('un ejercicio que no aparece en la hoja se marca sin hacer', () {
      final lectura = interpretarTanda(
        [linea('742 : 7 = 106', y: 100)],
        [op(1, '742 : 7', '106'), op(2, '47 + 25', '72')],
      );
      expect(lectura[1].resultadoEscrito, isEmpty);

      final corregido = corregirTanda(
        [op(1, '742 : 7', '106'), op(2, '47 + 25', '72')],
        lectura,
      );
      expect(corregido[0].correcta, isTrue);
      expect(corregido[1].motivo, MotivoFallo.sinHacer);
    });

    test('si el OCR solo lee medio enunciado, no se inventa el resultado', () {
      // "742" se ha leído como "7A2": mejor decir que no se ha visto que
      // puntuar mal un ejercicio que el niño quizá hizo bien.
      final lectura = interpretarTanda(
        [linea('7A2 : 7 = 106', y: 100)],
        [op(1, '742 : 7', '106')],
      );
      expect(lectura.single.resultadoEscrito, isEmpty);
    });
  });
}
