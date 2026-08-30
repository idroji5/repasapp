import '../contenido/matematicas.dart';
import 'matematicas.dart';
import 'ocr.dart';

/// Qué significa lo que el OCR ha leído.
///
/// Todo lo de este fichero es función pura sobre [LineaOcr]: no toca la cámara
/// ni ML Kit, así que se puede probar con las disposiciones reales que aparecen
/// en un cuaderno (operación en línea, resultado debajo, cuenta en columna…).

// ------------------------------------------------------------- dictado ---

/// Une las líneas leídas en un solo texto, de arriba abajo y de izquierda a
/// derecha. Es todo lo que hace falta para un dictado: el alineador de
/// ortografía se encarga del resto.
String transcripcionDeLineas(List<LineaOcr> lineas) {
  final ordenadas = [...lineas]..sort((a, b) {
      // Dos líneas están "a la misma altura" si se solapan verticalmente.
      final solapan = a.y < b.abajo && b.y < a.abajo;
      return solapan ? a.x.compareTo(b.x) : a.y.compareTo(b.y);
    });
  return ordenadas.map((l) => l.texto.trim()).where((t) => t.isNotEmpty).join(' ');
}

// --------------------------------------------------------- matemáticas ---

/// Un grupo de líneas que forman un mismo ejercicio en la hoja.
///
/// Hace falta agrupar porque una cuenta en columna ocupa tres o cuatro líneas
/// distintas para el OCR:
///
///     47
///   + 25
///   ----
///     72
class BloqueOcr {
  BloqueOcr(this.lineas);
  final List<LineaOcr> lineas;

  String get texto => lineas.map((l) => l.texto).join(' ');
  double get y => lineas.first.y;

  List<String> get numeros => numerosDe(texto);
}

/// Separación vertical máxima, en alturas de línea, para seguir en el mismo
/// bloque. Por encima de esto ya es otro ejercicio.
const double _huecoMaximo = 1.6;

List<BloqueOcr> agruparEnBloques(List<LineaOcr> lineas) {
  if (lineas.isEmpty) return [];

  final ordenadas = [...lineas]..sort((a, b) => a.y.compareTo(b.y));
  final bloques = <BloqueOcr>[];
  var actual = <LineaOcr>[ordenadas.first];

  for (final linea in ordenadas.skip(1)) {
    final anterior = actual.last;
    final hueco = linea.y - anterior.abajo;
    // Además de estar cerca en vertical, tienen que compartir columna: dos
    // ejercicios en paralelo a izquierda y derecha no son el mismo bloque.
    final solapanEnX = linea.x < anterior.derecha && anterior.x < linea.derecha;

    if (hueco <= anterior.alto * _huecoMaximo && solapanEnX) {
      actual.add(linea);
    } else {
      bloques.add(BloqueOcr(actual));
      actual = [linea];
    }
  }
  bloques.add(BloqueOcr(actual));
  return bloques;
}

/// Quita del conjunto una aparición de cada número dado.
List<String> _quitarUnaVez(List<String> numeros, List<String> aQuitar) {
  final resto = [...numeros];
  for (final n in aQuitar) {
    resto.remove(n);
  }
  return resto;
}

/// Cuántos de los operandos aparecen en el bloque. Es la puntuación con la que
/// se decide qué bloque de la hoja corresponde a qué operación dictada.
int _coincidencias(BloqueOcr bloque, List<String> operandos) {
  final disponibles = [...bloque.numeros];
  var puntos = 0;
  for (final operando in operandos) {
    if (disponibles.remove(operando)) puntos++;
  }
  return puntos;
}

/// Empareja lo escrito en la hoja con las operaciones que se dictaron.
///
/// La estrategia es la que hace viable el OCR local: no se intenta entender la
/// hoja en abstracto, se busca cada operación conocida. Sabiendo que en algún
/// sitio tiene que poner "742" y "7", encontrar ese bloque es fácil; y lo que
/// sobra en él es, por eliminación, el resultado al que llegó el niño.
List<LecturaEjercicio> interpretarTanda(
  List<LineaOcr> lineas,
  List<Operacion> operaciones,
) {
  final bloques = agruparEnBloques(lineas);
  final usados = <BloqueOcr>{};
  final lecturas = <LecturaEjercicio>[];

  for (final operacion in operaciones) {
    final operandos = numerosDe(operacion.enunciado);
    final cifrasEsperadas = numerosDe(operacion.respuesta).length;

    BloqueOcr? mejor;
    var mejorPuntos = 0;

    for (final bloque in bloques) {
      if (usados.contains(bloque)) continue;
      final puntos = _coincidencias(bloque, operandos);
      if (puntos > mejorPuntos) {
        mejor = bloque;
        mejorPuntos = puntos;
      }
    }

    // Con un solo operando reconocido no hay seguridad de haber encontrado el
    // ejercicio correcto; es preferible decir "no lo he visto" a inventárselo.
    if (mejor == null || mejorPuntos < operandos.length) {
      lecturas.add(LecturaEjercicio(
        numero: operacion.numero,
        operacionEscrita: '',
        resultadoEscrito: '',
      ));
      continue;
    }

    usados.add(mejor);

    var sobrantes = _quitarUnaVez(mejor.numeros, operandos);
    // Si el niño numeró los ejercicios, ese número no es un resultado.
    if (sobrantes.isNotEmpty && sobrantes.first == '${operacion.numero}') {
      sobrantes = sobrantes.sublist(1);
    }

    // El resultado es lo último que queda escrito: en una cuenta en columna va
    // debajo, y en una operación en línea va después del igual.
    final resultado = sobrantes.length >= cifrasEsperadas
        ? sobrantes.sublist(sobrantes.length - cifrasEsperadas)
        : sobrantes;

    lecturas.add(LecturaEjercicio(
      numero: operacion.numero,
      operacionEscrita: operacion.enunciado, // los operandos se han confirmado
      resultadoEscrito: resultado.join(' '),
    ));
  }

  return lecturas;
}
