import { dictadoPorId, type Dictado } from "../content/dictados.js";
import { generarTanda, type Operacion } from "../content/matematicas.js";
import type { Nivel } from "./asignaturas.js";

/**
 * Reconstruye lo que se le planteó al niño a partir de lo guardado en
 * `actividades.contenido`.
 *
 * Para las operaciones no se guarda la lista, se guarda la semilla: el
 * generador es determinista, así que la misma semilla devuelve exactamente la
 * misma tanda al corregir que la que se dictó.
 */

export type ContenidoActividad =
  | { tipo: "dictado"; dictado: Dictado }
  | { tipo: "tanda_operaciones"; operaciones: Operacion[] };

export function reconstruir(
  contenido: Record<string, unknown>,
  nivel: Nivel,
): ContenidoActividad {
  if (contenido.tipo === "dictado") {
    const dictado = dictadoPorId(String(contenido.dictadoId));
    if (!dictado) throw new Error(`Dictado desconocido: ${contenido.dictadoId}`);
    return { tipo: "dictado", dictado };
  }

  if (contenido.tipo === "tanda_operaciones") {
    return {
      tipo: "tanda_operaciones",
      operaciones: generarTanda(
        contenido.destrezas as string[],
        nivel,
        Number(contenido.cuantas),
        Number(contenido.semilla),
      ),
    };
  }

  throw new Error(`Tipo de actividad desconocido: ${String(contenido.tipo)}`);
}

export function tituloDe(contenido: Record<string, unknown>): string {
  if (contenido.tipo === "dictado") {
    return dictadoPorId(String(contenido.dictadoId))?.titulo ?? "Dictado";
  }
  return `${contenido.cuantas} operaciones`;
}
