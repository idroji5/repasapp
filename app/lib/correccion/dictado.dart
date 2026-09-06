import '../contenido/dictados.dart';
import 'ortografia.dart';

/// Lo que el niño dice que le ha salido en un dictado.
///
/// Al terminar ve el texto en pantalla, escrito con letra de cuaderno, y va
/// tocando encima las palabras que ha escrito mal. Marcar sobre el texto es
/// corregir como se corrige en una hoja —se tacha lo que está mal, donde
/// está— y de paso la app sabe exactamente qué palabras son, así que puede
/// explicar la regla de cada una y apuntar la destreza para la zona de padres.
///
/// Releerse palabra por palabra es parte del ejercicio. Y si se deja alguna
/// sin marcar, tampoco pasa nada: el nivel necesita varias actividades
/// seguidas para moverse, así que una autoevaluación imperfecta no descarrila
/// nada.
class CorreccionDictado {
  const CorreccionDictado({
    required this.totalPalabras,
    required this.explicadas,
  });

  final int totalPalabras;

  /// Las palabras que ha tachado, ya con su regla deducida.
  final List<Falta> explicadas;

  int get faltas => explicadas.length;

  int get aciertos => (totalPalabras - faltas).clamp(0, totalPalabras);

  bool get perfecto => explicadas.isEmpty;
}

/// Construye la corrección a partir de las palabras que ha tachado en pantalla.
CorreccionDictado corregirDictadoMarcado(
  Dictado dictado,
  List<String> palabrasFalladas,
) {
  final explicadas = [
    for (final palabra in palabrasFalladas)
      faltaDePalabra(palabra, dictado.destrezas),
  ];

  return CorreccionDictado(
    totalPalabras: dictado.numeroDePalabras,
    explicadas: explicadas,
  );
}
