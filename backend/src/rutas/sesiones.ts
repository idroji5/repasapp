import type { FastifyInstance } from "fastify";
import { consulta, enTransaccion, uno } from "../db/pool.js";
import type { Asignatura, Nivel } from "../domain/asignaturas.js";
import { ASIGNATURAS } from "../domain/asignaturas.js";
import { ajustarNivel } from "../domain/niveles.js";
import { planificarSesion } from "../domain/planificador.js";
import { reconstruir, tituloDe } from "../domain/reconstruir.js";
import {
  guionDictado,
  guionMatematicas,
  guionRepasoDictado,
  guionRepasoMatematicas,
} from "../domain/actividades.js";
import { corregirDictado, type ErrorDictado } from "../correccion/alinear.js";
import { corregirTanda } from "../correccion/matematicas.js";
import {
  esTipoAceptado,
  FotoIlegible,
  leerDictado,
  leerMatematicas,
  VisionNoConfigurada,
} from "../correccion/vision.js";
import { textoCompleto } from "../content/dictados.js";
import { exigirPadre, ninoDelPadre } from "./plugins.js";

/** Cuántas actividades recientes mira el autoajuste de nivel. */
const HISTORIAL_PARA_NIVEL = 3;

interface FilaActividad {
  id: string;
  nino_id: string;
  asignatura: Asignatura;
  nivel: number;
  orden: number;
  contenido: Record<string, unknown>;
  estado: string;
  aciertos: number | null;
  total: number | null;
}

export async function rutasSesiones(app: FastifyInstance) {
  app.addHook("preHandler", exigirPadre);

  // ------------------------------------------------------ el plan de hoy ---

  app.get<{ Params: { id: string } }>("/api/ninos/:id/hoy", async (peticion, respuesta) => {
    const nino = await ninoDelPadre(peticion.params.id, peticion.padreId);
    if (!nino) return respuesta.code(404).send({ error: "Niño no encontrado" });

    const existente = await uno<{ id: string; minutos_previstos: number }>(
      `select id, minutos_previstos from sesiones
        where nino_id = $1 and iniciada_en::date = current_date
        order by iniciada_en desc limit 1`,
      [nino.id],
    );

    const sesionId = existente?.id ?? (await crearSesionDeHoy(nino));

    const actividades = await consulta<FilaActividad>(
      `select id, nino_id, asignatura, nivel, orden, contenido, estado, aciertos, total
         from actividades where sesion_id = $1 order by orden`,
      [sesionId],
    );

    return {
      sesionId,
      minutos: existente?.minutos_previstos ?? nino.minutos_diarios,
      nombre: nino.nombre,
      actividades: actividades.map((a) => ({
        id: a.id,
        asignatura: a.asignatura,
        nivel: a.nivel,
        titulo: tituloDe(a.contenido),
        estado: a.estado,
        aciertos: a.aciertos,
        total: a.total,
      })),
    };
  });

  // --------------------------------------------- el guion de una actividad ---

  app.post<{ Params: { id: string } }>(
    "/api/actividades/:id/guion",
    async (peticion, respuesta) => {
      const actividad = await actividadDelPadre(peticion.params.id, peticion.padreId);
      if (!actividad) return respuesta.code(404).send({ error: "Actividad no encontrada" });

      const contenido = reconstruir(actividad.contenido, actividad.nivel as Nivel);

      await consulta(
        "update actividades set estado = 'en_curso' where id = $1 and estado = 'pendiente'",
        [actividad.id],
      );

      return contenido.tipo === "dictado"
        ? guionDictado(actividad.id, contenido.dictado)
        : guionMatematicas(actividad.id, contenido.operaciones);
    },
  );

  // ------------------------------------------------- corrección por foto ---

  app.post<{ Params: { id: string } }>(
    "/api/actividades/:id/corregir",
    async (peticion, respuesta) => {
      const actividad = await actividadDelPadre(peticion.params.id, peticion.padreId);
      if (!actividad) return respuesta.code(404).send({ error: "Actividad no encontrada" });

      const subida = await peticion.file();
      if (!subida) return respuesta.code(400).send({ error: "Falta la foto" });
      if (!esTipoAceptado(subida.mimetype)) {
        return respuesta.code(415).send({ error: "Formato de imagen no admitido" });
      }

      // La foto vive aquí, en memoria, y solo aquí. No se escribe en disco ni se
      // guarda en la base de datos: al salir de esta función deja de existir.
      const foto = await subida.toBuffer();
      if (subida.file.truncated) {
        return respuesta.code(413).send({ error: "La foto es demasiado grande" });
      }

      const nino = await ninoDelPadre(actividad.nino_id, peticion.padreId);
      if (!nino) return respuesta.code(404).send({ error: "Niño no encontrado" });

      const contenido = reconstruir(actividad.contenido, actividad.nivel as Nivel);

      try {
        if (contenido.tipo === "dictado") {
          const referencia = textoCompleto(contenido.dictado);
          const lectura = await leerDictado(foto, subida.mimetype, referencia);
          const correccion = corregirDictado(referencia, lectura.transcripcion);

          await guardarResultado(
            actividad.id,
            actividad.nino_id,
            correccion.aciertos,
            correccion.totalPalabras,
            correccion.errores,
          );
          const cambioNivel = await autoajustarNivel(actividad.nino_id, "dictado");

          return {
            resultado: {
              aciertos: correccion.aciertos,
              total: correccion.totalPalabras,
              transcripcion: lectura.transcripcion,
              confianza: lectura.confianza,
              errores: correccion.errores,
            },
            guion: await guionRepasoDictado(actividad.id, correccion),
            cambioNivel,
          };
        }

        const enunciados = contenido.operaciones.map((o) => o.enunciado);
        const lectura = await leerMatematicas(foto, subida.mimetype, enunciados);
        const resultados = corregirTanda(contenido.operaciones, lectura);
        const aciertos = resultados.filter((r) => r.correcta).length;

        await guardarResultado(
          actividad.id,
          actividad.nino_id,
          aciertos,
          resultados.length,
          resultados
            .filter((r) => !r.correcta)
            .map((r) => ({
              destrezaId: r.operacion.destrezaId,
              tipo: r.motivo ?? "resultado",
              esperado: r.operacion.respuesta,
              escrito: r.escrito,
            })),
        );
        const cambioNivel = await autoajustarNivel(actividad.nino_id, "matematicas");

        return {
          resultado: {
            aciertos,
            total: resultados.length,
            operaciones: resultados.map((r) => ({
              numero: r.operacion.numero,
              enunciado: r.operacion.enunciado,
              esperado: r.operacion.respuesta,
              escrito: r.escrito,
              correcta: r.correcta,
              motivo: r.motivo,
            })),
          },
          guion: await guionRepasoMatematicas(actividad.id, resultados, nino.modo_pistas),
          cambioNivel,
        };
      } catch (e) {
        if (e instanceof FotoIlegible) {
          return respuesta.code(422).send({ error: e.aviso, reintentable: true });
        }
        if (e instanceof VisionNoConfigurada) {
          return respuesta.code(503).send({ error: e.message });
        }
        throw e;
      }
    },
  );

  app.post<{ Params: { id: string } }>(
    "/api/sesiones/:id/terminar",
    async (peticion, respuesta) => {
      const filas = await consulta(
        `update sesiones s set terminada_en = now()
           from ninos n
          where s.id = $1 and s.nino_id = n.id and n.padre_id = $2
            and s.terminada_en is null
        returning s.id`,
        [peticion.params.id, peticion.padreId],
      );
      if (filas.length === 0) return respuesta.code(404).send({ error: "Sesión no encontrada" });
      return { ok: true };
    },
  );
}

// ------------------------------------------------------------- auxiliares ---

async function actividadDelPadre(actividadId: string, padreId: string) {
  return uno<FilaActividad>(
    `select a.id, a.nino_id, a.asignatura, a.nivel, a.orden, a.contenido, a.estado,
            a.aciertos, a.total
       from actividades a join ninos n on n.id = a.nino_id
      where a.id = $1 and n.padre_id = $2`,
    [actividadId, padreId],
  );
}

async function crearSesionDeHoy(nino: {
  id: string;
  curso: number;
  minutos_diarios: number;
}): Promise<string> {
  const niveles = await consulta<{ asignatura: Asignatura; nivel: number }>(
    "select asignatura, nivel from niveles_asignatura where nino_id = $1",
    [nino.id],
  );
  const porAsignatura = Object.fromEntries(
    ASIGNATURAS.map((a) => [a, (niveles.find((n) => n.asignatura === a)?.nivel ?? 3) as Nivel]),
  ) as Record<Asignatura, Nivel>;

  const hechos = await consulta<{ contenido: Record<string, unknown> }>(
    `select contenido from actividades
      where nino_id = $1 and asignatura = 'dictado' order by creada_en desc limit 20`,
    [nino.id],
  );

  const flojas = await consulta<{ destreza_id: string }>(
    `select destreza_id from destrezas_nino
      where nino_id = $1 and fallos > 0
      order by fallos::float / greatest(intentos, 1) desc, ultimo_fallo_en desc
      limit 5`,
    [nino.id],
  );

  const ultima = await uno<{ asignatura: Asignatura }>(
    `select asignatura from actividades where nino_id = $1
      order by creada_en desc limit 1`,
    [nino.id],
  );

  const plan = planificarSesion({
    curso: nino.curso,
    minutosDiarios: nino.minutos_diarios,
    niveles: porAsignatura,
    dictadosHechos: hechos.map((h) => String(h.contenido.dictadoId)).filter(Boolean),
    destrezasFlojas: flojas.map((f) => f.destreza_id),
    ultimaAsignatura: ultima?.asignatura ?? null,
  });

  return enTransaccion(async (cliente) => {
    const { rows } = await cliente.query<{ id: string }>(
      "insert into sesiones (nino_id, minutos_previstos) values ($1, $2) returning id",
      [nino.id, nino.minutos_diarios],
    );
    const sesionId = rows[0]!.id;

    for (const [i, actividad] of plan.entries()) {
      await cliente.query(
        `insert into actividades (sesion_id, nino_id, asignatura, nivel, orden, contenido)
         values ($1, $2, $3, $4, $5, $6)`,
        [sesionId, nino.id, actividad.asignatura, actividad.nivel, i, actividad.contenido],
      );
    }
    return sesionId;
  });
}

type FalloGuardable = Pick<ErrorDictado, "esperado" | "escrito"> & {
  destrezaId: string | null;
  tipo: string;
};

async function guardarResultado(
  actividadId: string,
  ninoId: string,
  aciertos: number,
  total: number,
  fallos: readonly FalloGuardable[],
): Promise<void> {
  await enTransaccion(async (cliente) => {
    await cliente.query(
      `update actividades
          set estado = 'corregida', aciertos = $2, total = $3, corregida_en = now(),
              duracion_s = extract(epoch from now() - creada_en)::int
        where id = $1`,
      [actividadId, aciertos, total],
    );

    for (const fallo of fallos) {
      if (!fallo.destrezaId) continue;
      await cliente.query(
        `insert into errores (nino_id, actividad_id, destreza_id, tipo, esperado, escrito)
         values ($1, $2, $3, $4, $5, $6)`,
        [ninoId, actividadId, fallo.destrezaId, fallo.tipo, fallo.esperado, fallo.escrito],
      );
      await cliente.query(
        `insert into destrezas_nino (nino_id, destreza_id, intentos, fallos, ultimo_fallo_en)
         values ($1, $2, 1, 1, now())
         on conflict (nino_id, destreza_id) do update
           set intentos = destrezas_nino.intentos + 1,
               fallos   = destrezas_nino.fallos + 1,
               ultimo_fallo_en = now()`,
        [ninoId, fallo.destrezaId],
      );
    }
  });
}

export interface CambioDeNivel {
  asignatura: Asignatura;
  antes: number;
  despues: number;
  motivo: string;
}

/** Revisa si esta actividad cambia el nivel de la asignatura, y lo aplica. */
async function autoajustarNivel(
  ninoId: string,
  asignatura: Asignatura,
): Promise<CambioDeNivel | null> {
  const estado = await uno<{ nivel: number; bloqueado: boolean; cambiado_en: Date | null }>(
    "select nivel, bloqueado, cambiado_en from niveles_asignatura where nino_id = $1 and asignatura = $2",
    [ninoId, asignatura],
  );
  if (!estado) return null;

  const recientes = await consulta<{ aciertos: number; total: number; corregida_en: Date }>(
    `select aciertos, total, corregida_en from actividades
      where nino_id = $1 and asignatura = $2 and estado = 'corregida' and total > 0
      order by corregida_en desc limit $3`,
    [ninoId, asignatura, HISTORIAL_PARA_NIVEL],
  );

  const ajuste = ajustarNivel(
    {
      nivel: estado.nivel as Nivel,
      bloqueado: estado.bloqueado,
      cambiadoEn: estado.cambiado_en,
    },
    recientes.map((r) => ({ aciertos: r.aciertos, total: r.total, corregidaEn: r.corregida_en })),
  );

  if (!ajuste.cambia) return null;

  await consulta(
    `update niveles_asignatura set nivel = $3, cambiado_en = now()
      where nino_id = $1 and asignatura = $2`,
    [ninoId, asignatura, ajuste.nivelNuevo],
  );
  await consulta(
    `insert into cambios_nivel (nino_id, asignatura, nivel_antes, nivel_despues, motivo)
     values ($1, $2, $3, $4, $5)`,
    [ninoId, asignatura, estado.nivel, ajuste.nivelNuevo, ajuste.motivo],
  );

  return {
    asignatura,
    antes: estado.nivel,
    despues: ajuste.nivelNuevo,
    motivo: ajuste.motivo,
  };
}
