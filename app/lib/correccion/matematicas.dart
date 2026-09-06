import '../contenido/matematicas.dart';

/// Qué salió bien y qué no en una tanda de matemáticas.
///
/// Quien corrige es el niño: la app le enseña la solución de cada ejercicio en
/// pantalla y él marca si le ha salido o no. Es menos automático que leer la
/// hoja con la cámara y es mejor pedagogía —comparar su cuenta con la buena y
/// decidir si coinciden ya es corregir— además de no equivocarse nunca al leer
/// su letra, que era el fallo que más confianza costaba.
class ResultadoOperacion {
  const ResultadoOperacion({required this.operacion, required this.correcta});

  final Operacion operacion;
  final bool correcta;
}

/// Cruza la tanda con lo que el niño ha marcado como fallado.
List<ResultadoOperacion> corregirTanda(
  List<Operacion> operaciones,
  Set<int> falladas,
) =>
    [
      for (final op in operaciones)
        ResultadoOperacion(
          operacion: op,
          correcta: !falladas.contains(op.numero),
        ),
    ];
