/// Las piezas que comparten los dos generadores de matemáticas: el de
/// operaciones sueltas y el de problemas con enunciado.
///
/// Viven aparte para que `matematicas.dart` pueda usar las plantillas de
/// `problemas.dart` sin que los dos ficheros se importen en círculo.
library;

import 'numeros.dart';

/// PRNG determinista (mulberry32): misma semilla, misma tanda.
class Azar {
  Azar(int semilla) : _a = semilla & 0xFFFFFFFF;
  int _a;

  double siguiente() {
    _a = (_a + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _a;
    t = (_multiplicar(t ^ (t >> 15), t | 1)) & 0xFFFFFFFF;
    t = (t ^ (t + _multiplicar(t ^ (t >> 7), t | 61))) & 0xFFFFFFFF;
    return ((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0;
  }

  /// Multiplicación truncada a 32 bits, equivalente a Math.imul.
  static int _multiplicar(int a, int b) => (a * b) & 0xFFFFFFFF;

  /// Entero aleatorio en [minimo, maximo], ambos incluidos.
  int entre(int minimo, int maximo) =>
      minimo + (siguiente() * (maximo - minimo + 1)).floor();

  T elegir<T>(List<T> opciones) => opciones[(siguiente() * opciones.length).floor()];
}

/// Techo del rango para un nivel dado, interpolando entre el mínimo (nivel 1)
/// y el máximo (nivel 5).
///
/// El nivel gradúa la dificultad DENTRO de lo que la destreza promete; nunca la
/// magnitud de los números. "Multiplicar por dos cifras" son dos cifras en
/// nivel 1 y en nivel 5: si en nivel 4 saliera un multiplicando de cuatro
/// cifras, el ejercicio dejaría de ser el que dice ser y se saldría del curso.
int techo(int nivel, int enNivel1, int enNivel5) =>
    enNivel1 + ((enNivel5 - enNivel1) * (nivel - 1) / 4).round();

/// Un ejercicio ya redactado, antes de saber qué número hace en la tanda.
class Cuerpo {
  const Cuerpo(
    this.enunciado,
    this.dictado,
    this.respuesta,
    this.pistas,
    this.explicacion, {
    this.planteamiento,
    this.respuestaDicha,
  });

  /// Cómo se escribe en el cuaderno: "742 : 7".
  final String enunciado;

  /// Cómo lo dice la voz: "setecientos cuarenta y dos dividido entre siete".
  final String dictado;

  /// Respuesta correcta, ya normalizada como texto.
  final String respuesta;

  /// La respuesta dicha en voz alta, cuando no basta con leer las cifras.
  final String? respuestaDicha;

  /// Dos pistas graduales, antes de dar la solución.
  final List<String> pistas;

  /// Explicación paso a paso, redactada para leerse en voz alta.
  final String explicacion;

  /// El enunciado del planteamiento, si esto es un planteamiento y no una cuenta suelta.
  /// Cuando lo hay, [enunciado] es la operación que había que plantear.
  final String? planteamiento;

  /// Un planteamiento con enunciado.
  ///
  /// El texto se enseña escrito tal cual, con sus cifras, y se dicta con los
  /// números en letras: en la pantalla un "12" se lee de un vistazo, y al oído
  /// hay que decir "doce" para saber exactamente qué oye el niño.
  ///
  /// `femenino` dice de qué género es lo que se cuenta, para que los numerales
  /// concuerden al leerlos ("doscientas galletas").
  Cuerpo.problema({
    required String texto,
    required String operacion,
    required this.respuesta,
    required this.pistas,
    required this.explicacion,
    bool femenino = false,
  })  : planteamiento = texto,
        dictado = numerosALetras(texto, femenino: femenino),
        respuestaDicha = numerosALetras(respuesta, femenino: femenino),
        enunciado = operacion;
}

typedef Plantilla = Cuerpo Function(Azar azar, int nivel);
