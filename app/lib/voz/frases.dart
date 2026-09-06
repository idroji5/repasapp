import '../contenido/numeros.dart';
import '../correccion/ortografia.dart';

/// Todo lo que dice la voz, en un solo sitio, para que la personalidad sea
/// coherente en toda la app y se pueda revisar de una pasada.
class Frases {
  const Frases._();

  static String saludo(String nombre) => 'Hola, $nombre. ¿Empezamos?';

  static String planDelDia(int minutos, List<String> actividades) =>
      'Hoy tenemos $minutos minutos: ${enumerar(actividades)}.';

  // ------------------------------------------------------------ dictado ---
  static String dictadoIntro(String titulo) =>
      'Vamos a hacer un dictado. Se titula $titulo.';
  static const String prepararPapel =
      'Prepara papel y lápiz. Cuando estés preparado, di: listo.';
  static const String empezamos =
      'Muy bien. Empezamos. Te voy a leer cada frase dos veces, '
      'la segunda más despacio.';
  static const String dictadoFin =
      'Ya está. Ahora lo corregimos juntos: te enseño el dictado en la '
      'pantalla para que lo compares con tu hoja.';

  // -------------------------------------------------------- matemáticas ---
  static String matematicasIntro(int cuantas, {bool conProblemas = false}) =>
      conProblemas
          ? 'Vamos a hacer $cuantas ejercicios: hay cuentas y algún problema. '
              'Escríbelos en el cuaderno.'
          : 'Vamos a hacer $cuantas operaciones. Escríbelas en el cuaderno.';
  static const String empezamosMates =
      'Muy bien. Empezamos. Si necesitas oírlo otra vez, di: repite.';
  static String operacion(int numero, String dictado) =>
      '${_capitalizar(ordinalFemenino(numero))}: $dictado.';
  static String matematicasFin(int cuantas) =>
      'Esos son los $cuantas. Resuélvelos con calma y, cuando termines, '
      'los corregimos juntos.';

  // ------------------------------------------------------- corrección ---
  static const String comparaDictado =
      'Este es el dictado. Compáralo con tu hoja, sin prisa, y marca en la '
      'pantalla cuántas faltas has tenido.';
  static const String comparaOperaciones =
      'Aquí tienes las soluciones. Mira una por una si te ha salido, y marca '
      'las que no.';

  // ---------------------------------------------------------- resultado ---
  static const String todoBien = '¡Perfecto! No has tenido ni un fallo. Muy bien hecho.';
  static String casiTodoBien(int fallos) =>
      'Muy bien, casi todo correcto. Solo ${fallos == 1 ? "un fallo" : "$fallos fallos"}.';
  static String resumenFallos(int fallos, List<String> palabras) =>
      'Has tenido ${fallos == 1 ? "un fallo" : "$fallos fallos"}. '
      'Vamos a repasar ${enumerar(palabras)}.';
  static String cuantasFaltas(int faltas) =>
      'Has tenido ${faltas == 1 ? "una falta" : "$faltas faltas"}.';
  static const String animo = 'No pasa nada, para eso repasamos. Mañana seguimos.';
  static const String apuntaLasFaltas =
      'Apunta las palabras que has fallado y escríbelas bien tres veces.';

  // ------------------------------------------------------------- pistas ---
  static String fallasteEn(int numero) =>
      'En la ${ordinalFemenino(numero)} te has equivocado.';
  static const String loTienes = '¿Ya lo ves, o te doy otra pista?';
  static String solucion(String respuesta) => 'La respuesta correcta es $respuesta.';
}

String _capitalizar(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String enumerar(List<String> elementos) {
  if (elementos.isEmpty) return '';
  if (elementos.length == 1) return elementos.first;
  return '${elementos.sublist(0, elementos.length - 1).join(", ")} y ${elementos.last}';
}

// ------------------------------------------- explicación de cada falta ---

const Map<String, String> _nombreLetra = {
  'b': 'be', 'v': 'uve', 'h': 'hache', 'g': 'ge', 'j': 'jota',
  'c': 'ce', 'z': 'zeta', 's': 'ese', 'y': 'i griega', 'll': 'elle',
  'r': 'erre', 'rr': 'doble erre', 'm': 'eme', 'n': 'ene', 'x': 'equis',
};

/// Qué letra de las dos usa realmente la palabra correcta.
String _letraCorrecta(String esperado, List<String> opciones) {
  final e = esperado.toLowerCase();
  final encontrada = opciones.firstWhere((l) => e.contains(l), orElse: () => opciones.first);
  return _nombreLetra[encontrada] ?? '';
}

const Map<String, String> _explicacionTilde = {
  'tilde_agudas': 'lleva tilde porque es aguda y termina en ene, en ese o en vocal',
  'tilde_llanas': 'lleva tilde porque es llana y no termina en ene, ni en ese, ni en vocal',
  'tilde_esdrujulas': 'lleva tilde porque es esdrújula, y todas las esdrújulas la llevan',
  'tilde_diacritica':
      'lleva tilde para distinguirla de la otra palabra que se escribe igual pero significa otra cosa',
  'tilde_interrogativos':
      'lleva tilde porque está preguntando o exclamando, y ahí siempre la lleva',
  'hiato': 'lleva tilde porque la i o la u van solas en su sílaba y rompen el diptongo',
};

/// Por qué se escribe así esta palabra, redactado para leerse en voz alta.
String razonDe(Falta falta) => switch (falta.tipo) {
      TipoFalta.tilde =>
        _explicacionTilde[falta.destrezaId ?? ''] ?? 'lleva tilde',
      TipoFalta.h => 'lleva hache, aunque no se oiga al pronunciarla',
      TipoFalta.bV => falta.destrezaId == 'b_verbos_aba'
          ? 'se escribe con be, porque los verbos terminados en -aba se escriben siempre con be'
          : falta.destrezaId == 'v_adjetivos'
              ? 'se escribe con uve, porque los adjetivos acabados en -ivo, -iva y -ave la llevan'
              : 'se escribe con ${_letraCorrecta(falta.esperado, ["b", "v"])}',
      TipoFalta.llY => 'se escribe con ${_letraCorrecta(falta.esperado, ["ll", "y"])}',
      TipoFalta.gJ => 'se escribe con ${_letraCorrecta(falta.esperado, ["j", "g"])}',
      TipoFalta.cZ => 'se escribe con ${_letraCorrecta(falta.esperado, ["z", "c", "s"])}',
      TipoFalta.cQu =>
        'con la e y la i el sonido fuerte se escribe que, qui; con la a, la o y '
            'la u se escribe ca, co, cu',
      TipoFalta.gGu =>
        'con la e y la i hay que poner u detrás de la ge: gue, gui; y esa u no suena',
      TipoFalta.rRr => falta.esperado.toLowerCase().contains('rr')
          ? 'lleva doble erre, porque el sonido es fuerte y va entre vocales'
          : 'lleva una sola erre',
      TipoFalta.mAntesPB => 'va con eme, porque antes de pe y de be siempre se escribe eme',
      TipoFalta.dieresis =>
        'lleva diéresis, los dos puntitos sobre la u, para que la u se oiga',
      TipoFalta.xS => 'se escribe con ${_letraCorrecta(falta.esperado, ["x", "s"])}',
      TipoFalta.homofono =>
        'suena igual que otra palabra que se escribe distinta, así que hay que '
            'mirar qué quiere decir la frase',
      TipoFalta.mayuscula => 'empieza por mayúscula',
      TipoFalta.unionSeparacion => falta.esperado.contains(' ')
          ? 'van separadas, en dos palabras'
          : 'va todo junto, en una sola palabra',
      TipoFalta.ortografia => 'se escribe así, no hay regla: hay que aprendérsela',
    };

/// Cómo se le explica al niño una palabra que dice haber fallado.
String explicarPalabra(Falta falta) => '${falta.esperado}: ${razonDe(falta)}.';
