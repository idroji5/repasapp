import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Una línea reconocida en la foto, con dónde está.
///
/// Es el único contrato entre el reconocimiento y la interpretación. Al no
/// depender de ML Kit, toda la lógica de "qué significa lo que se ha leído" se
/// puede probar con líneas inventadas, que es justo lo que hace falta: el
/// reconocimiento de caligrafía infantil falla, y hay que saber exactamente
/// cómo se comporta la app cuando falla.
class LineaOcr {
  const LineaOcr({
    required this.texto,
    required this.x,
    required this.y,
    required this.ancho,
    required this.alto,
  });

  final String texto;

  /// Esquina superior izquierda del rectángulo que la envuelve.
  final double x;
  final double y;
  final double ancho;
  final double alto;

  double get derecha => x + ancho;
  double get abajo => y + alto;

  @override
  String toString() => 'LineaOcr("$texto" @ $x,$y)';
}

/// Fuente de líneas reconocidas. Se abstrae para poder sustituirla en pruebas.
abstract class MotorOcr {
  Future<List<LineaOcr>> leer(String rutaImagen);
  Future<void> cerrar();
}

/// Reconocimiento en el propio dispositivo, sin red y sin coste.
///
/// Aviso honesto sobre sus límites: ML Kit está entrenado con texto impreso.
/// Con números y letra de imprenta va razonablemente bien; con letra ligada de
/// un niño de nueve años falla a menudo. Por eso la pantalla de resultado deja
/// siempre corregir lo que se ha leído antes de dar nada por bueno.
class OcrMlKit implements MotorOcr {
  OcrMlKit() : _reconocedor = TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _reconocedor;

  @override
  Future<List<LineaOcr>> leer(String rutaImagen) async {
    final texto = await _reconocedor.processImage(InputImage.fromFilePath(rutaImagen));

    return [
      for (final bloque in texto.blocks)
        for (final linea in bloque.lines)
          LineaOcr(
            texto: linea.text,
            x: linea.boundingBox.left.toDouble(),
            y: linea.boundingBox.top.toDouble(),
            ancho: linea.boundingBox.width.toDouble(),
            alto: linea.boundingBox.height.toDouble(),
          ),
    ];
  }

  @override
  Future<void> cerrar() => _reconocedor.close();
}
