import 'package:flutter_test/flutter_test.dart';
import 'package:repasapp/contenido/matematicas.dart';
import 'package:repasapp/correccion/interpretar.dart';
import 'package:repasapp/correccion/matematicas.dart';
import 'package:repasapp/correccion/alinear.dart';
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

  _pruebasDeFotoIlegible();
  _pruebasDeHojaReal();
  _pruebasDeOcrImperfecto();
  _pruebasDeLetraLigada();

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

/// Una foto que el OCR no consigue leer no puede convertirse en un cero.
///
/// Es el fallo más dañino posible del producto: la app le pinta al niño que ha
/// escrito mal todas las palabras, y ese cero cuenta para bajarle de nivel,
/// cuando lo único que ha pasado es que la foto salió borrosa.
void _pruebasDeFotoIlegible() {
  group('foto ilegible', () {
    test('una hoja de la que no se lee nada no es un dictado con 29 fallos', () {
      const referencia = 'Ayer cayó una tormenta muy fuerte. '
          'Mi madre cerró la ventana del salón.';
      // Lo que devuelve ML Kit con una foto sin texto legible.
      final r = corregirDictado(referencia, '');

      expect(r.aciertos, 0);
      // La señal que distingue "no escribió nada" de "no se pudo leer": todas
      // las faltas son omisiones, ninguna es ortográfica.
      expect(r.faltas.every((f) => f.tipo == TipoFalta.omision), isTrue);
    });

    test('un dictado real conserva aciertos aunque tenga faltas', () {
      const referencia = 'Ayer cayó una tormenta muy fuerte.';
      final r = corregirDictado(referencia, 'Ayer cayo una tormenta muy fuerte.');
      expect(r.aciertos, greaterThan(0));
    });
  });
}

/// Caso real capturado en el dispositivo: cinco operaciones en línea, una por
/// renglón, en una hoja de papel cuadriculado.
///
/// El algoritmo antiguo agrupaba los renglones 3, 4 y 5 en un solo bloque; el
/// ejercicio 3 se quedaba el bloque entero, tomaba como resultado el último
/// número que había en él —que era el del ejercicio 5— y los ejercicios 4 y 5
/// se quedaban sin bloque y salían como "sin hacer". Tres fallos que el niño no
/// había cometido.
void _pruebasDeHojaReal() {
  test('cinco operaciones en renglones separados se leen cada una por su lado', () {
    Operacion op(int n, String enunciado, String respuesta) => Operacion(
          numero: n,
          destrezaId: 'mult_3x2',
          enunciado: enunciado,
          dictado: '',
          respuesta: respuesta,
          pistas: const ['', ''],
          explicacion: '',
        );

    final operaciones = [
      op(1, '555 × 49', '27195'),
      op(2, '146 : 4', '36 resto 2'),
      op(3, '299 × 39', '11661'),
      op(4, '416 : 7', '59 resto 3'),
      op(5, '386 × 63', '24318'),
    ];

    // Un renglón por ejercicio, con las proporciones REALES de la hoja: letra
    // grande (unos 80 px de alto) y renglones a 180 px. El hueco entre líneas
    // es menor que 1,6 alturas de línea, que es justo lo que hacía que se
    // fundieran en un solo bloque.
    final lineas = [
      linea('1) 555 x 49 = 27195', y: 120, alto: 80),
      linea('2) 146 : 4 = 36 resto 2', y: 300, alto: 80),
      linea('3) 299 x 39 = 11651', y: 480, alto: 80),
      linea('4) 416 : 7 = 59 resto 3', y: 660, alto: 80),
      linea('5) 386 x 63 = 24318', y: 840, alto: 80),
    ];

    final lectura = interpretarTanda(lineas, operaciones);
    final corregido = corregirTanda(operaciones, lectura);

    // Cuatro bien y solo el fallo de verdad.
    expect(corregido.where((r) => r.correcta).length, 4);
    expect(corregido[2].correcta, isFalse);
    expect(corregido[2].escrito, '11651');
    expect(corregido[2].motivo, MotivoFallo.resultado);

    // Y sobre todo: ninguno se queda sin leer.
    expect(corregido.any((r) => r.motivo == MotivoFallo.sinHacer), isFalse,
        reason: 'ningún ejercicio escrito puede salir como "sin hacer"');
  });
}

/// Las líneas TAL Y COMO las devolvió ML Kit con la hoja real, copiadas del log
/// del dispositivo. Dos dígitos mal leídos, los dos un 1 confundido con un 4.
void _pruebasDeOcrImperfecto() {
  test('un dígito mal leído no puede convertir un ejercicio hecho en sin hacer', () {
    Operacion op(int n, String enunciado, String respuesta) => Operacion(
          numero: n, destrezaId: 'mult_3x2', enunciado: enunciado, dictado: '',
          respuesta: respuesta, pistas: const ['', ''], explicacion: '',
        );

    final operaciones = [
      op(1, '555 × 49', '27195'),
      op(2, '146 : 4', '36 resto 2'),
      op(3, '299 × 39', '11661'),
      op(4, '416 : 7', '59 resto 3'),
      op(5, '386 × 63', '24318'),
    ];

    // Geometría y texto exactos del log de ML Kit.
    final lineas = [
      LineaOcr(texto: '1) 555x 49 = 27195', x: 164, y: 116, ancho: 931, alto: 78),
      LineaOcr(texto: '2) 146 : 4 = 36 resto 2', x: 156, y: 320, ancho: 988, alto: 70),
      LineaOcr(texto: '3) 299 x 39 = 11654', x: 160, y: 510, ancho: 864, alto: 74),
      LineaOcr(texto: '4) 446:7=59 resto 3', x: 158, y: 678, ancho: 996, alto: 78),
      LineaOcr(texto: '5) 386x 63 = 24318', x: 164, y: 862, ancho: 929, alto: 80),
    ];

    final corregido = corregirTanda(operaciones, interpretarTanda(lineas, operaciones));

    // Ningún ejercicio escrito puede salir como "sin hacer" por un dígito.
    expect(corregido.any((r) => r.motivo == MotivoFallo.sinHacer), isFalse);

    // Los tres que el OCR leyó limpios salen correctos.
    expect(corregido[0].correcta, isTrue, reason: '555 × 49');
    expect(corregido[1].correcta, isTrue, reason: '146 : 4');
    expect(corregido[4].correcta, isTrue, reason: '386 × 63');

    // El 4 estaba bien hecho: aunque el OCR leyera mal el enunciado, el
    // resultado que el niño escribió es correcto.
    expect(corregido[3].correcta, isTrue, reason: '416 : 7 = 59 resto 3');

    // Y el 3 sigue marcado mal, que es el único fallo de verdad de la hoja.
    expect(corregido[2].correcta, isFalse, reason: '299 × 39');
  });
}

/// La letra ligada, medida en el dispositivo: de trece palabras, ML Kit
/// destrozó cinco. Si eso se corrige tal cual, la app le dice al niño que ha
/// cometido faltas que no cometió, que es lo peor que puede hacer.
void _pruebasDeLetraLigada() {
  test('una lectura destrozada se distingue de un niño que escribe mal', () {
    const referencia = 'Ayer cayó una tormenta muy fuerte. '
        'Mi madre cerró la ventana del salón.';

    // Salida real de ML Kit con la hoja en letra ligada.
    final mala = corregirDictado(
      referencia,
      'yer cayó na tomnta muy unte Mi madu cernó la ventana del salón.',
    );
    final sinRegla = mala.faltas
        .where((f) => f.tipo == TipoFalta.ortografia || f.tipo == TipoFalta.adicion)
        .length;
    expect(sinRegla / mala.faltas.length, greaterThanOrEqualTo(0.6),
        reason: 'un mal reconocimiento produce faltas que no encajan en ninguna regla');

    // Un niño de verdad falla con nombre y apellido: tildes, b/v, c/z.
    final real = corregirDictado(
      referencia,
      'Ayer cayo una tormenta mui fuerte. Mi madre zerro la bentana del salon.',
    );
    final conRegla = real.faltas
        .where((f) => f.tipo != TipoFalta.ortografia && f.tipo != TipoFalta.adicion)
        .length;
    expect(conRegla / real.faltas.length, greaterThan(0.6),
        reason: 'las faltas de un niño sí encajan en reglas de ortografía');
  });
}
