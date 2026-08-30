import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { pool } from "./pool.js";

const aqui = dirname(fileURLToPath(import.meta.url));

const sql = readFileSync(join(aqui, "schema.sql"), "utf8");
await pool.query(sql);
console.log("Esquema aplicado.");
await pool.end();
