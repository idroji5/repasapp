export const ASIGNATURAS = ["dictado", "matematicas"] as const;
export type Asignatura = (typeof ASIGNATURAS)[number];

export const NOMBRE_ASIGNATURA: Record<Asignatura, string> = {
  dictado: "Dictado",
  matematicas: "Matemáticas",
};

export function esAsignatura(v: string): v is Asignatura {
  return (ASIGNATURAS as readonly string[]).includes(v);
}

/** Niveles válidos, 1 (refuerzo) a 5 (avanzado). Independiente por asignatura. */
export const NIVEL_MIN = 1;
export const NIVEL_MAX = 5;
export type Nivel = 1 | 2 | 3 | 4 | 5;

export function esNivel(n: number): n is Nivel {
  return Number.isInteger(n) && n >= NIVEL_MIN && n <= NIVEL_MAX;
}
