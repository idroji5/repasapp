/**
 * Comparación de lo que el niño escribió contra el texto que se le dictó.
 *
 * Esta clasificación es determinista a propósito. El modelo de visión solo
 * transcribe lo que ve en el papel; decidir si "avía" es un fallo de b/v, de h
 * o de tilde es una regla de ortografía castellana, y una regla se programa —
 * así el resultado es idéntico cada vez, se puede probar, y no cuesta dinero.
 */

export type TipoError =
  | "tilde"
  | "b_v"
  | "h"
  | "g_j"
  | "ll_y"
  | "c_z"
  | "r_rr"
  | "m_antes_p_b"
  | "mayuscula"
  | "union_separacion"
  | "puntuacion"
  | "omision"
  | "adicion"
  | "ortografia";

export interface ErrorDictado {
  /** Índice de la palabra dentro del texto de referencia. */
  posicion: number;
  esperado: string;
  escrito: string;
  tipo: TipoError;
  /** Otras reglas falladas en la misma palabra ("avía" por "había": h y b/v). */
  tambien: TipoError[];
  /** Microdestreza a la que se imputa el fallo, si se puede deducir. */
  destrezaId: string | null;
}

export interface Correccion {
  totalPalabras: number;
  aciertos: number;
  errores: ErrorDictado[];
}

// ------------------------------------------------------------ utilidades ---

export function sinTildes(s: string): string {
  return s.normalize("NFD").replace(/[\u0300-\u036f]/g, "").normalize("NFC");
}

/** Palabras, sin signos de puntuación. La puntuación se evalúa aparte. */
export function palabras(texto: string): string[] {
  return texto
    .replace(/[.,;:¿?¡!"«»()—–-]/g, " ")
    .split(/\s+/)
    .filter(Boolean);
}

function normal(s: string): string {
  return sinTildes(s.toLowerCase());
}

function levenshtein(a: string, b: string): number {
  const m = a.length;
  const n = b.length;
  if (m === 0) return n;
  if (n === 0) return m;
  let anterior = Array.from({ length: n + 1 }, (_, j) => j);
  let actual = new Array<number>(n + 1);
  for (let i = 1; i <= m; i++) {
    actual[0] = i;
    for (let j = 1; j <= n; j++) {
      const coste = a[i - 1] === b[j - 1] ? 0 : 1;
      actual[j] = Math.min(anterior[j]! + 1, actual[j - 1]! + 1, anterior[j - 1]! + coste);
    }
    [anterior, actual] = [actual, anterior];
  }
  return anterior[n]!;
}

// ----------------------------------------------------- clases de fallo ortográfico ---

/**
 * Cada regla reduce la palabra a una forma canónica en la que la distinción que
 * la regla gobierna desaparece. Si dos palabras distintas comparten canónica,
 * el fallo es exactamente de esa regla.
 */
const REGLAS: ReadonlyArray<{ tipo: TipoError; canonica: (s: string) => string }> = [
  { tipo: "h", canonica: (s) => s.replace(/h/g, "") },
  { tipo: "b_v", canonica: (s) => s.replace(/v/g, "b") },
  { tipo: "ll_y", canonica: (s) => s.replace(/ll/g, "y") },
  { tipo: "g_j", canonica: (s) => s.replace(/j/g, "g") },
  { tipo: "c_z", canonica: (s) => s.replace(/z/g, "s").replace(/c(?=[ei])/g, "s") },
  { tipo: "r_rr", canonica: (s) => s.replace(/rr/g, "r") },
  { tipo: "m_antes_p_b", canonica: (s) => s.replace(/m(?=[pb])/g, "n") },
];

const DIACRITICOS = new Set([
  "tu", "el", "mi", "si", "te", "de", "se", "mas", "aun", "solo",
  "que", "como", "cuando", "donde", "quien", "cual", "cuanto", "cuanta",
]);

const VOCALES = /[aeiouáéíóúü]/i;

/**
 * Aguda, llana o esdrújula, contando grupos vocálicos desde el final hasta el
 * que lleva la tilde. Solo tiene sentido sobre la palabra correcta (la que
 * lleva la tilde puesta), que es justo la que tenemos como referencia.
 */
export function tipoAcentual(palabra: string): "aguda" | "llana" | "esdrujula" | null {
  const p = palabra.toLowerCase();
  const grupos: { inicio: number; fin: number; conTilde: boolean }[] = [];
  let i = 0;
  while (i < p.length) {
    if (VOCALES.test(p[i]!)) {
      const inicio = i;
      let conTilde = false;
      while (i < p.length && VOCALES.test(p[i]!)) {
        if (/[áéíóú]/.test(p[i]!)) conTilde = true;
        i++;
      }
      grupos.push({ inicio, fin: i, conTilde });
    } else {
      i++;
    }
  }
  const indice = grupos.findIndex((g) => g.conTilde);
  if (indice === -1) return null;
  const desdeElFinal = grupos.length - 1 - indice;
  if (desdeElFinal === 0) return "aguda";
  if (desdeElFinal === 1) return "llana";
  return "esdrujula";
}

function destrezaDeTilde(esperado: string): string {
  if (DIACRITICOS.has(normal(esperado))) return "tilde_diacritica";
  switch (tipoAcentual(esperado)) {
    case "aguda": return "tilde_agudas";
    case "llana": return "tilde_llanas";
    case "esdrujula": return "tilde_esdrujulas";
    default: return "tilde_agudas";
  }
}

const TERMINACIONES_ABA = /(aba|abas|ábamos|abais|aban)$/;

function destrezaDeError(tipo: TipoError, esperado: string): string | null {
  switch (tipo) {
    case "tilde": return destrezaDeTilde(esperado);
    case "b_v": return TERMINACIONES_ABA.test(esperado.toLowerCase()) ? "b_verbos_aba" : "b_v_reglas";
    case "h": return "h_frecuente";
    case "g_j": return "g_j";
    case "ll_y": return "ll_y";
    case "c_z": return "c_z";
    case "r_rr": return "r_rr";
    case "m_antes_p_b": return "m_antes_p_b";
    case "mayuscula": return "mayuscula_inicial";
    case "union_separacion": return normal(esperado).startsWith("porque") ? "porque" : null;
    default: return null;
  }
}

/**
 * Qué reglas ortográficas hacen falta para explicar la diferencia.
 *
 * Un niño puede fallar dos cosas en la misma palabra: escribir "avía" por
 * "había" es a la vez una hache que falta y una be que se ha vuelto uve.
 * Se aplican todas las canónicas a la vez; si así coinciden, son necesarias
 * justo aquellas cuya retirada vuelve a separarlas.
 */
function reglasNecesarias(e: string, c: string): TipoError[] {
  const aplicar = (reglas: typeof REGLAS, s: string) =>
    reglas.reduce((x, r) => r.canonica(x), s);

  if (aplicar(REGLAS, e) !== aplicar(REGLAS, c)) return [];

  return REGLAS.filter((regla) => {
    const resto = REGLAS.filter((r) => r !== regla);
    return aplicar(resto, e) !== aplicar(resto, c);
  }).map((r) => r.tipo);
}

export interface Clasificacion {
  tipo: TipoError;
  /** Otras reglas implicadas, cuando el niño falló más de una en la palabra. */
  tambien: TipoError[];
}

export function clasificarDetallado(esperado: string, escrito: string): Clasificacion {
  const solo = (tipo: TipoError): Clasificacion => ({ tipo, tambien: [] });

  if (esperado.toLowerCase() === escrito.toLowerCase()) return solo("mayuscula");

  const e = esperado.toLowerCase();
  const c = escrito.toLowerCase();
  if (sinTildes(e) === sinTildes(c)) return solo("tilde");

  // Las reglas se prueban sobre las palabras sin tildes: cuando además falta la
  // tilde, el fallo que hay que enseñar es el de la letra.
  const necesarias = reglasNecesarias(sinTildes(e), sinTildes(c));
  if (necesarias.length > 0) {
    return { tipo: necesarias[0]!, tambien: necesarias.slice(1) };
  }
  return solo("ortografia");
}

/** Clasifica un par (esperado, escrito) que ya sabemos que no coinciden. */
export function clasificar(esperado: string, escrito: string): TipoError {
  return clasificarDetallado(esperado, escrito).tipo;
}

// ------------------------------------------------------------ alineación ---

type Op =
  | { op: "igual"; esp: string; esc: string; idx: number }
  | { op: "sust"; esp: string; esc: string; idx: number }
  | { op: "falta"; esp: string; idx: number }
  | { op: "sobra"; esc: string; idx: number };

const COSTE_HUECO = 1.0;

function costeSustitucion(a: string, b: string): number {
  const na = normal(a);
  const nb = normal(b);
  if (na === nb) return 0.05; // difieren solo en mayúsculas
  const d = levenshtein(na, nb);
  const parecido = 1 - d / Math.max(na.length, nb.length);
  // Palabras parecidas se emparejan; palabras distintas salen más baratas como
  // hueco (omisión + adición), que es lo que realmente ocurrió.
  return parecido >= 0.5 ? 0.6 : 1.6;
}

/** Needleman–Wunsch sobre palabras. */
export function alinear(referencia: readonly string[], escritas: readonly string[]): Op[] {
  const m = referencia.length;
  const n = escritas.length;
  const d: number[][] = Array.from({ length: m + 1 }, () => new Array<number>(n + 1).fill(0));

  for (let i = 1; i <= m; i++) d[i]![0] = i * COSTE_HUECO;
  for (let j = 1; j <= n; j++) d[0]![j] = j * COSTE_HUECO;

  for (let i = 1; i <= m; i++) {
    for (let j = 1; j <= n; j++) {
      d[i]![j] = Math.min(
        d[i - 1]![j - 1]! + costeSustitucion(referencia[i - 1]!, escritas[j - 1]!),
        d[i - 1]![j]! + COSTE_HUECO,
        d[i]![j - 1]! + COSTE_HUECO,
      );
    }
  }

  const ops: Op[] = [];
  let i = m;
  let j = n;
  while (i > 0 || j > 0) {
    const esp = referencia[i - 1];
    const esc = escritas[j - 1];
    const casi = (a: number, b: number) => Math.abs(a - b) < 1e-9;
    if (i > 0 && j > 0 && casi(d[i]![j]!, d[i - 1]![j - 1]! + costeSustitucion(esp!, esc!))) {
      ops.push(esp === esc ? { op: "igual", esp: esp!, esc: esc!, idx: i - 1 } : { op: "sust", esp: esp!, esc: esc!, idx: i - 1 });
      i--; j--;
    } else if (i > 0 && casi(d[i]![j]!, d[i - 1]![j]! + COSTE_HUECO)) {
      ops.push({ op: "falta", esp: esp!, idx: i - 1 });
      i--;
    } else {
      ops.push({ op: "sobra", esc: esc!, idx: i });
      j--;
    }
  }
  return ops.reverse();
}

/**
 * Junta los casos en los que el niño partió una palabra en dos o unió dos en
 * una. Sin esto, escribir "por que" en lugar de "porque" cuenta como dos
 * errores distintos en vez de como el error de separación que realmente es.
 *
 * El hueco puede quedar a cualquiera de los dos lados de la sustitución según
 * por dónde pase la alineación, así que se comprueban ambos órdenes.
 */
function fusionarSeparaciones(ops: Op[]): Op[] {
  const esPar = (o: Op | undefined): o is Extract<Op, { op: "sust" | "igual" }> =>
    o !== undefined && (o.op === "sust" || o.op === "igual");

  const salida: Op[] = [];
  for (let i = 0; i < ops.length; i++) {
    const a = ops[i]!;
    const b = ops[i + 1];
    let fusionada: Op | null = null;

    if (b) {
      // El niño partió una palabra: sobra un trozo, antes o después.
      if (esPar(a) && b.op === "sobra" && normal(a.esc + b.esc) === normal(a.esp)) {
        fusionada = { op: "sust", esp: a.esp, esc: `${a.esc} ${b.esc}`, idx: a.idx };
      } else if (a.op === "sobra" && esPar(b) && normal(a.esc + b.esc) === normal(b.esp)) {
        fusionada = { op: "sust", esp: b.esp, esc: `${a.esc} ${b.esc}`, idx: b.idx };
      }
      // El niño unió dos palabras: falta una de la referencia, antes o después.
      else if (esPar(a) && b.op === "falta" && normal(a.esp + b.esp) === normal(a.esc)) {
        fusionada = { op: "sust", esp: `${a.esp} ${b.esp}`, esc: a.esc, idx: a.idx };
      } else if (a.op === "falta" && esPar(b) && normal(a.esp + b.esp) === normal(b.esc)) {
        fusionada = { op: "sust", esp: `${a.esp} ${b.esp}`, esc: b.esc, idx: a.idx };
      }
    }

    if (fusionada) {
      salida.push(fusionada);
      i++;
    } else {
      salida.push(a);
    }
  }
  return salida;
}

const SIGNOS: ReadonlyArray<{ signo: string; destreza: string }> = [
  { signo: ",", destreza: "coma_enumeracion" },
  { signo: "¿", destreza: "interrogacion_exclamacion" },
  { signo: "?", destreza: "interrogacion_exclamacion" },
  { signo: "¡", destreza: "interrogacion_exclamacion" },
  { signo: "!", destreza: "interrogacion_exclamacion" },
];

/** Como máximo dos avisos de puntuación: si no, tapan los fallos de ortografía. */
const MAX_ERRORES_PUNTUACION = 2;

function erroresDePuntuacion(referencia: string, escrito: string): ErrorDictado[] {
  const cuenta = (t: string, s: string) => t.split(s).length - 1;
  const salida: ErrorDictado[] = [];
  for (const { signo, destreza } of SIGNOS) {
    const faltan = cuenta(referencia, signo) - cuenta(escrito, signo);
    if (faltan > 0) {
      salida.push({
        posicion: -1,
        esperado: signo,
        escrito: "",
        tipo: "puntuacion",
        tambien: [],
        destrezaId: destreza,
      });
    }
    if (salida.length >= MAX_ERRORES_PUNTUACION) break;
  }
  return salida;
}

/**
 * Corrige un dictado: compara la transcripción de lo escrito contra el texto
 * de referencia y devuelve los aciertos y la lista clasificada de errores.
 */
export function corregirDictado(referencia: string, transcripcion: string): Correccion {
  const ref = palabras(referencia);
  const esc = palabras(transcripcion);
  const ops = fusionarSeparaciones(alinear(ref, esc));

  const errores: ErrorDictado[] = [];
  let aciertos = 0;

  for (const op of ops) {
    switch (op.op) {
      case "igual":
        aciertos++;
        break;
      case "sust": {
        // Una fusión deja un espacio dentro de la palabra: eso es, por
        // definición, un fallo de unión o separación y no de ortografía.
        const separacion = op.esp.includes(" ") || op.esc.includes(" ");
        const { tipo, tambien } = separacion
          ? { tipo: "union_separacion" as TipoError, tambien: [] as TipoError[] }
          : clasificarDetallado(op.esp, op.esc);
        errores.push({
          posicion: op.idx,
          esperado: op.esp,
          escrito: op.esc,
          tipo,
          tambien,
          destrezaId: destrezaDeError(tipo, op.esp),
        });
        break;
      }
      case "falta":
        errores.push({
          posicion: op.idx,
          esperado: op.esp,
          escrito: "",
          tipo: "omision",
          tambien: [],
          destrezaId: null,
        });
        break;
      case "sobra":
        errores.push({
          posicion: op.idx,
          esperado: "",
          escrito: op.esc,
          tipo: "adicion",
          tambien: [],
          destrezaId: null,
        });
        break;
    }
  }

  errores.push(...erroresDePuntuacion(referencia, transcripcion));

  return { totalPalabras: ref.length, aciertos, errores };
}
