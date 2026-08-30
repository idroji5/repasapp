import pg from "pg";
import { config } from "../config.js";

export const pool = new pg.Pool({ connectionString: config.databaseUrl, max: 10 });

export async function consulta<T extends pg.QueryResultRow = pg.QueryResultRow>(
  sql: string,
  valores: unknown[] = [],
): Promise<T[]> {
  const res = await pool.query<T>(sql, valores);
  return res.rows;
}

export async function uno<T extends pg.QueryResultRow = pg.QueryResultRow>(
  sql: string,
  valores: unknown[] = [],
): Promise<T | null> {
  const filas = await consulta<T>(sql, valores);
  return filas[0] ?? null;
}

export async function enTransaccion<T>(fn: (c: pg.PoolClient) => Promise<T>): Promise<T> {
  const cliente = await pool.connect();
  try {
    await cliente.query("begin");
    const r = await fn(cliente);
    await cliente.query("commit");
    return r;
  } catch (e) {
    await cliente.query("rollback");
    throw e;
  } finally {
    cliente.release();
  }
}
