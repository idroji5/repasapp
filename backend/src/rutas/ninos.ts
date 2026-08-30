import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { consulta, uno } from "../db/pool.js";
import { ASIGNATURAS, type Asignatura, type Nivel } from "../domain/asignaturas.js";
import { exigirPadre, ninoDelPadre } from "./plugins.js";

const NuevoNino = z.object({
  nombre: z.string().min(1).max(40),
  curso: z.number().int().min(1).max(6),
  anoNacimiento: z.number().int().min(2005).max(new Date().getFullYear()).optional(),
  minutosDiarios: z.number().int().min(5).max(60).default(15),
  /** Nivel de partida por asignatura. Si no se dice, todas empiezan en 3. */
  niveles: z.record(z.string(), z.number().int().min(1).max(5)).optional(),
});

export async function rutasNinos(app: FastifyInstance) {
  app.addHook("preHandler", exigirPadre);

  app.get("/api/ninos", async (peticion) => {
    const ninos = await consulta<{
      id: string; nombre: string; curso: number; minutos_diarios: number; modo_pistas: boolean;
    }>(
      `select id, nombre, curso, minutos_diarios, modo_pistas
         from ninos where padre_id = $1 order by creado_en`,
      [peticion.padreId],
    );

    const niveles = await consulta<{ nino_id: string; asignatura: string; nivel: number; bloqueado: boolean }>(
      `select nino_id, asignatura, nivel, bloqueado from niveles_asignatura
        where nino_id = any($1::uuid[])`,
      [ninos.map((n) => n.id)],
    );

    return ninos.map((n) => ({
      id: n.id,
      nombre: n.nombre,
      curso: n.curso,
      minutosDiarios: n.minutos_diarios,
      modoPistas: n.modo_pistas,
      niveles: Object.fromEntries(
        niveles.filter((x) => x.nino_id === n.id).map((x) => [x.asignatura, x.nivel]),
      ),
    }));
  });

  app.post("/api/ninos", async (peticion, respuesta) => {
    const datos = NuevoNino.safeParse(peticion.body);
    if (!datos.success) {
      return respuesta.code(400).send({ error: datos.error.issues[0]?.message });
    }
    const { nombre, curso, anoNacimiento, minutosDiarios, niveles } = datos.data;

    const [nino] = await consulta<{ id: string }>(
      `insert into ninos (padre_id, nombre, curso, ano_nacimiento, minutos_diarios)
       values ($1, $2, $3, $4, $5) returning id`,
      [peticion.padreId, nombre, curso, anoNacimiento ?? null, minutosDiarios],
    );

    // Un nivel por asignatura desde el primer día: es lo que permite que
    // Matemáticas y Dictado vayan por caminos distintos.
    for (const asignatura of ASIGNATURAS) {
      await consulta(
        `insert into niveles_asignatura (nino_id, asignatura, nivel) values ($1, $2, $3)`,
        [nino!.id, asignatura, niveles?.[asignatura] ?? 3],
      );
    }

    return respuesta.code(201).send({ id: nino!.id });
  });

  const Ajustes = z.object({
    minutosDiarios: z.number().int().min(5).max(60).optional(),
    modoPistas: z.boolean().optional(),
    curso: z.number().int().min(1).max(6).optional(),
  });

  app.patch<{ Params: { id: string } }>("/api/ninos/:id", async (peticion, respuesta) => {
    const nino = await ninoDelPadre(peticion.params.id, peticion.padreId);
    if (!nino) return respuesta.code(404).send({ error: "Niño no encontrado" });

    const datos = Ajustes.safeParse(peticion.body);
    if (!datos.success) return respuesta.code(400).send({ error: "Datos no válidos" });

    await consulta(
      `update ninos set
         minutos_diarios = coalesce($2, minutos_diarios),
         modo_pistas     = coalesce($3, modo_pistas),
         curso           = coalesce($4, curso)
       where id = $1`,
      [
        nino.id,
        datos.data.minutosDiarios ?? null,
        datos.data.modoPistas ?? null,
        datos.data.curso ?? null,
      ],
    );
    return { ok: true };
  });

  const CambioNivel = z.object({
    nivel: z.number().int().min(1).max(5),
    /** Si el padre lo fija, el autoajuste deja de tocarlo. */
    bloqueado: z.boolean().default(true),
  });

  app.put<{ Params: { id: string; asignatura: Asignatura } }>(
    "/api/ninos/:id/niveles/:asignatura",
    async (peticion, respuesta) => {
      const nino = await ninoDelPadre(peticion.params.id, peticion.padreId);
      if (!nino) return respuesta.code(404).send({ error: "Niño no encontrado" });

      const datos = CambioNivel.safeParse(peticion.body);
      if (!datos.success) return respuesta.code(400).send({ error: "Nivel no válido" });

      const anterior = await uno<{ nivel: number }>(
        "select nivel from niveles_asignatura where nino_id = $1 and asignatura = $2",
        [nino.id, peticion.params.asignatura],
      );

      await consulta(
        `insert into niveles_asignatura (nino_id, asignatura, nivel, bloqueado, cambiado_en)
         values ($1, $2, $3, $4, now())
         on conflict (nino_id, asignatura)
         do update set nivel = $3, bloqueado = $4, cambiado_en = now()`,
        [nino.id, peticion.params.asignatura, datos.data.nivel, datos.data.bloqueado],
      );

      if (anterior && anterior.nivel !== datos.data.nivel) {
        await consulta(
          `insert into cambios_nivel (nino_id, asignatura, nivel_antes, nivel_despues, motivo)
           values ($1, $2, $3, $4, 'cambiado por el padre')`,
          [nino.id, peticion.params.asignatura, anterior.nivel, datos.data.nivel],
        );
      }
      return { ok: true, nivel: datos.data.nivel as Nivel };
    },
  );
}
