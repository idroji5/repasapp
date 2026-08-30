import '../contenido/matematicas.dart';

/// Comparación de lo que el niño resolvió contra lo que debía salir.
///
/// No basta con mirar el resultado: si copió mal la operación, el resultado
/// puede ser correcto para lo que él escribió y aun así hay algo que enseñarle.
/// Copiar mal es un error distinto de calcular mal, y se informa como tal.
enum MotivoFallo { resultado, copia, sinHacer }

class ResultadoOperacion {
  const ResultadoOperacion({
    required this.operacion,
    required this.escrito,
    required this.correcta,
    this.motivo,
  });

  final Operacion operacion;
  final String escrito;
  final bool correcta;
  final MotivoFallo? motivo;
}

/// Lo que el OCR consiguió leer de un ejercicio.
class LecturaEjercicio {
  const LecturaEjercicio({
    required this.numero,
    required this.operacionEscrita,
    required this.resultadoEscrito,
  });

  final int numero;
  final String operacionEscrita;
  final String resultadoEscrito;
}

final RegExp _numero = RegExp(r'-?\d+(?:[.,]\d+)?');

/// Los números que aparecen en una respuesta, en orden: "45 resto 3" → [45, 3].
List<String> numerosDe(String texto) => _numero
    .allMatches(texto)
    .map((m) => m.group(0)!.replaceAll(',', '.'))
    // "3.0" y "3" son la misma respuesta; "3.50" y "3.5" también.
    .map((n) => num.parse(n).toString())
    .toList();

bool mismaRespuesta(String esperado, String escrito) {
  final a = numerosDe(esperado);
  final b = numerosDe(escrito);
  if (a.isEmpty || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// ¿Copió bien el enunciado? Se comparan solo los números, no los símbolos: el
/// OCR confunde con facilidad ×, x y *, y eso no es culpa del niño.
bool copiaCorrecta(String enunciado, String copiado) {
  if (copiado.trim().isEmpty) return true; // no lo pudimos leer: no se penaliza
  final a = numerosDe(enunciado);
  final b = numerosDe(copiado);
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

List<ResultadoOperacion> corregirTanda(
  List<Operacion> operaciones,
  List<LecturaEjercicio> lectura,
) {
  final porNumero = {for (final e in lectura) e.numero: e};

  return operaciones.map((operacion) {
    final leido = porNumero[operacion.numero];

    if (leido == null || leido.resultadoEscrito.trim().isEmpty) {
      return ResultadoOperacion(
        operacion: operacion,
        escrito: '',
        correcta: false,
        motivo: MotivoFallo.sinHacer,
      );
    }
    if (!copiaCorrecta(operacion.enunciado, leido.operacionEscrita)) {
      return ResultadoOperacion(
        operacion: operacion,
        escrito: leido.operacionEscrita,
        correcta: false,
        motivo: MotivoFallo.copia,
      );
    }
    final correcta = mismaRespuesta(operacion.respuesta, leido.resultadoEscrito);
    return ResultadoOperacion(
      operacion: operacion,
      escrito: leido.resultadoEscrito,
      correcta: correcta,
      motivo: correcta ? null : MotivoFallo.resultado,
    );
  }).toList();
}
