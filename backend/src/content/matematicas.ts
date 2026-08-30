import type { Nivel } from "../domain/asignaturas.js";
import { enteroALetras, numeroALetras } from "./numeros.js";

/**
 * Generador determinista de operaciones. No usa IA a propósito: las cuentas se
 * describen mejor con plantillas paramétricas que con un modelo de lenguaje —
 * salen gratis, son infinitas, y la respuesta correcta es exacta por
 * construcción en lugar de tener que fiarse de nadie.
 *
 * Dada la misma semilla y el mismo nivel, sale exactamente la misma tanda: eso
 * permite guardar solo `{destreza, semilla}` en la base de datos y reconstruir
 * el ejercicio al corregir.
 */

export interface Operacion {
  /** Posición dentro de la tanda, empezando en 1. */
  numero: number;
  destrezaId: string;
  /** Cómo se escribe en el cuaderno: "742 : 7". */
  enunciado: string;
  /** Cómo lo dice la voz: "setecientos cuarenta y dos dividido entre siete". */
  dictado: string;
  /** Respuesta correcta, ya normalizada como texto. */
  respuesta: string;
  /** Dos pistas graduales, antes de dar la solución. */
  pistas: [string, string];
  /** Explicación paso a paso, redactada para leerse en voz alta. */
  explicacion: string;
}

// ---------------------------------------------------------------- aleatorio ---

/** PRNG determinista (mulberry32): misma semilla, misma tanda. */
export function generadorAleatorio(semilla: number): () => number {
  let a = semilla >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

type Rnd = () => number;

/** Entero aleatorio en [min, max], ambos incluidos. */
function entre(rnd: Rnd, min: number, max: number): number {
  return min + Math.floor(rnd() * (max - min + 1));
}

function elegir<T>(rnd: Rnd, opciones: readonly T[]): T {
  return opciones[Math.floor(rnd() * opciones.length)]!;
}

// --------------------------------------------------------------- narración ---

/** Narra una suma en columna, indicando dónde se lleva. */
function narrarSuma(a: number, b: number): string {
  const pasos: string[] = [];
  const dA = [...String(a)].reverse().map(Number);
  const dB = [...String(b)].reverse().map(Number);
  const nombres = ["las unidades", "las decenas", "las centenas", "los millares"];
  let llevada = 0;

  for (let i = 0; i < Math.max(dA.length, dB.length); i++) {
    const x = dA[i] ?? 0;
    const y = dB[i] ?? 0;
    const suma = x + y + llevada;
    const conLlevada = llevada > 0 ? `, más ${llevada} que me llevaba,` : "";
    if (suma >= 10) {
      pasos.push(
        `En ${nombres[i] ?? "la siguiente columna"}: ${x} más ${y}${conLlevada} son ${suma}. Escribo ${suma % 10} y me llevo 1.`,
      );
      llevada = 1;
    } else {
      pasos.push(
        `En ${nombres[i] ?? "la siguiente columna"}: ${x} más ${y}${conLlevada} son ${suma}. Escribo ${suma}.`,
      );
      llevada = 0;
    }
  }
  if (llevada > 0) pasos.push("Y me queda 1 para escribir delante.");
  return pasos.join(" ");
}

/** Narra una resta en columna, indicando cuándo hay que pedir prestado. */
function narrarResta(a: number, b: number): string {
  const pasos: string[] = [];
  const dA = [...String(a)].reverse().map(Number);
  const dB = [...String(b)].reverse().map(Number);
  const nombres = ["las unidades", "las decenas", "las centenas", "los millares"];
  let debo = 0;

  for (let i = 0; i < dA.length; i++) {
    const y = (dB[i] ?? 0) + debo;
    const x = dA[i]!;
    if (x < y) {
      pasos.push(
        `En ${nombres[i] ?? "la siguiente columna"}: ${x} menos ${y} no se puede, así que le pido una a la columna de al lado: ${x + 10} menos ${y} son ${x + 10 - y}. Y me llevo una.`,
      );
      debo = 1;
    } else {
      pasos.push(
        `En ${nombres[i] ?? "la siguiente columna"}: ${x} menos ${y} son ${x - y}.`,
      );
      debo = 0;
    }
  }
  return pasos.join(" ");
}

/** Narra una división larga bajando cifra a cifra. */
function narrarDivision(dividendo: number, divisor: number): string {
  const pasos: string[] = [];
  let resto = 0;
  let empezado = false;

  for (const cifra of String(dividendo)) {
    const parcial = resto * 10 + Number(cifra);
    const cociente = Math.floor(parcial / divisor);
    const producto = cociente * divisor;

    if (!empezado && cociente === 0) {
      pasos.push(`Bajo el ${cifra}: ${parcial} entre ${divisor} no cabe, así que junto la siguiente cifra.`);
      resto = parcial;
      continue;
    }
    empezado = true;
    pasos.push(
      `${parcial} entre ${divisor} cabe a ${cociente}, porque ${cociente} por ${divisor} son ${producto}, y ${parcial} menos ${producto} da ${parcial - producto}.`,
    );
    resto = parcial - producto;
  }

  pasos.push(
    resto === 0
      ? "No sobra nada, la división es exacta."
      : `Sobran ${resto}, ese es el resto.`,
  );
  return pasos.join(" ");
}

// --------------------------------------------------------------- plantillas ---

type Plantilla = (rnd: Rnd, nivel: Nivel) => Omit<Operacion, "numero" | "destrezaId">;

/** Los rangos crecen con el nivel dentro de la misma destreza. */
function escala(nivel: Nivel, base: number): number {
  return Math.round(base * (0.6 + nivel * 0.2));
}

function suma(a: number, b: number): Omit<Operacion, "numero" | "destrezaId"> {
  return {
    enunciado: `${a} + ${b}`,
    dictado: `${enteroALetras(a)} más ${enteroALetras(b)}`,
    respuesta: String(a + b),
    pistas: [
      "Colócalos uno debajo del otro, cuidando que las unidades queden con las unidades.",
      "Empieza siempre por la columna de la derecha, y si te pasas de nueve, te llevas una.",
    ],
    explicacion: narrarSuma(a, b),
  };
}

function resta(a: number, b: number): Omit<Operacion, "numero" | "destrezaId"> {
  return {
    enunciado: `${a} - ${b}`,
    dictado: `${enteroALetras(a)} menos ${enteroALetras(b)}`,
    respuesta: String(a - b),
    pistas: [
      "Coloca el número grande arriba y el pequeño abajo, bien alineados.",
      "Si arriba tienes un número más pequeño que el de abajo, pídele una a la columna de la izquierda.",
    ],
    explicacion: narrarResta(a, b),
  };
}

function multiplicacion(a: number, b: number): Omit<Operacion, "numero" | "destrezaId"> {
  return {
    enunciado: `${a} × ${b}`,
    dictado: `${enteroALetras(a)} por ${enteroALetras(b)}`,
    respuesta: String(a * b),
    pistas: [
      "Multiplica primero por las unidades del número de abajo.",
      "Si el número de abajo tiene dos cifras, la segunda fila se escribe corrida un lugar a la izquierda.",
    ],
    explicacion:
      b < 10
        ? `${a} por ${b}. ${narrarSuma(a * b, 0).split(".")[0] ?? ""}. El resultado es ${a * b}.`
        : `Primero ${a} por ${b % 10}, que son ${a * (b % 10)}. Después ${a} por ${Math.floor(b / 10)}, que son ${a * Math.floor(b / 10)}, y lo escribo corrido un lugar. Sumando las dos filas sale ${a * b}.`,
  };
}

function division(D: number, d: number): Omit<Operacion, "numero" | "destrezaId"> {
  const cociente = Math.floor(D / d);
  const resto = D % d;
  return {
    enunciado: `${D} : ${d}`,
    dictado: `${enteroALetras(D)} dividido entre ${enteroALetras(d)}`,
    respuesta: resto === 0 ? String(cociente) : `${cociente} resto ${resto}`,
    pistas: [
      "Ve tomando cifras del dividendo por la izquierda hasta que el divisor quepa.",
      "En cada paso: cuántas veces cabe, lo multiplicas, lo restas, y bajas la siguiente cifra.",
    ],
    explicacion: narrarDivision(D, d),
  };
}

const PLANTILLAS: Record<string, Plantilla> = {
  suma_2cifras: (rnd, nivel) => {
    const a = entre(rnd, 11, escala(nivel, 60));
    const b = entre(rnd, 11, escala(nivel, 40));
    return suma(a, b);
  },
  resta_2cifras: (rnd, nivel) => {
    const a = entre(rnd, 30, escala(nivel, 70));
    const b = entre(rnd, 10, a - 1);
    return resta(a, b);
  },
  suma_llevada: (rnd, nivel) => {
    // Se fuerza que las unidades sumen 10 o más: la llevada es el objetivo.
    const uA = entre(rnd, 5, 9);
    const uB = entre(rnd, 10 - uA, 9);
    const a = entre(rnd, 1, escala(nivel, 8)) * 10 + uA;
    const b = entre(rnd, 1, escala(nivel, 6)) * 10 + uB;
    return suma(a, b);
  },
  resta_llevada: (rnd, nivel) => {
    // Unidades del minuendo menores que las del sustraendo: obliga a pedir prestado.
    const uA = entre(rnd, 0, 4);
    const uB = entre(rnd, uA + 1, 9);
    const dA = entre(rnd, 2, escala(nivel, 8));
    const dB = entre(rnd, 1, dA - 1);
    return resta(dA * 10 + uA, dB * 10 + uB);
  },
  suma_3cifras: (rnd, nivel) => suma(entre(rnd, 120, escala(nivel, 700)), entre(rnd, 110, escala(nivel, 500))),
  resta_3cifras: (rnd, nivel) => {
    const a = entre(rnd, 250, escala(nivel, 900));
    return resta(a, entre(rnd, 100, a - 1));
  },
  tablas_basicas: (rnd) => multiplicacion(elegir(rnd, [2, 5, 10]), entre(rnd, 2, 10)),
  tablas_completas: (rnd) => multiplicacion(entre(rnd, 2, 9), entre(rnd, 2, 10)),
  mult_2x1: (rnd, nivel) => multiplicacion(entre(rnd, 12, escala(nivel, 90)), entre(rnd, 3, 9)),
  mult_3x2: (rnd, nivel) => multiplicacion(entre(rnd, 110, escala(nivel, 800)), entre(rnd, 12, escala(nivel, 40))),
  div_exacta_1cifra: (rnd, nivel) => {
    const d = entre(rnd, 2, 9);
    // Se construye desde el cociente para garantizar que sea exacta.
    return division(d * entre(rnd, 11, escala(nivel, 90)), d);
  },
  div_resto_1cifra: (rnd, nivel) => {
    const d = entre(rnd, 3, 9);
    const cociente = entre(rnd, 20, escala(nivel, 130));
    return division(cociente * d + entre(rnd, 1, d - 1), d);
  },
  div_2cifras: (rnd, nivel) => {
    const d = entre(rnd, 12, 35);
    const cociente = entre(rnd, 11, escala(nivel, 60));
    return division(cociente * d + entre(rnd, 0, d - 1), d);
  },
  decimales_suma_resta: (rnd, nivel) => {
    const a = entre(rnd, 15, escala(nivel, 200)) / 10;
    const b = entre(rnd, 12, escala(nivel, 90)) / 10;
    const resultado = Math.round((a + b) * 10) / 10;
    return {
      enunciado: `${a.toString().replace(".", ",")} + ${b.toString().replace(".", ",")}`,
      dictado: `${numeroALetras(a)} más ${numeroALetras(b)}`,
      respuesta: resultado.toString().replace(".", ","),
      pistas: [
        "Coloca las comas una debajo de la otra: es lo único que importa al alinear.",
        "Después suma como siempre y baja la coma al resultado.",
      ],
      explicacion: `Alineando las comas, ${numeroALetras(a)} más ${numeroALetras(b)} son ${numeroALetras(resultado)}.`,
    };
  },
};

export const DESTREZAS_CON_PLANTILLA = Object.keys(PLANTILLAS);

export function tienePlantilla(destrezaId: string): boolean {
  return destrezaId in PLANTILLAS;
}

/**
 * Genera una tanda de operaciones. `semilla` la fija quien llama y se guarda con
 * la actividad, de modo que la corrección reconstruye exactamente lo mismo.
 */
export function generarTanda(
  destrezas: readonly string[],
  nivel: Nivel,
  cuantas: number,
  semilla: number,
): Operacion[] {
  const disponibles = destrezas.filter(tienePlantilla);
  if (disponibles.length === 0) {
    throw new Error("Ninguna de las destrezas pedidas tiene plantilla de generación");
  }

  const rnd = generadorAleatorio(semilla);
  const operaciones: Operacion[] = [];

  for (let i = 0; i < cuantas; i++) {
    // Se rota por las destrezas en vez de sortearlas: así una tanda de 5 con dos
    // destrezas sale 3 y 2, y no 5 de la misma por mala suerte.
    const destrezaId = disponibles[i % disponibles.length]!;
    operaciones.push({
      numero: i + 1,
      destrezaId,
      ...PLANTILLAS[destrezaId]!(rnd, nivel),
    });
  }
  return operaciones;
}
