/// Qué regla de ortografía se juega en cada palabra.
///
/// El niño corrige su propio dictado mirando la pantalla: marca en qué palabras
/// ha tenido falta y la app le explica por qué se escriben así. Para explicarlo
/// hay que saber qué regla gobierna esa palabra —si "había" es cosa de la hache
/// o de la be—, y eso es ortografía castellana, no adivinación: se programa
/// como reglas, así el resultado es idéntico cada vez y se puede probar.
library;

enum TipoFalta {
  tilde,
  bV,
  h,
  gJ,
  llY,
  cZ,
  cQu,
  gGu,
  rRr,
  mAntesPB,
  dieresis,
  xS,
  homofono,
  mayuscula,
  unionSeparacion,

  /// La palabra es difícil pero no cae bajo ninguna regla con nombre.
  ortografia,
}

class Falta {
  const Falta({
    required this.esperado,
    required this.tipo,
    this.destrezaId,
  });

  /// Cómo se escribe de verdad.
  final String esperado;
  final TipoFalta tipo;

  /// Microdestreza a la que se imputa el fallo, si se puede deducir.
  final String? destrezaId;
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

final RegExp _signos = RegExp(r'[.,;:¿?¡!"«»()—–]');

/// Palabras, sin signos de puntuación.
List<String> palabrasDe(String texto) => texto
    .replaceAll(_signos, ' ')
    .split(RegExp(r'\s+'))
    .where((p) => p.isNotEmpty)
    .toList();

String _normal(String s) => sinTildes(s.toLowerCase());

// -------------------------------------------------- reglas por microdestreza ---

const Set<String> _diacriticos = {
  'tu', 'el', 'mi', 'si', 'te', 'de', 'se', 'mas', 'aun', 'solo',
};

const Set<String> _interrogativos = {
  'que', 'como', 'cuando', 'donde', 'quien', 'cual', 'cuanto', 'cuanta',
  'cuantos', 'cuantas', 'cuales', 'quienes',
};

const Set<String> _homofonos = {
  'hay', 'ahi', 'ay', 'haber', 'a ver', 'echo', 'hecho', 'ha', 'a',
  'halla', 'haya', 'valla', 'vaya', 'tubo', 'tuvo', 'basta', 'vasta',
};

final RegExp _vocales = RegExp(r'[aeiouáéíóúü]', caseSensitive: false);
final RegExp _vocalesConTilde = RegExp(r'[áéíóú]');
final RegExp _terminacionesAba = RegExp(r'(aba|abas|ábamos|abais|aban)$');
final RegExp _adjetivosConV = RegExp(r'(iva|ivo|ivas|ivos|ave|aves|eve|eves)$');

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

/// Qué clase de falta comete quien se equivoca en esta microdestreza.
TipoFalta tipoDeDestreza(String destrezaId) => switch (destrezaId) {
      'tilde_agudas' ||
      'tilde_llanas' ||
      'tilde_esdrujulas' ||
      'tilde_diacritica' ||
      'tilde_interrogativos' ||
      'hiato' =>
        TipoFalta.tilde,
      'h_frecuente' => TipoFalta.h,
      'b_verbos_aba' || 'b_v_reglas' || 'v_adjetivos' => TipoFalta.bV,
      'll_y' => TipoFalta.llY,
      'g_j' => TipoFalta.gJ,
      'c_z' => TipoFalta.cZ,
      'c_qu' => TipoFalta.cQu,
      'g_gu' => TipoFalta.gGu,
      'r_rr' => TipoFalta.rRr,
      'm_antes_p_b' => TipoFalta.mAntesPB,
      'dieresis' => TipoFalta.dieresis,
      'x_s' => TipoFalta.xS,
      'homofonos' => TipoFalta.homofono,
      'mayuscula_inicial' => TipoFalta.mayuscula,
      'porque' => TipoFalta.unionSeparacion,
      _ => TipoFalta.ortografia,
    };

/// ¿Esta palabra pone a prueba esa microdestreza?
///
/// Es la pregunta que permite explicar una falta sin saber qué escribió el
/// niño: si ha marcado "había" en un dictado que trabaja la hache y las tildes,
/// lo que hay que explicarle de esa palabra es la hache.
bool ejercita(String destrezaId, String palabra) {
  final p = _normal(palabra);
  final conTildes = palabra.toLowerCase();

  return switch (destrezaId) {
    'tilde_agudas' => tipoAcentual(palabra) == 'aguda',
    'tilde_llanas' => tipoAcentual(palabra) == 'llana',
    'tilde_esdrujulas' => tipoAcentual(palabra) == 'esdrujula',
    'tilde_diacritica' => _diacriticos.contains(p),
    'tilde_interrogativos' =>
      _interrogativos.contains(p) && _vocalesConTilde.hasMatch(conTildes),
    // Un hiato de los que llevan tilde: vocal fuerte junto a í o ú tildada.
    'hiato' => RegExp(r'[aeoáéó][íú]|[íú][aeoáéó]').hasMatch(conTildes),
    'h_frecuente' => p.contains('h'),
    'b_verbos_aba' => _terminacionesAba.hasMatch(conTildes),
    'v_adjetivos' => _adjetivosConV.hasMatch(p),
    'b_v_reglas' => p.contains('b') || p.contains('v'),
    'll_y' => p.contains('ll') || p.contains('y'),
    'g_j' => p.contains('j') || RegExp(r'g[ei]').hasMatch(p),
    'c_z' => p.contains('z') || RegExp(r'c[ei]').hasMatch(p),
    'c_qu' => RegExp(r'qu[ei]|c[aou]').hasMatch(p),
    'g_gu' => RegExp(r'gu[ei]|g[aou]').hasMatch(p),
    'r_rr' => p.contains('rr'),
    'm_antes_p_b' => RegExp(r'm[pb]').hasMatch(p),
    'dieresis' => conTildes.contains('ü'),
    'x_s' => p.contains('x'),
    'homofonos' => _homofonos.contains(p),
    'mayuscula_inicial' =>
      palabra.isNotEmpty && palabra[0] == palabra[0].toUpperCase(),
    'porque' => p.startsWith('porque') || p.startsWith('por que'),
    _ => false,
  };
}

/// Orden en que se prueban las reglas cuando una palabra encaja en varias.
///
/// "Había" es hache y es be; lo que hay que enseñarle al niño es la hache, que
/// es la que se le ha caído. Las reglas de letra concreta van antes que las
/// generales, y la mayúscula la última: casi cualquier palabra al principio de
/// una frase la cumple, y casi nunca es lo que ha fallado.
const List<String> _prioridad = [
  'homofonos',
  'porque',
  'dieresis',
  'h_frecuente',
  'b_verbos_aba',
  'v_adjetivos',
  'r_rr',
  'm_antes_p_b',
  'll_y',
  'g_j',
  'c_z',
  'x_s',
  'b_v_reglas',
  'c_qu',
  'g_gu',
  'tilde_diacritica',
  'tilde_interrogativos',
  'hiato',
  'tilde_esdrujulas',
  'tilde_agudas',
  'tilde_llanas',
  'mayuscula_inicial',
];

/// Qué falta describe mejor una palabra que el niño dice haber escrito mal.
///
/// Se busca entre las destrezas que el dictado dice trabajar: son las que se
/// eligieron al escribir el texto y las únicas que le han explicado en clase.
/// Si la palabra no encaja en ninguna, se devuelve una falta sin regla: se le
/// enseña cómo se escribe y se deja de inventar explicaciones.
Falta faltaDePalabra(String palabra, List<String> destrezasDelDictado) {
  final candidatas = _prioridad.where(destrezasDelDictado.contains);

  for (final destrezaId in candidatas) {
    if (ejercita(destrezaId, palabra)) {
      return Falta(
        esperado: palabra,
        tipo: tipoDeDestreza(destrezaId),
        destrezaId: destrezaId,
      );
    }
  }

  // Fuera de lo que el dictado promete trabajar, la tilde sigue siendo
  // evidente: la palabra la lleva puesta y no hay nada que adivinar.
  if (_vocalesConTilde.hasMatch(palabra.toLowerCase())) {
    final normal = _normal(palabra);
    final destrezaId = _interrogativos.contains(normal)
        ? 'tilde_interrogativos'
        : _diacriticos.contains(normal)
            ? 'tilde_diacritica'
            : switch (tipoAcentual(palabra)) {
                'llana' => 'tilde_llanas',
                'esdrujula' => 'tilde_esdrujulas',
                _ => 'tilde_agudas',
              };
    return Falta(esperado: palabra, tipo: TipoFalta.tilde, destrezaId: destrezaId);
  }

  return Falta(esperado: palabra, tipo: TipoFalta.ortografia);
}
