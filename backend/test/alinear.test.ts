import { test } from "node:test";
import assert from "node:assert/strict";
import { clasificar, corregirDictado, tipoAcentual } from "../src/correccion/alinear.js";

test("clasifica el tipo de fallo ortográfico", () => {
  assert.equal(clasificar("había", "habia"), "tilde");
  assert.equal(clasificar("también", "tambien"), "tilde");
  assert.equal(clasificar("árbol", "arbol"), "tilde");
  assert.equal(clasificar("hola", "ola"), "h");
  assert.equal(clasificar("bailado", "vailado"), "b_v");
  assert.equal(clasificar("llevaba", "yevaba"), "ll_y");
  assert.equal(clasificar("jardín", "gardin"), "g_j");
  assert.equal(clasificar("zapato", "sapato"), "c_z");
  assert.equal(clasificar("perro", "pero"), "r_rr");
  assert.equal(clasificar("campo", "canpo"), "m_antes_p_b");
  assert.equal(clasificar("Rosa", "rosa"), "mayuscula");
  assert.equal(clasificar("ventana", "mesa"), "ortografia");
});

test("distingue aguda, llana y esdrújula", () => {
  assert.equal(tipoAcentual("balón"), "aguda");
  assert.equal(tipoAcentual("árbol"), "llana");
  assert.equal(tipoAcentual("simpático"), "esdrujula");
  assert.equal(tipoAcentual("casa"), null);
});

test("imputa la tilde a la destreza correcta", () => {
  const { errores } = corregirDictado("Cayó un balón.", "Cayo un balon.");
  assert.equal(errores.length, 2);
  assert.ok(errores.every((e) => e.tipo === "tilde"));
  assert.ok(errores.every((e) => e.destrezaId === "tilde_agudas"));
});

test("la tilde diacrítica va a su propia destreza", () => {
  const { errores } = corregirDictado("Pero tú sabes.", "Pero tu sabes.");
  assert.equal(errores[0]?.destrezaId, "tilde_diacritica");
});

test("los verbos en -aba se imputan a su regla, no a b/v general", () => {
  const { errores } = corregirDictado("Ella cocinaba.", "Ella cocinava.");
  assert.equal(errores[0]?.tipo, "b_v");
  assert.equal(errores[0]?.destrezaId, "b_verbos_aba");
});

test("un dictado perfecto no tiene errores", () => {
  const texto = "Mi abuelo vive en el campo. Tiene un perro pequeño.";
  const r = corregirDictado(texto, texto);
  assert.equal(r.errores.length, 0);
  assert.equal(r.aciertos, r.totalPalabras);
});

test("detecta palabras omitidas y añadidas", () => {
  const r = corregirDictado("Mi abuelo vive en el campo.", "Mi abuelo vive el campo.");
  const omision = r.errores.find((e) => e.tipo === "omision");
  assert.equal(omision?.esperado, "en");

  const r2 = corregirDictado("Mi abuelo vive.", "Mi querido abuelo vive.");
  assert.ok(r2.errores.some((e) => e.tipo === "adicion" && e.escrito === "querido"));
});

test("detecta que el niño separó una palabra en dos", () => {
  const r = corregirDictado("Sonreía porque todo salió bien.", "Sonreía por que todo salió bien.");
  const sep = r.errores.find((e) => e.tipo === "union_separacion");
  assert.equal(sep?.esperado, "porque");
  assert.equal(sep?.escrito, "por que");
  assert.equal(sep?.destrezaId, "porque");
});

test("detecta que el niño unió dos palabras en una", () => {
  const r = corregirDictado("Vamos a ver si hay entradas.", "Vamos aver si hay entradas.");
  const sep = r.errores.find((e) => e.tipo === "union_separacion");
  assert.equal(sep?.esperado, "a ver");
  assert.equal(sep?.escrito, "aver");
});

test("avisa de la puntuación que falta, pero sin inundar", () => {
  const r = corregirDictado("¿Quieres jugar? ¡Vamos, corre!", "Quieres jugar Vamos corre");
  const puntuacion = r.errores.filter((e) => e.tipo === "puntuacion");
  assert.ok(puntuacion.length > 0);
  assert.ok(puntuacion.length <= 2);
});

test("una palabra puede acumular dos faltas: falta la hache y la be es uve", () => {
  const r = corregirDictado("No había ido.", "No avía ido.");
  const e = r.errores[0]!;
  assert.equal(e.tipo, "h");
  assert.deepEqual(e.tambien, ["b_v"]);
  assert.equal(e.destrezaId, "h_frecuente");
});

test("caso realista: un dictado de nivel 5 con tres faltas", () => {
  const referencia = "Me preguntabas por qué no había ido. Sí, tenía muchas ganas de verte.";
  const escrito = "Me preguntabas por que no avía ido. Si, tenía muchas ganas de verte.";
  const r = corregirDictado(referencia, escrito);

  assert.equal(r.errores.length, 3);
  // "qué" y "Sí" pierden la tilde diacrítica; "había" se convierte en "avía".
  assert.deepEqual(
    r.errores.map((e) => e.esperado),
    ["qué", "había", "Sí"],
  );
  assert.deepEqual(
    r.errores.map((e) => e.destrezaId),
    ["tilde_diacritica", "h_frecuente", "tilde_diacritica"],
  );
  assert.equal(r.totalPalabras, 13);
  assert.equal(r.aciertos, 10);
});
