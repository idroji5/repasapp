import '../contenido/dictados.dart';
import 'ortografia.dart';

/// Lo que el niño dice que le ha salido en un dictado.
///
/// Al terminar ve el texto en pantalla, escrito con letra de cuaderno, y lo
/// compara con su hoja. Dice cuántas faltas ha tenido —eso da la nota— y, si
/// quiere, marca en cuáles de las palabras difíciles, que es lo que permite
/// explicarle la regla y anotar la destreza para la zona de padres.
///
/// Contar sus propias faltas es parte del ejercicio: obliga a releerse. Y
/// aunque se cuente alguna de más o de menos, el número solo mueve el nivel
/// despacio (hacen falta varias actividades seguidas para cambiarlo), así que
/// una autoevaluación imperfecta no descarrila nada.
class CorreccionDictado {
  const CorreccionDictado({
    required this.totalPalabras,
    required this.faltas,
    required this.explicadas,
  });

  final int totalPalabras;

  /// Cuántas faltas dice el niño que ha tenido.
  final int faltas;

  /// Las palabras que ha marcado, ya con su regla deducida. Puede estar vacía
  /// aunque haya faltas: marcar cuáles es opcional.
  final List<Falta> explicadas;

  int get aciertos => (totalPalabras - faltas).clamp(0, totalPalabras);

  bool get perfecto => faltas == 0;
}

/// Construye la corrección a partir de lo que el niño ha marcado en pantalla.
CorreccionDictado corregirDictadoMarcado(
  Dictado dictado,
  int faltas,
  List<String> palabrasFalladas,
) {
  final explicadas = [
    for (final palabra in palabrasFalladas)
      faltaDePalabra(palabra, dictado.destrezas),
  ];

  return CorreccionDictado(
    totalPalabras: dictado.numeroDePalabras,
    // Si marca más palabras de las faltas que dijo tener, mandan las palabras:
    // son la información concreta, y el número era una estimación suya.
    faltas: faltas < explicadas.length ? explicadas.length : faltas,
    explicadas: explicadas,
  );
}
