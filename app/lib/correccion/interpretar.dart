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

/// Separación vertical máxima, en alturas de línea, para que dos renglones
/// puedan pertenecer al mismo ejercicio.
const double _huecoMaximo = 1.6;

/// Quita del conjunto una aparición de cada número dado.
List<String> _quitarUnaVez(List<String> numeros, List<String> aQuitar) {
  final resto = [...numeros];
  for (final n in aQuitar) {
    resto.remove(n);
  }
  return resto;
}

/// ¿Se parecen lo bastante como para ser el mismo número mal leído?
///
/// El OCR confunde dígitos concretos con mucha regularidad —en las pruebas,
/// leyó 416 como 446 y 11651 como 11654, siempre el 1 por el 4—. Exigir una
/// coincidencia exacta para localizar el ejercicio hace que un solo dígito mal
/// leído convierta un ejercicio hecho en un "sin hacer".
///
/// Se admite un dígito de diferencia, y solo en números de dos cifras o más:
/// con esa longitud, que además coincidan TODOS los operandos hace muy
/// improbable emparejar el ejercicio equivocado.
bool _seParecen(String a, String b) {
  if (a.length != b.length || a.length < 2) return false;
  var distintos = 0;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) distintos++;
  }
  return distintos == 1;
}

/// Localiza los operandos entre los números leídos, tolerando un dígito mal.
/// Devuelve los números TAL Y COMO SE LEYERON, para poder descontarlos luego,
/// o null si falta alguno.
List<String>? _emparejarOperandos(List<String> numeros, List<String> operandos) {
  final disponibles = [...numeros];
  final encontrados = <String>[];
  final pendientes = <String>[];

  // Primero los exactos: si no, una coincidencia aproximada podría quedarse con
  // el número que le tocaba a otro operando.
  for (final o in operandos) {
    if (disponibles.remove(o)) {
      encontrados.add(o);
    } else {
      pendientes.add(o);
    }
  }
  for (final o in pendientes) {
    final i = disponibles.indexWhere((n) => _seParecen(n, o));
    if (i < 0) return null;
    encontrados.add(disponibles.removeAt(i));
  }
  return encontrados;
}

/// ¿Esta línea es el comienzo de OTRO ejercicio?
///
/// Es la pregunta que hace falta para no tragarse el ejercicio siguiente. Y se
/// puede responder con certeza: si una línea trae los dos operandos de otra de
/// las operaciones dictadas, esa línea es de esa otra operación, por muy pegada
/// que esté a la anterior.
bool _iniciaOtroEjercicio(
  LineaOcr linea,
  List<Operacion> operaciones,
  Operacion actual,
) {
  final numeros = numerosDe(linea.texto);
  return operaciones.any((o) =>
      o.numero != actual.numero &&
      _emparejarOperandos(numeros, numerosDe(o.enunciado)) != null);
}

/// Empareja lo escrito en la hoja con las operaciones que se dictaron.
///
/// La estrategia es la que hace viable el OCR local: no se intenta entender la
/// hoja en abstracto, se busca cada operación conocida. Sabiendo que en algún
/// sitio tiene que poner "742" y "7", encontrar esos renglones es fácil; y lo
/// que sobra en ellos es, por eliminación, el resultado al que llegó el niño.
///
/// Se busca la ventana de renglones consecutivos MÁS PEQUEÑA que contenga los
/// operandos, y luego se extiende hacia abajo mientras lo de abajo siga siendo
/// del mismo ejercicio: una cuenta en columna deja el resultado debajo. Buscar
/// ventanas mínimas en vez de agrupar la hoja de antemano es lo que evita que
/// un ejercicio se trague a los siguientes cuando los renglones van juntos.
List<LecturaEjercicio> interpretarTanda(
  List<LineaOcr> lineas,
  List<Operacion> operaciones,
) {
  final ordenadas = [...lineas]..sort((a, b) => a.y.compareTo(b.y));
  final usadas = List<bool>.filled(ordenadas.length, false);
  final lecturas = <LecturaEjercicio>[];

  LecturaEjercicio sinLeer(Operacion o) =>
      LecturaEjercicio(numero: o.numero, operacionEscrita: '', resultadoEscrito: '');

  for (final operacion in operaciones) {
    final operandos = numerosDe(operacion.enunciado);
    final cifrasEsperadas = numerosDe(operacion.respuesta).length;

    // Ventana mínima de renglones libres que contenga todos los operandos.
    int? desde;
    int? hasta;
    List<String>? leidosComoOperandos;
    for (var i = 0; i < ordenadas.length; i++) {
      if (usadas[i]) continue;
      final numeros = <String>[];
      for (var j = i; j < ordenadas.length && !usadas[j]; j++) {
        if (j > i && _iniciaOtroEjercicio(ordenadas[j], operaciones, operacion)) break;
        numeros.addAll(numerosDe(ordenadas[j].texto));
        final emparejados = _emparejarOperandos(numeros, operandos);
        if (emparejados != null) {
          if (desde == null || (j - i) < (hasta! - desde)) {
            desde = i;
            hasta = j;
            leidosComoOperandos = emparejados;
          }
          break; // la ventana mínima que empieza en i ya está
        }
      }
    }

    // Sin los dos operandos no hay seguridad de haber encontrado el ejercicio;
    // es preferible decir "no lo he visto" a puntuar el ejercicio equivocado.
    if (desde == null) {
      lecturas.add(sinLeer(operacion));
      continue;
    }

    // ¿Hace falta mirar debajo? Solo si en la ventana no ha quedado ningún
    // número suelto que pueda ser el resultado. Una operación en línea ya lo
    // trae ("299 x 39 = 11651"); una cuenta en columna lo deja en el renglón de
    // abajo. Bajar cuando ya tenemos el resultado es lo que hacía que un
    // ejercicio se tragara el siguiente.
    final numerosVentana = <String>[];
    for (var k = desde; k <= hasta!; k++) {
      numerosVentana.addAll(numerosDe(ordenadas[k].texto));
    }
    var sueltos = _quitarUnaVez(numerosVentana, leidosComoOperandos!);
    if (sueltos.isNotEmpty && sueltos.first == '${operacion.numero}') {
      sueltos = sueltos.sublist(1);
    }

    var fin = hasta;
    while (sueltos.isEmpty &&
        fin + 1 < ordenadas.length &&
        !usadas[fin + 1] &&
        ordenadas[fin + 1].y - ordenadas[fin].abajo <= ordenadas[fin].alto * _huecoMaximo &&
        !_iniciaOtroEjercicio(ordenadas[fin + 1], operaciones, operacion)) {
      fin++;
    }

    final numeros = <String>[];
    for (var k = desde; k <= fin; k++) {
      numeros.addAll(numerosDe(ordenadas[k].texto));
      usadas[k] = true;
    }

    var sobrantes = _quitarUnaVez(numeros, leidosComoOperandos);
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
