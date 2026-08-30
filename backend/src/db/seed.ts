/**
 * Familia de ejemplo para desarrollar contra datos reales.
 *
 *   npm run db:seed
 *
 * Crea a Pedro tal y como se describió el producto: 9 años, 4.º de Primaria,
 * Matemáticas en nivel alto y Dictado en nivel de refuerzo. El caso concreto
 * que justifica que el nivel sea por asignatura y no por niño.
 */
import { consulta, pool } from "./pool.js";
import { hashear } from "../lib/auth.js";

const EMAIL = "familia@ejemplo.es";

await consulta("delete from padres where email = $1", [EMAIL]);

const [padre] = await consulta<{ id: string }>(
  `insert into padres (email, password_hash, pin_hash) values ($1, $2, $3) returning id`,
  [EMAIL, await hashear("repasapp2026"), await hashear("1234")],
);

const [pedro] = await consulta<{ id: string }>(
  `insert into ninos (padre_id, nombre, curso, ano_nacimiento, minutos_diarios)
   values ($1, 'Pedro', 4, 2017, 15) returning id`,
  [padre!.id],
);

const [lucia] = await consulta<{ id: string }>(
  `insert into ninos (padre_id, nombre, curso, ano_nacimiento, minutos_diarios)
   values ($1, 'Lucía', 2, 2019, 10) returning id`,
  [padre!.id],
);

for (const [ninoId, niveles] of [
  [pedro!.id, { matematicas: 4, dictado: 2 }],
  [lucia!.id, { matematicas: 3, dictado: 3 }],
] as const) {
  for (const [asignatura, nivel] of Object.entries(niveles)) {
    await consulta(
      "insert into niveles_asignatura (nino_id, asignatura, nivel) values ($1, $2, $3)",
      [ninoId, asignatura, nivel],
    );
  }
}

console.log(`Familia de ejemplo creada.
  correo:    ${EMAIL}
  contraseña: repasapp2026
  PIN:       1234
  Pedro  — 4.º, Matemáticas 4/5, Dictado 2/5
  Lucía  — 2.º, Matemáticas 3/5, Dictado 3/5`);

await pool.end();
