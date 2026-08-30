import type { Operacion } from "../content/matematicas.js";
import type { LecturaMatematicas } from "./vision.js";

/**
 * Comparación de lo que el niño resolvió contra lo que debía salir.
 *
 * No basta con mirar el resultado: si copió mal la operación, el resultado
 * puede ser correcto para lo que él escribió y aun así hay algo que enseñarle.
 * Copiar mal es un error distinto de calcular mal, y se informa como tal.
 */

export type MotivoFallo = "resultado" | "copia" | "sin_hacer";

export interface ResultadoOperacion {
  operacion: Operacion;
  escrito: string;
  correcta: boolean;
  motivo: MotivoFallo | null;
}

/** Los números que aparecen en una respuesta, en orden: "45 resto 3" → [45, 3]. */
function numerosDe(texto: string): string[] {
  return (texto.replace(/,/g, ".").match(/-?\d+(?:\.\d+)?/g) ?? []).map((n) =>
    // "3.0" y "3" son la misma respuesta; "3.50" y "3.5" también.
    String(Number(n)),
  );
}

export function mismaRespuesta(esperado: string, escrito: string): boolean {
  const a = numerosDe(esperado);
  const b = numerosDe(escrito);
  return a.length > 0 && a.length === b.length && a.every((n, i) => n === b[i]);
}

/** ¿Copió bien el enunciado? Se comparan solo los números, no los símbolos. */
function copiaCorrecta(enunciado: string, copiado: string): boolean {
  if (copiado.trim() === "") return true; // no lo pudimos leer: no lo penalizamos
  const a = numerosDe(enunciado);
  const b = numerosDe(copiado);
  return a.length === b.length && a.every((n, i) => n === b[i]);
}

export function corregirTanda(
  operaciones: readonly Operacion[],
  lectura: LecturaMatematicas,
): ResultadoOperacion[] {
  const porNumero = new Map(lectura.ejercicios.map((e) => [e.numero, e]));

  return operaciones.map((operacion) => {
    const leido = porNumero.get(operacion.numero);

    if (!leido || !leido.encontrado || leido.resultadoEscrito.trim() === "") {
      return { operacion, escrito: "", correcta: false, motivo: "sin_hacer" as const };
    }
    if (!copiaCorrecta(operacion.enunciado, leido.operacionEscrita)) {
      return {
        operacion,
        escrito: leido.operacionEscrita,
        correcta: false,
        motivo: "copia" as const,
      };
    }
    const correcta = mismaRespuesta(operacion.respuesta, leido.resultadoEscrito);
    return {
      operacion,
      escrito: leido.resultadoEscrito,
      correcta,
      motivo: correcta ? null : ("resultado" as const),
    };
  });
}
