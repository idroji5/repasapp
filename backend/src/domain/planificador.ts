import { ASIGNATURAS, type Asignatura, type Nivel } from "./asignaturas.js";
import { destrezasHasta } from "./curriculo.js";
import { DESTREZAS_CON_PLANTILLA } from "../content/matematicas.js";
import { duracionEstimadaSegundos, elegirDictado } from "../content/dictados.js";

/**
 * "Quince minutos al día" → una sesión concreta.
 *
 * Este es el corazón del producto: la retención de una app infantil de estudio
 * se juega en que el niño abra la app y ya tenga el plan hecho, no en el tamaño
 * del catálogo de ejercicios.
 */

export interface ContextoPlan {
  curso: number;
  minutosDiarios: number;
  niveles: Record<Asignatura, Nivel>;
  /** Dictados ya hechos, para no repetirlos. */
  dictadosHechos: readonly string[];
  /** Destrezas con más fallos recientes: son las que hay que trabajar. */
  destrezasFlojas: readonly string[];
  /** Asignatura de la última sesión, para no empezar siempre por la misma. */
  ultimaAsignatura: Asignatura | null;
}

export interface ActividadPlanificada {
  asignatura: Asignatura;
  nivel: Nivel;
  /** Se guarda tal cual en `actividades.contenido`. */
  contenido: Record<string, unknown>;
  duracionEstimadaSegundos: number;
}

/** Operaciones por tanda. Cinco es lo que cabe en una hoja y en la cabeza. */
const OPERACIONES_POR_TANDA = 5;
const SEGUNDOS_POR_OPERACION = 55;

/** Por debajo de esto no cabe ninguna actividad que valga la pena. */
const MINIMO_UTIL_SEGUNDOS = 100;
const MAX_ACTIVIDADES = 3;

function rotacion(ultima: Asignatura | null): Asignatura[] {
  const todas = [...ASIGNATURAS];
  if (ultima === null) return todas;
  // Se empieza por la que NO tocó ayer.
  return [...todas.filter((a) => a !== ultima), ...todas.filter((a) => a === ultima)];
}

function planificarMatematicas(
  ctx: ContextoPlan,
  segundosDisponibles: number,
): ActividadPlanificada | null {
  const delCurso = destrezasHasta(ctx.curso, "matematicas")
    .map((d) => d.id)
    .filter((id) => DESTREZAS_CON_PLANTILLA.includes(id));
  if (delCurso.length === 0) return null;

  // Las destrezas flojas van primero; el resto rellena.
  const flojas = delCurso.filter((id) => ctx.destrezasFlojas.includes(id));
  const resto = delCurso.filter((id) => !ctx.destrezasFlojas.includes(id));
  // Las dos últimas del curso son las más avanzadas: son las que toca practicar.
  const elegidas = [...flojas, ...resto.slice(-2)].slice(0, 2);

  const cuantas = Math.min(
    OPERACIONES_POR_TANDA,
    Math.floor(segundosDisponibles / SEGUNDOS_POR_OPERACION),
  );
  if (cuantas < 2) return null;

  return {
    asignatura: "matematicas",
    nivel: ctx.niveles.matematicas,
    contenido: {
      tipo: "tanda_operaciones",
      destrezas: elegidas,
      cuantas,
      // La semilla se guarda para reconstruir exactamente la misma tanda al corregir.
      semilla: Math.floor(Math.random() * 2 ** 31),
    },
    duracionEstimadaSegundos: cuantas * SEGUNDOS_POR_OPERACION,
  };
}

function planificarDictado(
  ctx: ContextoPlan,
  segundosDisponibles: number,
): ActividadPlanificada | null {
  const dictado = elegirDictado(ctx.niveles.dictado, ctx.curso, ctx.dictadosHechos);
  if (!dictado) return null;

  const duracion = duracionEstimadaSegundos(dictado);
  if (duracion > segundosDisponibles * 1.3) return null; // margen: un dictado no se parte

  return {
    asignatura: "dictado",
    nivel: ctx.niveles.dictado,
    contenido: { tipo: "dictado", dictadoId: dictado.id },
    duracionEstimadaSegundos: duracion,
  };
}

export function planificarSesion(ctx: ContextoPlan): ActividadPlanificada[] {
  let restante = ctx.minutosDiarios * 60;
  const plan: ActividadPlanificada[] = [];
  const orden = rotacion(ctx.ultimaAsignatura);

  for (let vuelta = 0; vuelta < 2 && plan.length < MAX_ACTIVIDADES; vuelta++) {
    for (const asignatura of orden) {
      if (restante < MINIMO_UTIL_SEGUNDOS || plan.length >= MAX_ACTIVIDADES) break;

      const actividad =
        asignatura === "dictado"
          ? planificarDictado(ctx, restante)
          : planificarMatematicas(ctx, restante);

      if (actividad) {
        plan.push(actividad);
        restante -= actividad.duracionEstimadaSegundos;
      }
    }
  }
  return plan;
}
