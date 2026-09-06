import 'numeros.dart';

/// Un ejercicio suelto, ya redactado y listo para plantearlo.
///
/// Lo comparten las asignaturas que van por tandas —matemáticas e inglés—
/// porque de una cuenta y de una frase en inglés hace falta lo mismo: cómo se
/// dice, cómo se escribe, cuál es la solución, y qué contar si no sale.
class Ejercicio {
  const Ejercicio({
    required this.numero,
    required this.destrezaId,
    required this.enunciado,
    required this.dictado,
    required this.respuesta,
    required this.pistas,
    required this.explicacion,
    this.planteamiento,
    this.respuestaDicha,
  });

  /// Posición dentro de la tanda, empezando en 1.
  final int numero;
  final String destrezaId;

  /// Cómo se escribe en el cuaderno: "742 : 7".
  final String enunciado;

  /// Cómo lo dice la voz: "setecientos cuarenta y dos dividido entre siete".
  final String dictado;

  /// Respuesta correcta, ya normalizada como texto: "106", "32 resto 12".
  final String respuesta;

  /// Cómo se dice la respuesta en voz alta. Si no se dice de una forma
  /// concreta, se leen las cifras tal cual.
  final String? respuestaDicha;

  /// La respuesta, para leerla al corregir.
  String get respuestaEnVozAlta => respuestaDicha ?? numerosALetras(respuesta);

  /// Dos pistas graduales, antes de dar la solución.
  final List<String> pistas;

  /// Explicación paso a paso, redactada para leerse en voz alta.
  final String explicacion;

  /// El enunciado, si es un planteamiento con texto en lugar de una cuenta suelta.
  /// Cuando lo hay, [enunciado] es la operación a la que había que llegar.
  final String? planteamiento;

  bool get tienePlanteamiento => planteamiento != null;

  /// La misma operación en otro sitio de la tanda. Al repetir solo las que
  /// salieron mal, la tercera y la quinta pasan a ser la primera y la segunda.
  Ejercicio conNumero(int otro) => Ejercicio(
        numero: otro,
        destrezaId: destrezaId,
        enunciado: enunciado,
        dictado: dictado,
        respuesta: respuesta,
        pistas: pistas,
        explicacion: explicacion,
        planteamiento: planteamiento,
        respuestaDicha: respuestaDicha,
      );
}
