import '../contenido/numeros.dart';
import '../correccion/alinear.dart';

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
  static const String empezamos = 'Muy bien. Empezamos.';
  static const String dictadoFin =
      'Ya está. Repasa lo que has escrito y, cuando quieras, hazme una foto de la hoja.';

  // -------------------------------------------------------- matemáticas ---
  static String matematicasIntro(int cuantas) =>
      'Vamos a hacer $cuantas operaciones. Escríbelas en el cuaderno.';
  static String operacion(int numero, String dictado) =>
      '${_capitalizar(ordinalFemenino(numero))}: $dictado.';
  static String matematicasFin(int cuantas) =>
      'Esas son las $cuantas. Resuélvelas con calma y, cuando termines, hazme una foto.';

  // --------------------------------------------------------------- foto ---
  static const String instruccionFoto =
      'Coloca la hoja plana, con buena luz, y procura que se vea entera.';
  static const String procesando = 'Déjame mirarlo un momento.';

  // ---------------------------------------------------------- resultado ---
  static const String todoBien = '¡Perfecto! No has tenido ni un fallo. Muy bien hecho.';
  static String casiTodoBien(int fallos) =>
      'Muy bien, casi todo correcto. Solo ${fallos == 1 ? "un fallo" : "$fallos fallos"}.';
  static String resumenFallos(int fallos, List<String> palabras) =>
      'Has tenido ${fallos == 1 ? "un fallo" : "$fallos fallos"}. '
      'Vamos a repasar ${enumerar(palabras)}.';
  static const String animo = 'No pasa nada, para eso repasamos. Mañana seguimos.';

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
  'r': 'erre', 'rr': 'doble erre', 'm': 'eme', 'n': 'ene',
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
};

/// Redacta, para leer en voz alta, por qué una palabra se escribe así.
String explicarFalta(Falta falta) {
  final explicaciones = <String>[];

  for (final tipo in [falta.tipo, ...falta.tambien]) {
    switch (tipo) {
      case TipoFalta.tilde:
        explicaciones.add(_explicacionTilde[falta.destrezaId ?? ''] ?? 'lleva tilde');
      case TipoFalta.h:
        explicaciones.add('lleva hache, aunque no se oiga al pronunciarla');
      case TipoFalta.bV:
        explicaciones.add(falta.destrezaId == 'b_verbos_aba'
            ? 'se escribe con be, porque los verbos terminados en -aba se escriben siempre con be'
            : 'se escribe con ${_letraCorrecta(falta.esperado, ["b", "v"])}');
      case TipoFalta.llY:
        explicaciones.add('se escribe con ${_letraCorrecta(falta.esperado, ["ll", "y"])}');
      case TipoFalta.gJ:
        explicaciones.add('se escribe con ${_letraCorrecta(falta.esperado, ["j", "g"])}');
      case TipoFalta.cZ:
        explicaciones.add('se escribe con ${_letraCorrecta(falta.esperado, ["z", "c", "s"])}');
      case TipoFalta.rRr:
        explicaciones.add(falta.esperado.toLowerCase().contains('rr')
            ? 'lleva doble erre, porque el sonido es fuerte y va entre vocales'
            : 'lleva una sola erre');
      case TipoFalta.mAntesPB:
        explicaciones.add('va con eme, porque antes de pe y de be siempre se escribe eme');
      case TipoFalta.mayuscula:
        explicaciones.add('empieza por mayúscula');
      case TipoFalta.unionSeparacion:
        explicaciones.add(falta.esperado.contains(' ')
            ? 'van separadas, en dos palabras'
            : 'va todo junto, en una sola palabra');
      case TipoFalta.omision:
        return 'Te has dejado la palabra ${falta.esperado}.';
      case TipoFalta.adicion:
        return 'Has escrito ${falta.escrito} de más.';
      case TipoFalta.puntuacion:
        return 'Se te ha olvidado ${_signoEnPalabras(falta.esperado)}.';
      case TipoFalta.ortografia:
        break;
    }
  }

  if (explicaciones.isEmpty) {
    return 'Escribiste ${falta.escrito}. Se escribe ${falta.esperado}.';
  }
  return 'Escribiste ${falta.escrito}. Se escribe ${falta.esperado}: '
      '${enumerar(explicaciones)}.';
}

String _signoEnPalabras(String signo) => switch (signo) {
      ',' => 'alguna coma',
      '¿' => 'abrir la interrogación',
      '?' => 'cerrar la interrogación',
      '¡' => 'abrir la exclamación',
      '!' => 'cerrar la exclamación',
      _ => 'algún signo de puntuación',
    };
