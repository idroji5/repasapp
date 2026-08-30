import type { FastifyReply, FastifyRequest } from "fastify";
import { verificarToken } from "../lib/auth.js";
import { uno } from "../db/pool.js";

declare module "fastify" {
  interface FastifyRequest {
    padreId: string;
  }
}

/** Exige un token válido y deja el padre autenticado en la petición. */
export async function exigirPadre(peticion: FastifyRequest, respuesta: FastifyReply) {
  const cabecera = peticion.headers.authorization ?? "";
  const token = cabecera.startsWith("Bearer ") ? cabecera.slice(7) : "";
  const sesion = verificarToken(token);

  if (!sesion) {
    await respuesta.code(401).send({ error: "Sesión no válida o caducada" });
    return;
  }
  peticion.padreId = sesion.padreId;
}

/**
 * Comprueba que el niño existe y es hijo de quien pregunta. Todas las rutas que
 * tocan datos de un niño pasan por aquí: es la única barrera entre las familias.
 */
export async function ninoDelPadre(ninoId: string, padreId: string) {
  return uno<{
    id: string;
    nombre: string;
    curso: number;
    minutos_diarios: number;
    modo_pistas: boolean;
  }>(
    `select id, nombre, curso, minutos_diarios, modo_pistas
       from ninos where id = $1 and padre_id = $2`,
    [ninoId, padreId],
  );
}
