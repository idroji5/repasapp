import type { Asignatura } from "./asignaturas.js";

/**
 * Catálogo de microdestrezas.
 *
 * El contenido NO se indexa por curso, se indexa por destreza. El curso solo
 * dice qué destrezas se dan por vistas ("¿ya le han explicado la tilde en las
 * esdrújulas?"), mientras que el nivel 1-5 dice cuánto se le exige dentro de
 * ellas. Esta separación es la que permite "9 años, 4.º de Primaria,
 * Matemáticas avanzado y Dictado de refuerzo".
 */
export interface Destreza {
  id: string;
  nombre: string;
  asignatura: Asignatura;
  /** Curso de Primaria en el que se introduce (1-6). */
  cursoIntroduccion: number;
}

export const DESTREZAS: readonly Destreza[] = [
  // ------------------------------------------------------------- dictado ---
  { id: "mayuscula_inicial", nombre: "Mayúscula al empezar y en nombres propios", asignatura: "dictado", cursoIntroduccion: 1 },
  { id: "punto_final", nombre: "El punto final", asignatura: "dictado", cursoIntroduccion: 1 },
  { id: "m_antes_p_b", nombre: "Se escribe m antes de p y b", asignatura: "dictado", cursoIntroduccion: 1 },
  { id: "c_qu", nombre: "ca, co, cu / que, qui", asignatura: "dictado", cursoIntroduccion: 1 },
  { id: "g_gu", nombre: "ga, go, gu / gue, gui", asignatura: "dictado", cursoIntroduccion: 2 },
  { id: "r_rr", nombre: "El sonido fuerte de la r y la rr", asignatura: "dictado", cursoIntroduccion: 2 },
  { id: "h_frecuente", nombre: "Palabras frecuentes con h", asignatura: "dictado", cursoIntroduccion: 2 },
  { id: "c_z", nombre: "za, ce, ci, zo, zu", asignatura: "dictado", cursoIntroduccion: 2 },
  { id: "interrogacion_exclamacion", nombre: "Signos de interrogación y exclamación", asignatura: "dictado", cursoIntroduccion: 2 },
  { id: "coma_enumeracion", nombre: "La coma en las enumeraciones", asignatura: "dictado", cursoIntroduccion: 3 },
  { id: "tilde_agudas", nombre: "Tilde en las palabras agudas", asignatura: "dictado", cursoIntroduccion: 3 },
  { id: "b_verbos_aba", nombre: "Verbos terminados en -aba, -abas, -ábamos", asignatura: "dictado", cursoIntroduccion: 3 },
  { id: "ll_y", nombre: "Palabras con ll y con y", asignatura: "dictado", cursoIntroduccion: 3 },
  { id: "tilde_llanas", nombre: "Tilde en las palabras llanas", asignatura: "dictado", cursoIntroduccion: 4 },
  { id: "tilde_esdrujulas", nombre: "Tilde en las palabras esdrújulas", asignatura: "dictado", cursoIntroduccion: 4 },
  { id: "g_j", nombre: "Palabras con g y con j", asignatura: "dictado", cursoIntroduccion: 4 },
  { id: "v_adjetivos", nombre: "Adjetivos terminados en -ivo, -iva, -ave", asignatura: "dictado", cursoIntroduccion: 4 },
  { id: "dieresis", nombre: "La diéresis: güe, güi", asignatura: "dictado", cursoIntroduccion: 4 },
  { id: "tilde_diacritica", nombre: "Tilde diacrítica: tú/tu, él/el, sí/si", asignatura: "dictado", cursoIntroduccion: 5 },
  { id: "hiato", nombre: "Diptongos e hiatos", asignatura: "dictado", cursoIntroduccion: 5 },
  { id: "b_v_reglas", nombre: "Reglas generales de b y v", asignatura: "dictado", cursoIntroduccion: 5 },
  { id: "x_s", nombre: "Palabras con x y con s", asignatura: "dictado", cursoIntroduccion: 5 },
  { id: "homofonos", nombre: "Homófonos: hay/ahí/ay, haber/a ver", asignatura: "dictado", cursoIntroduccion: 6 },
  { id: "tilde_interrogativos", nombre: "Tilde en qué, cómo, cuándo, dónde", asignatura: "dictado", cursoIntroduccion: 6 },
  { id: "porque", nombre: "porque, por qué, porqué, por que", asignatura: "dictado", cursoIntroduccion: 6 },

  // --------------------------------------------------------- matemáticas ---
  { id: "suma_2cifras", nombre: "Sumas de dos cifras", asignatura: "matematicas", cursoIntroduccion: 1 },
  { id: "resta_2cifras", nombre: "Restas de dos cifras", asignatura: "matematicas", cursoIntroduccion: 1 },
  { id: "suma_llevada", nombre: "Sumas llevando", asignatura: "matematicas", cursoIntroduccion: 2 },
  { id: "resta_llevada", nombre: "Restas llevando", asignatura: "matematicas", cursoIntroduccion: 2 },
  { id: "tablas_basicas", nombre: "Tablas del 2, del 5 y del 10", asignatura: "matematicas", cursoIntroduccion: 2 },
  { id: "suma_3cifras", nombre: "Sumas de tres cifras", asignatura: "matematicas", cursoIntroduccion: 3 },
  { id: "resta_3cifras", nombre: "Restas de tres cifras", asignatura: "matematicas", cursoIntroduccion: 3 },
  { id: "tablas_completas", nombre: "Todas las tablas de multiplicar", asignatura: "matematicas", cursoIntroduccion: 3 },
  { id: "mult_2x1", nombre: "Multiplicar por una cifra", asignatura: "matematicas", cursoIntroduccion: 3 },
  { id: "div_exacta_1cifra", nombre: "Divisiones exactas entre una cifra", asignatura: "matematicas", cursoIntroduccion: 3 },
  { id: "mult_3x2", nombre: "Multiplicar por dos cifras", asignatura: "matematicas", cursoIntroduccion: 4 },
  { id: "div_resto_1cifra", nombre: "Divisiones con resto entre una cifra", asignatura: "matematicas", cursoIntroduccion: 4 },
  { id: "fracciones_basicas", nombre: "Fracciones sencillas", asignatura: "matematicas", cursoIntroduccion: 4 },
  { id: "div_2cifras", nombre: "Dividir entre dos cifras", asignatura: "matematicas", cursoIntroduccion: 5 },
  { id: "decimales_suma_resta", nombre: "Sumar y restar decimales", asignatura: "matematicas", cursoIntroduccion: 5 },
  { id: "mult_decimales", nombre: "Multiplicar decimales", asignatura: "matematicas", cursoIntroduccion: 5 },
  { id: "porcentajes", nombre: "Porcentajes", asignatura: "matematicas", cursoIntroduccion: 6 },
  { id: "potencias", nombre: "Potencias", asignatura: "matematicas", cursoIntroduccion: 6 },
  { id: "div_decimales", nombre: "Dividir con decimales", asignatura: "matematicas", cursoIntroduccion: 6 },
];

const POR_ID = new Map(DESTREZAS.map((d) => [d.id, d]));

export function destreza(id: string): Destreza | undefined {
  return POR_ID.get(id);
}

export function nombreDestreza(id: string): string {
  return POR_ID.get(id)?.nombre ?? id;
}

/**
 * Destrezas que un niño de ese curso ya debería haber visto en clase.
 * Acumulativo: 4.º incluye todo lo de 1.º a 4.º.
 */
export function destrezasHasta(curso: number, asignatura?: Asignatura): Destreza[] {
  return DESTREZAS.filter(
    (d) => d.cursoIntroduccion <= curso && (asignatura === undefined || d.asignatura === asignatura),
  );
}

/**
 * ¿Puede plantearse este contenido a un niño de ese curso? Solo si todas las
 * destrezas que ejercita se han introducido ya. Evita dictarle tilde diacrítica
 * a un niño de 2.º por mucho que su nivel sea alto.
 */
export function apropiadoParaCurso(destrezas: readonly string[], curso: number): boolean {
  return destrezas.every((id) => {
    const d = POR_ID.get(id);
    return d !== undefined && d.cursoIntroduccion <= curso;
  });
}
