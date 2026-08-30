import type { ErrorDictado, TipoError } from "../correccion/alinear.js";
import { ordinalFemenino } from "../content/numeros.js";

/**
 * Todo lo que dice la voz, en un solo sitio.
 *
 * Está centralizado por dos razones: la personalidad de la voz se mantiene
 * coherente en toda la app, y el script de pregeneración puede recorrer estas
 * plantillas y dejar el audio hecho antes de que ningún niño abra la aplicación.
 */

export const frases = {
  saludo: (nombre: string) => `Hola, ${nombre}. ¿Empezamos?`,

  planDelDia: (minutos: number, actividades: string[]) =>
    `Hoy tenemos ${minutos} minutos: ${enumerar(actividades)}.`,

  // ------------------------------------------------------------ dictado ---
  dictadoIntro: (titulo: string) => `Vamos a hacer un dictado. Se titula ${titulo}.`,
  prepararPapel: () => "Prepara papel y lápiz. Cuando estés preparado, di: listo.",
  empezamos: () => "Muy bien. Empezamos.",
  dictadoFin: () =>
    "Ya está. Repasa lo que has escrito y, cuando quieras, hazme una foto de la hoja.",

  // -------------------------------------------------------- matemáticas ---
  matematicasIntro: (cuantas: number) =>
    `Vamos a hacer ${cuantas} operaciones. Escríbelas en el cuaderno y resuélvelas.`,
  operacion: (numero: number, dictado: string) =>
    `${capitalizar(ordinalFemenino(numero))}: ${dictado}.`,
  matematicasFin: (cuantas: number) =>
    `Esas son las ${cuantas}. Cuando termines, hazme una foto de la hoja.`,

  // --------------------------------------------------------------- foto ---
  instruccionFoto: () =>
    "Coloca la hoja plana, con buena luz, y procura que se vea entera.",
  procesando: () => "Déjame mirarlo un momento.",

  // ---------------------------------------------------------- resultado ---
  todoBien: () => "¡Perfecto! No has tenido ni un fallo. Muy bien hecho.",
  casiTodoBien: (fallos: number) =>
    `Muy bien, casi todo correcto. Solo ${fallos === 1 ? "un fallo" : `${fallos} fallos`}.`,
  resumenFallos: (fallos: number, palabras: string[]) =>
    `Has tenido ${fallos === 1 ? "un fallo" : `${fallos} fallos`}. Vamos a repasar ${enumerar(palabras)}.`,
  animo: () => "No pasa nada, para eso repasamos. Mañana seguimos.",

  // ------------------------------------------------------------- pistas ---
  fallasteEn: (numero: number) => `En la ${ordinalFemenino(numero)} te has equivocado.`,
  loTienes: () => "¿Ya lo ves, o te doy otra pista?",
  solucion: (respuesta: string) => `La respuesta correcta es ${respuesta}.`,
} as const;

function capitalizar(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

function enumerar(elementos: readonly string[]): string {
  if (elementos.length === 0) return "";
  if (elementos.length === 1) return elementos[0]!;
  return `${elementos.slice(0, -1).join(", ")} y ${elementos.at(-1)}`;
}

// ------------------------------------------- explicación de cada falta ---

const NOMBRE_LETRA: Record<string, string> = {
  b: "be", v: "uve", h: "hache", g: "ge", j: "jota",
  c: "ce", z: "zeta", s: "ese", y: "i griega", ll: "elle",
  r: "erre", rr: "doble erre", m: "eme", n: "ene",
};

/** Qué letra de las dos usa realmente la palabra correcta. */
function letraCorrecta(esperado: string, opciones: readonly string[]): string {
  const e = esperado.toLowerCase();
  const encontrada = opciones.find((letra) => e.includes(letra));
  return NOMBRE_LETRA[encontrada ?? opciones[0]!] ?? "";
}

const EXPLICACION_TILDE: Record<string, string> = {
  tilde_agudas: "lleva tilde porque es aguda y termina en ene, en ese o en vocal",
  tilde_llanas: "lleva tilde porque es llana y no termina en ene, ni en ese, ni en vocal",
  tilde_esdrujulas: "lleva tilde porque es esdrújula, y todas las esdrújulas la llevan",
  tilde_diacritica:
    "lleva tilde para distinguirla de la otra palabra que se escribe igual pero significa otra cosa",
};

/** Redacta, para leer en voz alta, por qué una palabra se escribe así. */
export function explicarFalta(error: ErrorDictado): string {
  const explicaciones: string[] = [];
  const todos: TipoError[] = [error.tipo, ...error.tambien];

  for (const tipo of todos) {
    switch (tipo) {
      case "tilde":
        explicaciones.push(
          EXPLICACION_TILDE[error.destrezaId ?? ""] ?? "lleva tilde",
        );
        break;
      case "h":
        explicaciones.push("lleva hache, aunque no se oiga al pronunciarla");
        break;
      case "b_v":
        explicaciones.push(
          error.destrezaId === "b_verbos_aba"
            ? "se escribe con be, porque los verbos terminados en -aba se escriben siempre con be"
            : `se escribe con ${letraCorrecta(error.esperado, ["b", "v"])}`,
        );
        break;
      case "ll_y":
        explicaciones.push(`se escribe con ${letraCorrecta(error.esperado, ["ll", "y"])}`);
        break;
      case "g_j":
        explicaciones.push(`se escribe con ${letraCorrecta(error.esperado, ["j", "g"])}`);
        break;
      case "c_z":
        explicaciones.push(`se escribe con ${letraCorrecta(error.esperado, ["z", "c", "s"])}`);
        break;
      case "r_rr":
        explicaciones.push(
          error.esperado.toLowerCase().includes("rr")
            ? "lleva doble erre, porque el sonido es fuerte y va entre vocales"
            : "lleva una sola erre",
        );
        break;
      case "m_antes_p_b":
        explicaciones.push("va con eme, porque antes de pe y de be siempre se escribe eme");
        break;
      case "mayuscula":
        explicaciones.push("empieza por mayúscula");
        break;
      case "union_separacion":
        explicaciones.push(
          error.esperado.includes(" ")
            ? "van separadas, en dos palabras"
            : "va todo junto, en una sola palabra",
        );
        break;
      case "omision":
        return `Te has dejado la palabra ${error.esperado}.`;
      case "adicion":
        return `Has escrito ${error.escrito} de más.`;
      case "puntuacion":
        return `Se te ha olvidado ${signoEnPalabras(error.esperado)}.`;
      default:
        break;
    }
  }

  if (explicaciones.length === 0) {
    return `Escribiste ${error.escrito}. Se escribe ${error.esperado}.`;
  }
  return `Escribiste ${error.escrito}. Se escribe ${error.esperado}: ${enumerar(explicaciones)}.`;
}

function signoEnPalabras(signo: string): string {
  switch (signo) {
    case ",": return "alguna coma";
    case "¿": return "abrir la interrogación";
    case "?": return "cerrar la interrogación";
    case "¡": return "abrir la exclamación";
    case "!": return "cerrar la exclamación";
    default: return "algún signo de puntuación";
  }
}
