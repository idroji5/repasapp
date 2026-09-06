import '../contenido/matematicas.dart';

/// Qué salió bien y qué no en una tanda de ejercicios, sean cuentas, problemas
/// o frases en inglés.
///
/// Quien corrige es el niño: la app le enseña la solución de cada ejercicio en
/// pantalla y él marca si le ha salido o no. Es menos automático que leer la
/// hoja con la cámara y es mejor pedagogía —comparar su cuenta con la buena y
/// decidir si coinciden ya es corregir— además de no equivocarse nunca al leer
/// su letra, que era el fallo que más confianza costaba.
class ResultadoEjercicio {
  const ResultadoEjercicio({required this.ejercicio, required this.correcta});

  final Ejercicio ejercicio;
  final bool correcta;
}

/// Cruza la tanda con lo que el niño ha marcado como fallado.
List<ResultadoEjercicio> corregirTanda(
  List<Ejercicio> ejercicios,
  Set<int> falladas,
) =>
    [
      for (final op in ejercicios)
        ResultadoEjercicio(
          ejercicio: op,
          correcta: !falladas.contains(op.numero),
        ),
    ];
