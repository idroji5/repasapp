/// Asignaturas del MVP. Añadir una más es añadir un valor aquí y su contenido.
enum Asignatura {
  dictado('Dictado'),
  matematicas('Matemáticas');

  const Asignatura(this.nombre);
  final String nombre;

  static Asignatura? porClave(String clave) {
    for (final a in Asignatura.values) {
      if (a.name == clave) return a;
    }
    return null;
  }
}

/// Niveles válidos: 1 (refuerzo) a 5 (avanzado). Independiente por asignatura.
const int nivelMinimo = 1;
const int nivelMaximo = 5;

int nivelValido(int n) => n.clamp(nivelMinimo, nivelMaximo);
