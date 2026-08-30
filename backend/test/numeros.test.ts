import { test } from "node:test";
import assert from "node:assert/strict";
import { enteroALetras, numeroALetras, ordinalFemenino } from "../src/content/numeros.js";

test("unidades y decenas", () => {
  assert.equal(enteroALetras(0), "cero");
  assert.equal(enteroALetras(7), "siete");
  assert.equal(enteroALetras(15), "quince");
  assert.equal(enteroALetras(16), "dieciséis");
  assert.equal(enteroALetras(21), "veintiuno");
  assert.equal(enteroALetras(22), "veintidós");
  assert.equal(enteroALetras(30), "treinta");
  assert.equal(enteroALetras(31), "treinta y uno");
  assert.equal(enteroALetras(99), "noventa y nueve");
});

test("centenas", () => {
  assert.equal(enteroALetras(100), "cien");
  assert.equal(enteroALetras(101), "ciento uno");
  assert.equal(enteroALetras(115), "ciento quince");
  assert.equal(enteroALetras(200), "doscientos");
  assert.equal(enteroALetras(500), "quinientos");
  assert.equal(enteroALetras(700), "setecientos");
  assert.equal(enteroALetras(742), "setecientos cuarenta y dos");
  assert.equal(enteroALetras(900), "novecientos");
  assert.equal(enteroALetras(999), "novecientos noventa y nueve");
});

test("millares, con apócope de uno", () => {
  assert.equal(enteroALetras(1000), "mil");
  assert.equal(enteroALetras(1001), "mil uno");
  assert.equal(enteroALetras(2000), "dos mil");
  assert.equal(enteroALetras(21000), "veintiún mil");
  assert.equal(enteroALetras(31000), "treinta y un mil");
  assert.equal(enteroALetras(100000), "cien mil");
  assert.equal(enteroALetras(345678), "trescientos cuarenta y cinco mil seiscientos setenta y ocho");
});

test("millones", () => {
  assert.equal(enteroALetras(1_000_000), "un millón");
  assert.equal(enteroALetras(2_000_000), "dos millones");
  assert.equal(enteroALetras(1_500_000), "un millón quinientos mil");
});

test("negativos y decimales", () => {
  assert.equal(numeroALetras(-5), "menos cinco");
  assert.equal(numeroALetras(3.5), "tres coma cinco");
  assert.equal(numeroALetras(2.25), "dos coma veinticinco");
});

test("ordinales femeninos para enumerar ejercicios", () => {
  assert.equal(ordinalFemenino(1), "primera");
  assert.equal(ordinalFemenino(5), "quinta");
});
