import { NIVEL_MAX, NIVEL_MIN, type Nivel } from "./asignaturas.js";

/** Resultado de una actividad ya corregida, de más reciente a más antigua. */
export interface ResultadoReciente {
  aciertos: number;
  total: number;
  corregidaEn: Date;
}

export interface EstadoNivel {
  nivel: Nivel;
  bloqueado: boolean;
  cambiadoEn: Date | null;
}

export interface Ajuste {
  nivelNuevo: Nivel;
  cambia: boolean;
  motivo: string;
}

/** Sube tras 3 actividades seguidas con al menos este acierto. */
const UMBRAL_SUBIDA = 0.85;
const ACTIVIDADES_PARA_SUBIR = 3;

/** Baja tras 2 actividades seguidas por debajo de este acierto. */
const UMBRAL_BAJADA = 0.5;
const ACTIVIDADES_PARA_BAJAR = 2;

/** Nunca más de un cambio de nivel por semana: los saltos bruscos desorientan. */
const DIAS_ENTRE_CAMBIOS = 7;

const MS_POR_DIA = 24 * 60 * 60 * 1000;

function porcentaje(r: ResultadoReciente): number {
  return r.total === 0 ? 0 : r.aciertos / r.total;
}

/**
 * Decide si el nivel de una asignatura debe cambiar.
 *
 * Función pura: no toca la base de datos. `recientes` debe venir ordenado de
 * más reciente a más antigua e incluir solo actividades ya corregidas de esa
 * asignatura.
 */
export function ajustarNivel(
  estado: EstadoNivel,
  recientes: readonly ResultadoReciente[],
  ahora: Date = new Date(),
): Ajuste {
  const sinCambio = (motivo: string): Ajuste => ({
    nivelNuevo: estado.nivel,
    cambia: false,
    motivo,
  });

  if (estado.bloqueado) {
    return sinCambio("nivel fijado por el padre");
  }

  if (estado.cambiadoEn) {
    const dias = (ahora.getTime() - estado.cambiadoEn.getTime()) / MS_POR_DIA;
    if (dias < DIAS_ENTRE_CAMBIOS) {
      return sinCambio("cambió hace menos de una semana");
    }
  }

  // Solo se cuentan actividades con ejercicios; una tanda vacía no dice nada.
  const validas = recientes.filter((r) => r.total > 0);

  const ultimasParaSubir = validas.slice(0, ACTIVIDADES_PARA_SUBIR);
  if (
    ultimasParaSubir.length === ACTIVIDADES_PARA_SUBIR &&
    estado.nivel < NIVEL_MAX &&
    ultimasParaSubir.every((r) => porcentaje(r) >= UMBRAL_SUBIDA)
  ) {
    return {
      nivelNuevo: (estado.nivel + 1) as Nivel,
      cambia: true,
      motivo: `${ACTIVIDADES_PARA_SUBIR} actividades seguidas por encima del ${Math.round(UMBRAL_SUBIDA * 100)}%`,
    };
  }

  const ultimasParaBajar = validas.slice(0, ACTIVIDADES_PARA_BAJAR);
  if (
    ultimasParaBajar.length === ACTIVIDADES_PARA_BAJAR &&
    estado.nivel > NIVEL_MIN &&
    ultimasParaBajar.every((r) => porcentaje(r) < UMBRAL_BAJADA)
  ) {
    return {
      nivelNuevo: (estado.nivel - 1) as Nivel,
      cambia: true,
      motivo: `${ACTIVIDADES_PARA_BAJAR} actividades seguidas por debajo del ${Math.round(UMBRAL_BAJADA * 100)}%`,
    };
  }

  return sinCambio("sin datos suficientes para cambiar");
}
