/**
 * Números a letras en castellano, para que la voz diga "setecientos cuarenta y
 * dos" en lugar de "siete cuatro dos". Cubre 0 – 999.999.999 y decimales.
 */

const UNIDADES = [
  "cero", "uno", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve",
  "diez", "once", "doce", "trece", "catorce", "quince", "dieciséis", "diecisiete",
  "dieciocho", "diecinueve", "veinte", "veintiuno", "veintidós", "veintitrés",
  "veinticuatro", "veinticinco", "veintiséis", "veintisiete", "veintiocho", "veintinueve",
];

const DECENAS = [
  "", "", "veinte", "treinta", "cuarenta", "cincuenta",
  "sesenta", "setenta", "ochenta", "noventa",
];

const CENTENAS = [
  "", "ciento", "doscientos", "trescientos", "cuatrocientos", "quinientos",
  "seiscientos", "setecientos", "ochocientos", "novecientos",
];

/** "uno" se apocopa a "un" delante de un sustantivo: veintiún mil, treinta y un millones. */
function apocopar(texto: string): string {
  if (texto === "uno") return "un";
  if (texto.endsWith("veintiuno")) return `${texto.slice(0, -"veintiuno".length)}veintiún`;
  if (texto.endsWith(" y uno")) return `${texto.slice(0, -" y uno".length)} y un`;
  return texto;
}

function menorDeCien(n: number): string {
  if (n < 30) return UNIDADES[n]!;
  const d = Math.floor(n / 10);
  const u = n % 10;
  return u === 0 ? DECENAS[d]! : `${DECENAS[d]} y ${UNIDADES[u]}`;
}

function menorDeMil(n: number): string {
  if (n === 100) return "cien";
  if (n < 100) return menorDeCien(n);
  const c = Math.floor(n / 100);
  const r = n % 100;
  return r === 0 ? CENTENAS[c]! : `${CENTENAS[c]} ${menorDeCien(r)}`;
}

function menorDeMillon(n: number): string {
  if (n < 1000) return menorDeMil(n);
  const miles = Math.floor(n / 1000);
  const r = n % 1000;
  const cabeza = miles === 1 ? "mil" : `${apocopar(menorDeMil(miles))} mil`;
  return r === 0 ? cabeza : `${cabeza} ${menorDeMil(r)}`;
}

/** Convierte un entero no negativo a su lectura en castellano. */
export function enteroALetras(n: number): string {
  if (!Number.isInteger(n) || n < 0) {
    throw new RangeError(`enteroALetras espera un entero no negativo, recibió ${n}`);
  }
  if (n < 1_000_000) return menorDeMillon(n);

  const millones = Math.floor(n / 1_000_000);
  const r = n % 1_000_000;
  const cabeza =
    millones === 1 ? "un millón" : `${apocopar(menorDeMillon(millones))} millones`;
  return r === 0 ? cabeza : `${cabeza} ${menorDeMillon(r)}`;
}

/**
 * Convierte un número a su lectura, incluidos negativos y decimales.
 * La parte decimal se lee como número si tiene una o dos cifras
 * ("dos coma veinticinco") y cifra a cifra si tiene más.
 */
export function numeroALetras(n: number): string {
  const signo = n < 0 ? "menos " : "";
  const abs = Math.abs(n);
  const entera = Math.trunc(abs);

  if (Number.isInteger(abs)) return signo + enteroALetras(entera);

  const decimalesTexto = abs.toString().split(".")[1] ?? "";
  const lectura =
    decimalesTexto.length <= 2
      ? enteroALetras(Number(decimalesTexto))
      : decimalesTexto.split("").map((d) => UNIDADES[Number(d)]).join(" ");

  return `${signo}${enteroALetras(entera)} coma ${lectura}`;
}

/** Ordinales que usa la voz al enumerar ejercicios: "Primera:", "Segunda:"… */
const ORDINALES_FEMENINOS = [
  "primera", "segunda", "tercera", "cuarta", "quinta",
  "sexta", "séptima", "octava", "novena", "décima",
];

export function ordinalFemenino(n: number): string {
  return ORDINALES_FEMENINOS[n - 1] ?? `número ${enteroALetras(n)}`;
}
