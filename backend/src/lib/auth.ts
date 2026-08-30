import { createHmac, randomBytes, scrypt as scryptCb, timingSafeEqual } from "node:crypto";
import { promisify } from "node:util";
import { config } from "../config.js";

const scrypt = promisify(scryptCb) as (
  secreto: string,
  sal: Buffer,
  longitud: number,
) => Promise<Buffer>;

const LONGITUD_CLAVE = 32;

/** Hash con scrypt y sal por registro. Se usa para contraseñas y para el PIN. */
export async function hashear(secreto: string): Promise<string> {
  const sal = randomBytes(16);
  const clave = await scrypt(secreto, sal, LONGITUD_CLAVE);
  return `${sal.toString("hex")}:${clave.toString("hex")}`;
}

export async function verificar(secreto: string, almacenado: string): Promise<boolean> {
  const [salHex, claveHex] = almacenado.split(":");
  if (!salHex || !claveHex) return false;
  const clave = await scrypt(secreto, Buffer.from(salHex, "hex"), LONGITUD_CLAVE);
  const esperada = Buffer.from(claveHex, "hex");
  return clave.length === esperada.length && timingSafeEqual(clave, esperada);
}

// --------------------------------------------------------------- tokens ---

function base64url(b: Buffer | string): string {
  return Buffer.from(b).toString("base64url");
}

function firma(cuerpo: string): string {
  return createHmac("sha256", config.jwtSecret).update(cuerpo).digest("base64url");
}

export interface Sesion {
  padreId: string;
  /** Marca de tiempo de expiración, en segundos. */
  exp: number;
}

const DURACION_SEGUNDOS = 60 * 60 * 24 * 90; // 90 días: es una app familiar, no un banco

export function firmarToken(padreId: string): string {
  const cabecera = base64url(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const datos: Sesion = {
    padreId,
    exp: Math.floor(Date.now() / 1000) + DURACION_SEGUNDOS,
  };
  const cuerpo = `${cabecera}.${base64url(JSON.stringify(datos))}`;
  return `${cuerpo}.${firma(cuerpo)}`;
}

export function verificarToken(token: string): Sesion | null {
  const partes = token.split(".");
  if (partes.length !== 3) return null;

  const cuerpo = `${partes[0]}.${partes[1]}`;
  const esperada = Buffer.from(firma(cuerpo));
  const recibida = Buffer.from(partes[2]!);
  if (esperada.length !== recibida.length || !timingSafeEqual(esperada, recibida)) return null;

  try {
    const datos = JSON.parse(Buffer.from(partes[1]!, "base64url").toString()) as Sesion;
    if (typeof datos.exp !== "number" || datos.exp < Date.now() / 1000) return null;
    return datos;
  } catch {
    return null;
  }
}
