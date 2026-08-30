import 'asignaturas.dart';

/// Catálogo de microdestrezas.
///
/// El contenido NO se indexa por curso, se indexa por destreza. El curso solo
/// dice qué destrezas se dan por vistas ("¿ya le han explicado la tilde en las
/// esdrújulas?"), mientras que el nivel 1-5 dice cuánto se le exige dentro de
/// ellas. Esta separación es la que permite "9 años, 4.º de Primaria,
/// Matemáticas avanzado y Dictado de refuerzo".
class Destreza {
  const Destreza(this.id, this.nombre, this.asignatura, this.cursoIntroduccion);

  final String id;
  final String nombre;
  final Asignatura asignatura;

  /// Curso de Primaria en el que se introduce (1-6).
  final int cursoIntroduccion;
}

const List<Destreza> destrezas = [
  // ------------------------------------------------------------- dictado ---
  Destreza('mayuscula_inicial', 'Mayúscula al empezar y en nombres propios', Asignatura.dictado, 1),
  Destreza('punto_final', 'El punto final', Asignatura.dictado, 1),
  Destreza('m_antes_p_b', 'Se escribe m antes de p y b', Asignatura.dictado, 1),
  Destreza('c_qu', 'ca, co, cu / que, qui', Asignatura.dictado, 1),
  Destreza('g_gu', 'ga, go, gu / gue, gui', Asignatura.dictado, 2),
  Destreza('r_rr', 'El sonido fuerte de la r y la rr', Asignatura.dictado, 2),
  Destreza('h_frecuente', 'Palabras frecuentes con h', Asignatura.dictado, 2),
  Destreza('c_z', 'za, ce, ci, zo, zu', Asignatura.dictado, 2),
  Destreza('interrogacion_exclamacion', 'Signos de interrogación y exclamación', Asignatura.dictado, 2),
  Destreza('coma_enumeracion', 'La coma en las enumeraciones', Asignatura.dictado, 3),
  Destreza('tilde_agudas', 'Tilde en las palabras agudas', Asignatura.dictado, 3),
  Destreza('b_verbos_aba', 'Verbos terminados en -aba, -abas, -ábamos', Asignatura.dictado, 3),
  Destreza('ll_y', 'Palabras con ll y con y', Asignatura.dictado, 3),
  Destreza('tilde_llanas', 'Tilde en las palabras llanas', Asignatura.dictado, 4),
  Destreza('tilde_esdrujulas', 'Tilde en las palabras esdrújulas', Asignatura.dictado, 4),
  Destreza('g_j', 'Palabras con g y con j', Asignatura.dictado, 4),
  Destreza('v_adjetivos', 'Adjetivos terminados en -ivo, -iva, -ave', Asignatura.dictado, 4),
  Destreza('dieresis', 'La diéresis: güe, güi', Asignatura.dictado, 4),
  Destreza('tilde_diacritica', 'Tilde diacrítica: tú/tu, él/el, sí/si', Asignatura.dictado, 5),
  Destreza('hiato', 'Diptongos e hiatos', Asignatura.dictado, 5),
  Destreza('b_v_reglas', 'Reglas generales de b y v', Asignatura.dictado, 5),
  Destreza('x_s', 'Palabras con x y con s', Asignatura.dictado, 5),
  Destreza('homofonos', 'Homófonos: hay/ahí/ay, haber/a ver', Asignatura.dictado, 6),
  Destreza('tilde_interrogativos', 'Tilde en qué, cómo, cuándo, dónde', Asignatura.dictado, 6),
  Destreza('porque', 'porque, por qué, porqué, por que', Asignatura.dictado, 6),

  // --------------------------------------------------------- matemáticas ---
  Destreza('suma_2cifras', 'Sumas de dos cifras', Asignatura.matematicas, 1),
  Destreza('resta_2cifras', 'Restas de dos cifras', Asignatura.matematicas, 1),
  Destreza('suma_llevada', 'Sumas llevando', Asignatura.matematicas, 2),
  Destreza('resta_llevada', 'Restas llevando', Asignatura.matematicas, 2),
  Destreza('tablas_basicas', 'Tablas del 2, del 5 y del 10', Asignatura.matematicas, 2),
  Destreza('suma_3cifras', 'Sumas de tres cifras', Asignatura.matematicas, 3),
  Destreza('resta_3cifras', 'Restas de tres cifras', Asignatura.matematicas, 3),
  Destreza('tablas_completas', 'Todas las tablas de multiplicar', Asignatura.matematicas, 3),
  Destreza('mult_2x1', 'Multiplicar por una cifra', Asignatura.matematicas, 3),
  Destreza('div_exacta_1cifra', 'Divisiones exactas entre una cifra', Asignatura.matematicas, 3),
  Destreza('mult_3x2', 'Multiplicar por dos cifras', Asignatura.matematicas, 4),
  Destreza('div_resto_1cifra', 'Divisiones con resto entre una cifra', Asignatura.matematicas, 4),
  Destreza('div_2cifras', 'Dividir entre dos cifras', Asignatura.matematicas, 5),
  Destreza('decimales_suma_resta', 'Sumar y restar decimales', Asignatura.matematicas, 5),
];

final Map<String, Destreza> _porId = {for (final d in destrezas) d.id: d};

Destreza? destrezaPorId(String id) => _porId[id];

String nombreDestreza(String id) => _porId[id]?.nombre ?? id;

/// Destrezas que un niño de ese curso ya debería haber visto en clase.
/// Acumulativo: 4.º incluye todo lo de 1.º a 4.º.
List<Destreza> destrezasHasta(int curso, [Asignatura? asignatura]) => destrezas
    .where((d) =>
        d.cursoIntroduccion <= curso &&
        (asignatura == null || d.asignatura == asignatura))
    .toList();

/// ¿Puede plantearse este contenido a un niño de ese curso? Solo si todas las
/// destrezas que ejercita se han introducido ya. Evita dictarle tilde diacrítica
/// a un niño de 2.º por mucho que su nivel sea alto.
bool apropiadoParaCurso(List<String> ids, int curso) => ids.every((id) {
      final d = _porId[id];
      return d != null && d.cursoIntroduccion <= curso;
    });
