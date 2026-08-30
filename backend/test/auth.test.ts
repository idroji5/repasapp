import { test } from "node:test";
import assert from "node:assert/strict";
import { firmarToken, hashear, verificar, verificarToken } from "../src/lib/auth.js";

test("una contraseña se verifica contra su propio hash y no contra otro", async () => {
  const hash = await hashear("mi-contraseña-buena");
  assert.ok(await verificar("mi-contraseña-buena", hash));
  assert.equal(await verificar("otra-cosa", hash), false);
});

test("cada hash lleva su propia sal", async () => {
  assert.notEqual(await hashear("igual"), await hashear("igual"));
});

test("un token firmado se verifica; uno manipulado no", () => {
  const token = firmarToken("11111111-1111-1111-1111-111111111111");
  assert.equal(verificarToken(token)?.padreId, "11111111-1111-1111-1111-111111111111");

  const [cabecera, cuerpo, firma] = token.split(".");
  const falsificado = Buffer.from(JSON.stringify({ padreId: "otro", exp: 9e9 })).toString("base64url");
  assert.equal(verificarToken(`${cabecera}.${falsificado}.${firma}`), null);
  assert.equal(verificarToken("basura"), null);
});
