/// Comparación de lo que el niño escribió contra el texto que se le dictó.
///
/// Esta clasificación es determinista a propósito. El OCR solo transcribe lo
/// que ve en el papel; decidir si "avía" es un fallo de b/v, de h o de tilde es
/// una regla de ortografía castellana, y una regla se programa — así el
/// resultado es idéntico cada vez y se puede probar.
library;

enum TipoFalta {
  tilde,
  bV,
  h,
  gJ,
  llY,
  cZ,
  rRr,
  mAntesPB,
  mayuscula,
  unionSeparacion,
  puntuacion,
  omision,
  adicion,
  ortografia,
}

class Falta {
  const Falta({
    required this.posicion,
    required this.esperado,
    required this.escrito,
    required this.tipo,
    this.tambien = const [],
    this.destrezaId,
  });

  /// Índice de la palabra dentro del texto de referencia.
  final int posicion;
  final String esperado;
  final String escrito;
  final TipoFalta tipo;

  /// Otras reglas falladas en la misma palabra ("avía" por "había": h y b/v).
  final List<TipoFalta> tambien;

  /// Microdestreza a la que se imputa el fallo, si se puede deducir.
  final String? destrezaId;
}

class Correccion {
  const Correccion(this.totalPalabras, this.aciertos, this.faltas);
  final int totalPalabras;
  final int aciertos;
  final List<Falta> faltas;

  double get porcentaje => totalPalabras == 0 ? 0 : aciertos / totalPalabras;
}

// ------------------------------------------------------------ utilidades ---

/// Quita solo las tildes y la diéresis. La eñe NO se toca: si se convirtiera en
/// ene, escribir "ano" por "año" pasaría por bueno, que es justo el tipo de
/// falta que hay que cazar.
const Map<String, String> _sinTilde = {
  'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u',
  'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', 'Ü': 'U',
};

String sinTildes(String s) {
  final b = StringBuffer();
  for (final c in s.split('')) {
    b.write(_sinTilde[c] ?? c);
  }
  return b.toString();
}

final RegExp _signos = RegExp(r'[.,;:¿?¡!"«»()—–\-]');

/// Palabras, sin signos de puntuación. La puntuación se evalúa aparte.
List<String> palabrasDe(String texto) => texto
    .replaceAll(_signos, ' ')
    .split(RegExp(r'\s+'))
    .where((p) => p.isNotEmpty)
    .toList();

String _normal(String s) => sinTildes(s.toLowerCase());

int levenshtein(String a, String b) {
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var anterior = List<int>.generate(b.length + 1, (j) => j);
  var actual = List<int>.filled(b.length + 1, 0);

  for (var i = 1; i <= a.length; i++) {
    actual[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final coste = a[i - 1] == b[j - 1] ? 0 : 1;
      final borrar = anterior[j] + 1;
      final insertar = actual[j - 1] + 1;
      final sustituir = anterior[j - 1] + coste;
      actual[j] = borrar < insertar
          ? (borrar < sustituir ? borrar : sustituir)
          : (insertar < sustituir ? insertar : sustituir);
    }
    final intercambio = anterior;
    anterior = actual;
    actual = intercambio;
  }
  return anterior[b.length];
}

// ------------------------------------------- clases de fallo ortográfico ---

/// Cada regla reduce la palabra a una forma canónica en la que la distinción
/// que la regla gobierna desaparece. Si dos palabras distintas comparten
/// canónica, el fallo es exactamente de esa regla.
class _Regla {
  const _Regla(this.tipo, this.canonica);
  final TipoFalta tipo;
  final String Function(String) canonica;
}

final List<_Regla> _reglas = [
  _Regla(TipoFalta.h, (s) => s.replaceAll('h', '')),
  _Regla(TipoFalta.bV, (s) => s.replaceAll('v', 'b')),
  _Regla(TipoFalta.llY, (s) => s.replaceAll('ll', 'y')),
  _Regla(TipoFalta.gJ, (s) => s.replaceAll('j', 'g')),
  _Regla(TipoFalta.cZ, (s) => s.replaceAll('z', 's').replaceAll(RegExp(r'c(?=[ei])'), 's')),
  _Regla(TipoFalta.rRr, (s) => s.replaceAll('rr', 'r')),
  _Regla(TipoFalta.mAntesPB, (s) => s.replaceAll(RegExp(r'm(?=[pb])'), 'n')),
];

const Set<String> _diacriticos = {
  'tu', 'el', 'mi', 'si', 'te', 'de', 'se', 'mas', 'aun', 'solo',
  'que', 'como', 'cuando', 'donde', 'quien', 'cual', 'cuanto', 'cuanta',
};

final RegExp _vocales = RegExp(r'[aeiouáéíóúü]', caseSensitive: false);
final RegExp _vocalesConTilde = RegExp(r'[áéíóú]');

/// Aguda, llana o esdrújula, contando grupos vocálicos desde el final hasta el
/// que lleva la tilde. Solo tiene sentido sobre la palabra correcta —la que
/// lleva la tilde puesta—, que es justo la que tenemos como referencia.
String? tipoAcentual(String palabra) {
  final p = palabra.toLowerCase();
  final grupos = <bool>[]; // ¿lleva tilde este grupo vocálico?
  var i = 0;

  while (i < p.length) {
    if (_vocales.hasMatch(p[i])) {
      var conTilde = false;
      while (i < p.length && _vocales.hasMatch(p[i])) {
        if (_vocalesConTilde.hasMatch(p[i])) conTilde = true;
        i++;
      }
      grupos.add(conTilde);
    } else {
      i++;
    }
  }

  final indice = grupos.indexOf(true);
  if (indice == -1) return null;

  final desdeElFinal = grupos.length - 1 - indice;
  if (desdeElFinal == 0) return 'aguda';
  if (desdeElFinal == 1) return 'llana';
  return 'esdrujula';
}

String _destrezaDeTilde(String esperado) {
  if (_diacriticos.contains(_normal(esperado))) return 'tilde_diacritica';
  switch (tipoAcentual(esperado)) {
    case 'aguda':
      return 'tilde_agudas';
    case 'llana':
      return 'tilde_llanas';
    case 'esdrujula':
      return 'tilde_esdrujulas';
    default:
      return 'tilde_agudas';
  }
}

final RegExp _terminacionesAba = RegExp(r'(aba|abas|ábamos|abais|aban)$');

String? destrezaDeFalta(TipoFalta tipo, String esperado) {
  switch (tipo) {
    case TipoFalta.tilde:
      return _destrezaDeTilde(esperado);
    case TipoFalta.bV:
      return _terminacionesAba.hasMatch(esperado.toLowerCase())
          ? 'b_verbos_aba'
          : 'b_v_reglas';
    case TipoFalta.h:
      return 'h_frecuente';
    case TipoFalta.gJ:
      return 'g_j';
    case TipoFalta.llY:
      return 'll_y';
    case TipoFalta.cZ:
      return 'c_z';
    case TipoFalta.rRr:
      return 'r_rr';
    case TipoFalta.mAntesPB:
      return 'm_antes_p_b';
    case TipoFalta.mayuscula:
      return 'mayuscula_inicial';
    case TipoFalta.unionSeparacion:
      return _normal(esperado).startsWith('porque') ? 'porque' : null;
    default:
      return null;
  }
}

class Clasificacion {
  const Clasificacion(this.tipo, this.tambien);
  final TipoFalta tipo;
  final List<TipoFalta> tambien;
}

/// Qué reglas ortográficas hacen falta para explicar la diferencia.
///
/// Un niño puede fallar dos cosas en la misma palabra: escribir "avía" por
/// "había" es a la vez una hache que falta y una be que se ha vuelto uve. Se
/// aplican todas las canónicas a la vez; si así coinciden, son necesarias justo
/// aquellas cuya retirada vuelve a separarlas.
List<TipoFalta> _reglasNecesarias(String e, String c) {
  String aplicar(List<_Regla> reglas, String s) =>
      reglas.fold(s, (x, r) => r.canonica(x));

  if (aplicar(_reglas, e) != aplicar(_reglas, c)) return [];

  return _reglas
      .where((regla) {
        final resto = _reglas.where((r) => r != regla).toList();
        return aplicar(resto, e) != aplicar(resto, c);
      })
      .map((r) => r.tipo)
      .toList();
}

Clasificacion clasificarDetallado(String esperado, String escrito) {
  if (esperado.toLowerCase() == escrito.toLowerCase()) {
    return const Clasificacion(TipoFalta.mayuscula, []);
  }

  final e = esperado.toLowerCase();
  final c = escrito.toLowerCase();
  if (sinTildes(e) == sinTildes(c)) return const Clasificacion(TipoFalta.tilde, []);

  // Las reglas se prueban sobre las palabras sin tildes: cuando además falta la
  // tilde, el fallo que hay que enseñar es el de la letra.
  final necesarias = _reglasNecesarias(sinTildes(e), sinTildes(c));
  if (necesarias.isNotEmpty) {
    return Clasificacion(necesarias.first, necesarias.sublist(1));
  }
  return const Clasificacion(TipoFalta.ortografia, []);
}

TipoFalta clasificar(String esperado, String escrito) =>
    clasificarDetallado(esperado, escrito).tipo;

// ------------------------------------------------------------ alineación ---

enum _Op { igual, sust, falta, sobra }

class _Paso {
  _Paso(this.op, this.idx, {this.esp = '', this.esc = ''});
  final _Op op;
  final int idx;
  String esp;
  String esc;
}

const double _costeHueco = 1.0;

double _costeSustitucion(String a, String b) {
  final na = _normal(a);
  final nb = _normal(b);
  if (na == nb) return 0.05; // difieren solo en mayúsculas

  final d = levenshtein(na, nb);
  final parecido = 1 - d / (na.length > nb.length ? na.length : nb.length);
  // Palabras parecidas se emparejan; palabras distintas salen más baratas como
  // hueco (omisión + adición), que es lo que realmente ocurrió.
  return parecido >= 0.5 ? 0.6 : 1.6;
}

/// Needleman–Wunsch sobre palabras.
List<_Paso> _alinear(List<String> referencia, List<String> escritas) {
  final m = referencia.length;
  final n = escritas.length;
  final d = List.generate(m + 1, (_) => List<double>.filled(n + 1, 0));

  for (var i = 1; i <= m; i++) {
    d[i][0] = i * _costeHueco;
  }
  for (var j = 1; j <= n; j++) {
    d[0][j] = j * _costeHueco;
  }

  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      final diagonal = d[i - 1][j - 1] + _costeSustitucion(referencia[i - 1], escritas[j - 1]);
      final arriba = d[i - 1][j] + _costeHueco;
      final izquierda = d[i][j - 1] + _costeHueco;
      d[i][j] = [diagonal, arriba, izquierda].reduce((a, b) => a < b ? a : b);
    }
  }

  bool casi(double a, double b) => (a - b).abs() < 1e-9;

  final pasos = <_Paso>[];
  var i = m;
  var j = n;
  while (i > 0 || j > 0) {
    if (i > 0 &&
        j > 0 &&
        casi(d[i][j], d[i - 1][j - 1] + _costeSustitucion(referencia[i - 1], escritas[j - 1]))) {
      final esp = referencia[i - 1];
      final esc = escritas[j - 1];
      pasos.add(_Paso(esp == esc ? _Op.igual : _Op.sust, i - 1, esp: esp, esc: esc));
      i--;
      j--;
    } else if (i > 0 && casi(d[i][j], d[i - 1][j] + _costeHueco)) {
      pasos.add(_Paso(_Op.falta, i - 1, esp: referencia[i - 1]));
      i--;
    } else {
      pasos.add(_Paso(_Op.sobra, i, esc: escritas[j - 1]));
      j--;
    }
  }
  return pasos.reversed.toList();
}

/// Junta los casos en los que el niño partió una palabra en dos o unió dos en
/// una. Sin esto, escribir "por que" en lugar de "porque" cuenta como dos
/// errores distintos en vez de como el error de separación que realmente es.
///
/// El hueco puede quedar a cualquiera de los dos lados de la sustitución según
/// por dónde pase la alineación, así que se comprueban ambos órdenes.
List<_Paso> _fusionarSeparaciones(List<_Paso> pasos) {
  bool esPar(_Paso? p) => p != null && (p.op == _Op.sust || p.op == _Op.igual);

  final salida = <_Paso>[];
  for (var i = 0; i < pasos.length; i++) {
    final a = pasos[i];
    final b = i + 1 < pasos.length ? pasos[i + 1] : null;
    _Paso? fusionada;

    if (b != null) {
      // El niño partió una palabra: sobra un trozo, antes o después.
      if (esPar(a) && b.op == _Op.sobra && _normal(a.esc + b.esc) == _normal(a.esp)) {
        fusionada = _Paso(_Op.sust, a.idx, esp: a.esp, esc: '${a.esc} ${b.esc}');
      } else if (a.op == _Op.sobra && esPar(b) && _normal(a.esc + b.esc) == _normal(b.esp)) {
        fusionada = _Paso(_Op.sust, b.idx, esp: b.esp, esc: '${a.esc} ${b.esc}');
      }
      // El niño unió dos palabras: falta una de la referencia, antes o después.
      else if (esPar(a) && b.op == _Op.falta && _normal(a.esp + b.esp) == _normal(a.esc)) {
        fusionada = _Paso(_Op.sust, a.idx, esp: '${a.esp} ${b.esp}', esc: a.esc);
      } else if (a.op == _Op.falta && esPar(b) && _normal(a.esp + b.esp) == _normal(b.esc)) {
        fusionada = _Paso(_Op.sust, a.idx, esp: '${a.esp} ${b.esp}', esc: b.esc);
      }
    }

    if (fusionada != null) {
      salida.add(fusionada);
      i++;
    } else {
      salida.add(a);
    }
  }
  return salida;
}

const List<(String, String)> _signosVigilados = [
  (',', 'coma_enumeracion'),
  ('¿', 'interrogacion_exclamacion'),
  ('?', 'interrogacion_exclamacion'),
  ('¡', 'interrogacion_exclamacion'),
  ('!', 'interrogacion_exclamacion'),
];

/// Como máximo dos avisos de puntuación: si no, tapan los fallos de ortografía.
const int _maxFaltasPuntuacion = 2;

List<Falta> _faltasDePuntuacion(String referencia, String escrito) {
  int cuenta(String texto, String signo) => signo.allMatches(texto).length;

  final salida = <Falta>[];
  for (final (signo, destreza) in _signosVigilados) {
    if (cuenta(referencia, signo) - cuenta(escrito, signo) > 0) {
      salida.add(Falta(
        posicion: -1,
        esperado: signo,
        escrito: '',
        tipo: TipoFalta.puntuacion,
        destrezaId: destreza,
      ));
    }
    if (salida.length >= _maxFaltasPuntuacion) break;
  }
  return salida;
}

/// Corrige un dictado: compara la transcripción de lo escrito contra el texto
/// de referencia y devuelve los aciertos y la lista clasificada de faltas.
Correccion corregirDictado(String referencia, String transcripcion) {
  final ref = palabrasDe(referencia);
  final esc = palabrasDe(transcripcion);
  final pasos = _fusionarSeparaciones(_alinear(ref, esc));

  final faltas = <Falta>[];
  var aciertos = 0;

  for (final paso in pasos) {
    switch (paso.op) {
      case _Op.igual:
        aciertos++;
      case _Op.sust:
        // Una fusión deja un espacio dentro de la palabra: eso es, por
        // definición, un fallo de unión o separación y no de ortografía.
        final separacion = paso.esp.contains(' ') || paso.esc.contains(' ');
        final c = separacion
            ? const Clasificacion(TipoFalta.unionSeparacion, [])
            : clasificarDetallado(paso.esp, paso.esc);
        faltas.add(Falta(
          posicion: paso.idx,
          esperado: paso.esp,
          escrito: paso.esc,
          tipo: c.tipo,
          tambien: c.tambien,
          destrezaId: destrezaDeFalta(c.tipo, paso.esp),
        ));
      case _Op.falta:
        faltas.add(Falta(
          posicion: paso.idx,
          esperado: paso.esp,
          escrito: '',
          tipo: TipoFalta.omision,
        ));
      case _Op.sobra:
        faltas.add(Falta(
          posicion: paso.idx,
          esperado: '',
          escrito: paso.esc,
          tipo: TipoFalta.adicion,
        ));
    }
  }

  faltas.addAll(_faltasDePuntuacion(referencia, transcripcion));

  return Correccion(ref.length, aciertos, faltas);
}
