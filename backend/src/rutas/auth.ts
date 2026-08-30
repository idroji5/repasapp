import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { consulta, uno } from "../db/pool.js";
import { firmarToken, hashear, verificar } from "../lib/auth.js";

const Registro = z.object({
  email: z.email(),
  password: z.string().min(8, "La contraseña debe tener al menos 8 caracteres"),
  pin: z.string().regex(/^\d{4}$/, "El PIN son 4 dígitos"),
});

const Acceso = z.object({
  email: z.email(),
  password: z.string(),
});

export async function rutasAuth(app: FastifyInstance) {
  app.post("/api/registro", async (peticion, respuesta) => {
    const datos = Registro.safeParse(peticion.body);
    if (!datos.success) {
      return respuesta.code(400).send({ error: datos.error.issues[0]?.message });
    }
    const { email, password, pin } = datos.data;

    const yaExiste = await uno("select 1 from padres where email = $1", [email.toLowerCase()]);
    if (yaExiste) {
      return respuesta.code(409).send({ error: "Ya hay una cuenta con ese correo" });
    }

    const [padre] = await consulta<{ id: string }>(
      `insert into padres (email, password_hash, pin_hash)
       values ($1, $2, $3) returning id`,
      [email.toLowerCase(), await hashear(password), await hashear(pin)],
    );

    return { token: firmarToken(padre!.id) };
  });

  app.post("/api/acceso", async (peticion, respuesta) => {
    const datos = Acceso.safeParse(peticion.body);
    if (!datos.success) {
      return respuesta.code(400).send({ error: "Datos incompletos" });
    }

    const padre = await uno<{ id: string; password_hash: string }>(
      "select id, password_hash from padres where email = $1",
      [datos.data.email.toLowerCase()],
    );
    // Mismo mensaje exista o no la cuenta: no confirmamos qué correos hay dados de alta.
    if (!padre || !(await verificar(datos.data.password, padre.password_hash))) {
      return respuesta.code(401).send({ error: "Correo o contraseña incorrectos" });
    }

    return { token: firmarToken(padre.id) };
  });
}
