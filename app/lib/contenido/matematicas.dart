import 'numeros.dart';

/// Generador determinista de operaciones.
///
/// No usa IA a propósito: las cuentas se describen mejor con plantillas
/// paramétricas que con un modelo de lenguaje — salen gratis, son infinitas, y
/// la respuesta correcta es exacta por construcción en lugar de tener que
/// fiarse de nadie.
///
/// Dada la misma semilla y el mismo nivel sale exactamente la misma tanda, así
/// que basta guardar `{destrezas, semilla}` para reconstruir el ejercicio al
/// corregir.
class Operacion {
  const Operacion({
    required this.numero,
    required this.destrezaId,
    required this.enunciado,
    required this.dictado,
    required this.respuesta,
    required this.pistas,
    required this.explicacion,
  });

  /// Posición dentro de la tanda, empezando en 1.
  final int numero;
  final String destrezaId;

  /// Cómo se escribe en el cuaderno: "742 : 7".
  final String enunciado;

  /// Cómo lo dice la voz: "setecientos cuarenta y dos dividido entre siete".
  final String dictado;

  /// Respuesta correcta, ya normalizada como texto.
  final String respuesta;

  /// Dos pistas graduales, antes de dar la solución.
  final List<String> pistas;

  /// Explicación paso a paso, redactada para leerse en voz alta.
  final String explicacion;
}

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

// --------------------------------------------------------------- narración ---

const _columnas = ['las unidades', 'las decenas', 'las centenas', 'los millares'];

String _nombreColumna(int i) =>
    i < _columnas.length ? _columnas[i] : 'la siguiente columna';

List<int> _cifrasAlReves(int n) =>
    n.toString().split('').reversed.map(int.parse).toList();

/// Narra una suma en columna, indicando dónde se lleva.
String narrarSuma(int a, int b) {
  final pasos = <String>[];
  final da = _cifrasAlReves(a);
  final db = _cifrasAlReves(b);
  var llevada = 0;

  for (var i = 0; i < (da.length > db.length ? da.length : db.length); i++) {
    final x = i < da.length ? da[i] : 0;
    final y = i < db.length ? db[i] : 0;
    final suma = x + y + llevada;
    final conLlevada = llevada > 0 ? ', más $llevada que me llevaba,' : '';

    if (suma >= 10) {
      pasos.add('En ${_nombreColumna(i)}: $x más $y$conLlevada son $suma. '
          'Escribo ${suma % 10} y me llevo 1.');
      llevada = 1;
    } else {
      pasos.add('En ${_nombreColumna(i)}: $x más $y$conLlevada son $suma. Escribo $suma.');
      llevada = 0;
    }
  }
  if (llevada > 0) pasos.add('Y me queda 1 para escribir delante.');
  return pasos.join(' ');
}

/// Narra una resta en columna, indicando cuándo hay que pedir prestado.
String narrarResta(int a, int b) {
  final pasos = <String>[];
  final da = _cifrasAlReves(a);
  final db = _cifrasAlReves(b);
  var debo = 0;

  for (var i = 0; i < da.length; i++) {
    final y = (i < db.length ? db[i] : 0) + debo;
    final x = da[i];
    if (x < y) {
      pasos.add('En ${_nombreColumna(i)}: $x menos $y no se puede, así que le pido '
          'una a la columna de al lado: ${x + 10} menos $y son ${x + 10 - y}. '
          'Y me llevo una.');
      debo = 1;
    } else {
      pasos.add('En ${_nombreColumna(i)}: $x menos $y son ${x - y}.');
      debo = 0;
    }
  }
  return pasos.join(' ');
}

/// Narra una división larga bajando cifra a cifra.
String narrarDivision(int dividendo, int divisor) {
  final pasos = <String>[];
  var resto = 0;
  var empezado = false;

  for (final cifra in dividendo.toString().split('')) {
    final parcial = resto * 10 + int.parse(cifra);
    final cociente = parcial ~/ divisor;
    final producto = cociente * divisor;

    if (!empezado && cociente == 0) {
      pasos.add('Bajo el $cifra: $parcial entre $divisor no cabe, '
          'así que junto la siguiente cifra.');
      resto = parcial;
      continue;
    }
    empezado = true;
    pasos.add('$parcial entre $divisor cabe a $cociente, porque $cociente por '
        '$divisor son $producto, y $parcial menos $producto da ${parcial - producto}.');
    resto = parcial - producto;
  }

  pasos.add(resto == 0
      ? 'No sobra nada, la división es exacta.'
      : 'Sobran $resto, ese es el resto.');
  return pasos.join(' ');
}

// --------------------------------------------------------------- plantillas ---

/// Techo del rango para un nivel dado, interpolando entre el mínimo (nivel 1)
/// y el máximo (nivel 5).
///
/// El nivel gradúa la dificultad DENTRO de lo que la destreza promete; nunca la
/// magnitud de los números. "Multiplicar por dos cifras" son dos cifras en
/// nivel 1 y en nivel 5: si en nivel 4 saliera un multiplicando de cuatro
/// cifras, el ejercicio dejaría de ser el que dice ser y se saldría del curso.
int _techo(int nivel, int enNivel1, int enNivel5) =>
    enNivel1 + ((enNivel5 - enNivel1) * (nivel - 1) / 4).round();

class _Cuerpo {
  const _Cuerpo(this.enunciado, this.dictado, this.respuesta, this.pistas, this.explicacion);
  final String enunciado;
  final String dictado;
  final String respuesta;
  final List<String> pistas;
  final String explicacion;
}

_Cuerpo _suma(int a, int b) => _Cuerpo(
      '$a + $b',
      '${enteroALetras(a)} más ${enteroALetras(b)}',
      '${a + b}',
      const [
        'Colócalos uno debajo del otro, cuidando que las unidades queden con las unidades.',
        'Empieza siempre por la columna de la derecha, y si te pasas de nueve, te llevas una.',
      ],
      narrarSuma(a, b),
    );

_Cuerpo _resta(int a, int b) => _Cuerpo(
      '$a - $b',
      '${enteroALetras(a)} menos ${enteroALetras(b)}',
      '${a - b}',
      const [
        'Coloca el número grande arriba y el pequeño abajo, bien alineados.',
        'Si arriba tienes un número más pequeño que el de abajo, pídele una a la columna de la izquierda.',
      ],
      narrarResta(a, b),
    );

_Cuerpo _multiplicacion(int a, int b) => _Cuerpo(
      '$a × $b',
      '${enteroALetras(a)} por ${enteroALetras(b)}',
      '${a * b}',
      const [
        'Multiplica primero por las unidades del número de abajo.',
        'Si el número de abajo tiene dos cifras, la segunda fila se escribe corrida un lugar a la izquierda.',
      ],
      b < 10
          ? '$a por $b son ${a * b}.'
          : 'Primero $a por ${b % 10}, que son ${a * (b % 10)}. Después $a por '
              '${b ~/ 10}, que son ${a * (b ~/ 10)}, y lo escribo corrido un lugar. '
              'Sumando las dos filas sale ${a * b}.',
    );

_Cuerpo _division(int dividendo, int divisor) {
  final cociente = dividendo ~/ divisor;
  final resto = dividendo % divisor;
  return _Cuerpo(
    '$dividendo : $divisor',
    '${enteroALetras(dividendo)} dividido entre ${enteroALetras(divisor)}',
    resto == 0 ? '$cociente' : '$cociente resto $resto',
    const [
      'Ve tomando cifras del dividendo por la izquierda hasta que el divisor quepa.',
      'En cada paso: cuántas veces cabe, lo multiplicas, lo restas, y bajas la siguiente cifra.',
    ],
    narrarDivision(dividendo, divisor),
  );
}

typedef _Plantilla = _Cuerpo Function(Azar azar, int nivel);

final Map<String, _Plantilla> _plantillas = {
  'suma_2cifras': (a, n) =>
      _suma(a.entre(11, _techo(n, 29, 89)), a.entre(11, _techo(n, 19, 89))),

  'resta_2cifras': (a, n) {
    final x = a.entre(30, _techo(n, 59, 99));
    return _resta(x, a.entre(10, x - 1));
  },

  'suma_llevada': (a, n) {
    // Se fuerza que las unidades sumen 10 o más: la llevada es el objetivo.
    final ua = a.entre(5, 9);
    final ub = a.entre(10 - ua, 9);
    return _suma(
      a.entre(1, _techo(n, 3, 8)) * 10 + ua,
      a.entre(1, _techo(n, 2, 8)) * 10 + ub,
    );
  },

  'resta_llevada': (a, n) {
    // Unidades del minuendo menores que las del sustraendo: obliga a pedir prestado.
    final ua = a.entre(0, 4);
    final ub = a.entre(ua + 1, 9);
    final da = a.entre(2, _techo(n, 4, 9));
    final db = a.entre(1, da - 1);
    return _resta(da * 10 + ua, db * 10 + ub);
  },

  'suma_3cifras': (a, n) =>
      _suma(a.entre(120, _techo(n, 399, 899)), a.entre(110, _techo(n, 299, 799))),

  'resta_3cifras': (a, n) {
    final x = a.entre(250, _techo(n, 599, 999));
    return _resta(x, a.entre(100, x - 1));
  },

  'tablas_basicas': (a, n) => _multiplicacion(a.elegir([2, 5, 10]), a.entre(2, 10)),

  'tablas_completas': (a, n) => _multiplicacion(a.entre(2, 9), a.entre(2, 10)),

  // Por una cifra: el multiplicando se queda en dos.
  'mult_2x1': (a, n) =>
      _multiplicacion(a.entre(_techo(n, 12, 41), _techo(n, 39, 99)), a.entre(_techo(n, 3, 6), 9)),

  // Tres cifras por dos cifras. Ni una más, en ningún nivel. El suelo del rango
  // sube con el nivel además del techo: si no, en nivel 5 seguirían saliendo
  // multiplicadores de once, que no ejercitan nada.
  'mult_3x2': (a, n) => _multiplicacion(
        a.entre(_techo(n, 110, 401), _techo(n, 399, 999)),
        a.entre(_techo(n, 11, 41), _techo(n, 29, 99)),
      ),

  'div_exacta_1cifra': (a, n) {
    final d = a.entre(2, 9);
    // Se construye desde el cociente para garantizar que sea exacta.
    return _division(d * a.entre(11, _techo(n, 39, 99)), d);
  },

  'div_resto_1cifra': (a, n) {
    final d = a.entre(3, 9);
    return _division(a.entre(20, _techo(n, 49, 110)) * d + a.entre(1, d - 1), d);
  },

  'div_2cifras': (a, n) {
    final d = a.entre(_techo(n, 12, 21), _techo(n, 19, 35));
    return _division(a.entre(_techo(n, 11, 31), _techo(n, 39, 99)) * d + a.entre(0, d - 1), d);
  },

  'decimales_suma_resta': (a, n) {
    final x = a.entre(15, _techo(n, 99, 320)) / 10;
    final y = a.entre(12, _techo(n, 59, 199)) / 10;
    final resultado = ((x + y) * 10).round() / 10;
    return _Cuerpo(
      '${_coma(x)} + ${_coma(y)}',
      '${numeroALetras(x)} más ${numeroALetras(y)}',
      _coma(resultado),
      const [
        'Coloca las comas una debajo de la otra: es lo único que importa al alinear.',
        'Después suma como siempre y baja la coma al resultado.',
      ],
      'Alineando las comas, ${numeroALetras(x)} más ${numeroALetras(y)} '
          'son ${numeroALetras(resultado)}.',
    );
  },
};

String _coma(num n) => n.toString().replaceAll('.', ',');

List<String> get destrezasConPlantilla => _plantillas.keys.toList();

bool tienePlantilla(String destrezaId) => _plantillas.containsKey(destrezaId);

/// Genera una tanda de operaciones. La semilla se guarda con la actividad para
/// poder reconstruir exactamente lo mismo al corregir.
List<Operacion> generarTanda(
  List<String> destrezas,
  int nivel,
  int cuantas,
  int semilla,
) {
  final disponibles = destrezas.where(tienePlantilla).toList();
  if (disponibles.isEmpty) {
    throw ArgumentError('Ninguna de las destrezas pedidas tiene plantilla de generación');
  }

  final azar = Azar(semilla);
  return List.generate(cuantas, (i) {
    // Se rota por las destrezas en vez de sortearlas: así una tanda de 5 con dos
    // destrezas sale 3 y 2, y no 5 de la misma por mala suerte.
    final destrezaId = disponibles[i % disponibles.length];
    final cuerpo = _plantillas[destrezaId]!(azar, nivel);
    return Operacion(
      numero: i + 1,
      destrezaId: destrezaId,
      enunciado: cuerpo.enunciado,
      dictado: cuerpo.dictado,
      respuesta: cuerpo.respuesta,
      pistas: cuerpo.pistas,
      explicacion: cuerpo.explicacion,
    );
  });
}
