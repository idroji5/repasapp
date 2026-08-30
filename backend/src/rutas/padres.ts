import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { consulta, uno } from "../db/pool.js";
import { verificar } from "../lib/auth.js";
import { nombreDestreza } from "../domain/curriculo.js";
import { exigirPadre, ninoDelPadre } from "./plugins.js";

/**
 * Zona de padres. Va detrás de un PIN de 4 dígitos porque el móvil lo tiene el
 * niño en la mano: la contraseña de la cuenta no sirve de barrera aquí.
 *
 * Las estadísticas son deliberadamente pocas. Un padre quiere saber si su hijo
 * está estudiando, en qué falla y si progresa; no necesita un cuadro de mando.
 */
export async function rutasPadres(app: FastifyInstance) {
  app.addHook("preHandler", exigirPadre);

  app.post("/api/padres/pin", async (peticion, respuesta) => {
    const datos = z.object({ pin: z.string() }).safeParse(peticion.body);
    if (!datos.success) return respuesta.code(400).send({ error: "Falta el PIN" });

    const padre = await uno<{ pin_hash: string }>("select pin_hash from padres where id = $1", [
      peticion.padreId,
    ]);
    if (!padre || !(await verificar(datos.data.pin, padre.pin_hash))) {
      return respuesta.code(401).send({ error: "PIN incorrecto" });
    }
    return { ok: true };
  });

  app.get<{ Params: { id: string } }>(
    "/api/ninos/:id/estadisticas",
    async (peticion, respuesta) => {
      const nino = await ninoDelPadre(peticion.params.id, peticion.padreId);
      if (!nino) return respuesta.code(404).send({ error: "Niño no encontrado" });

      const [porAsignatura, topErrores, ultimosDias, cambios, racha] = await Promise.all([
        consulta<{
          asignatura: string; nivel: number; bloqueado: boolean;
          actividades: string; aciertos: string; total: string;
        }>(
          `select na.asignatura, na.nivel, na.bloqueado,
                  count(a.id)                       as actividades,
                  coalesce(sum(a.aciertos), 0)      as aciertos,
                  coalesce(sum(a.total), 0)         as total
             from niveles_asignatura na
             left join actividades a
               on a.nino_id = na.nino_id and a.asignatura = na.asignatura
              and a.estado = 'corregida' and a.corregida_en > now() - interval '30 days'
            where na.nino_id = $1
            group by na.asignatura, na.nivel, na.bloqueado
            order by na.asignatura`,
          [nino.id],
        ),
        consulta<{ destreza_id: string; fallos: string }>(
          `select destreza_id, count(*) as fallos from errores
            where nino_id = $1 and creado_en > now() - interval '30 days'
            group by destreza_id order by count(*) desc limit 5`,
          [nino.id],
        ),
        consulta<{ dia: string; minutos: string; actividades: string }>(
          `select iniciada_en::date::text as dia,
                  round(coalesce(sum(a.duracion_s), 0) / 60.0)::text as minutos,
                  count(a.id) as actividades
             from sesiones s left join actividades a on a.sesion_id = s.id
            where s.nino_id = $1 and s.iniciada_en > now() - interval '7 days'
            group by s.iniciada_en::date order by dia`,
          [nino.id],
        ),
        consulta<{ asignatura: string; nivel_antes: number; nivel_despues: number; motivo: string; creado_en: Date }>(
          `select asignatura, nivel_antes, nivel_despues, motivo, creado_en
             from cambios_nivel where nino_id = $1 order by creado_en desc limit 10`,
          [nino.id],
        ),
        calcularRacha(nino.id),
      ]);

      return {
        nino: { id: nino.id, nombre: nino.nombre, curso: nino.curso },
        racha,
        porAsignatura: porAsignatura.map((a) => ({
          asignatura: a.asignatura,
          nivel: a.nivel,
          bloqueado: a.bloqueado,
          actividades: Number(a.actividades),
          porcentajeAcierto:
            Number(a.total) > 0 ? Math.round((Number(a.aciertos) / Number(a.total)) * 100) : null,
        })),
        erroresFrecuentes: topErrores.map((e) => ({
          destrezaId: e.destreza_id,
          nombre: nombreDestreza(e.destreza_id),
          fallos: Number(e.fallos),
        })),
        ultimosDias: ultimosDias.map((d) => ({
          dia: d.dia,
          minutos: Number(d.minutos),
          actividades: Number(d.actividades),
        })),
        cambiosNivel: cambios,
      };
    },
  );
}

/** Días seguidos, hasta hoy, en los que ha hecho al menos una actividad. */
async function calcularRacha(ninoId: string): Promise<number> {
  const dias = await consulta<{ dia: string }>(
    `select distinct iniciada_en::date::text as dia from sesiones
      where nino_id = $1 order by dia desc limit 90`,
    [ninoId],
  );
  if (dias.length === 0) return 0;

  const hoy = new Date();
  hoy.setHours(0, 0, 0, 0);
  let racha = 0;

  for (const [i, { dia }] of dias.entries()) {
    const esperado = new Date(hoy);
    esperado.setDate(hoy.getDate() - i);
    // Se admite empezar la racha ayer: aún no ha estudiado hoy y no se le castiga.
    if (i === 0 && dia !== iso(esperado) && dia !== iso(new Date(esperado.getTime() - 86400000))) {
      return 0;
    }
    if (i > 0 && dia !== iso(esperado)) break;
    racha++;
  }
  return racha;
}

function iso(d: Date): string {
  return d.toISOString().slice(0, 10);
}
