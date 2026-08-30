import type { Correccion, ErrorDictado } from "../correccion/alinear.js";
import type { Dictado } from "../content/dictados.js";
import { pausaSegundos } from "../content/dictados.js";
import type { Operacion } from "../content/matematicas.js";
import { explicarFalta, frases } from "../tts/frases.js";
import { espera, fragmento, habla, pedirFoto, pregunta, type Guion, type Paso } from "./guion.js";

/** Cuántas faltas se repasan de viva voz antes de que el repaso canse más de lo que enseña. */
const MAX_FALTAS_A_REPASAR = 5;

// ---------------------------------------------------------------- dictado ---

export async function guionDictado(actividadId: string, dictado: Dictado): Promise<Guion> {
  const pasos: Paso[] = [
    await habla(frases.dictadoIntro(dictado.titulo)),
    await espera(frases.prepararPapel(), ["listo"], "Estoy listo"),
    await habla(frases.empezamos()),
  ];

  for (const [i, texto] of dictado.fragmentos.entries()) {
    pasos.push(await fragmento(i, texto, pausaSegundos(texto, dictado.nivel)));
  }

  pasos.push(await pedirFoto(frases.dictadoFin()));

  return {
    actividadId,
    asignatura: "dictado",
    titulo: dictado.titulo,
    // Durante un dictado el niño tiene que poder interrumpir sin tocar nada.
    comandosGlobales: ["repite", "mas_despacio", "mas_rapido", "continua"],
    pasos,
  };
}

export async function guionRepasoDictado(
  actividadId: string,
  correccion: Correccion,
): Promise<Guion> {
  const pasos: Paso[] = [];
  const faltas = correccion.errores.slice(0, MAX_FALTAS_A_REPASAR);

  if (correccion.errores.length === 0) {
    pasos.push(await habla(frases.todoBien()));
  } else {
    const palabras = faltas.map((e) => e.esperado).filter((p) => p !== "");
    pasos.push(await habla(frases.resumenFallos(correccion.errores.length, palabras)));
    for (const falta of faltas) {
      pasos.push(await habla(explicarFalta(falta)));
    }
    if (correccion.errores.length > MAX_FALTAS_A_REPASAR) {
      pasos.push(await habla(frases.animo()));
    }
  }

  return {
    actividadId,
    asignatura: "dictado",
    titulo: "Repaso",
    comandosGlobales: ["repite", "continua"],
    pasos,
  };
}

// ------------------------------------------------------------ matemáticas ---

/**
 * Cuánto callar tras dictar una operación. Es el tiempo de *copiarla*, no el de
 * resolverla: se dictan todas primero y el niño las resuelve después a su ritmo,
 * para que el móvil no esté hablándole mientras piensa.
 */
function pausaParaCopiar(op: Operacion): number {
  return Math.round(6 + op.enunciado.length * 0.6);
}

export async function guionMatematicas(
  actividadId: string,
  operaciones: readonly Operacion[],
): Promise<Guion> {
  const pasos: Paso[] = [
    await habla(frases.matematicasIntro(operaciones.length)),
    await espera(frases.prepararPapel(), ["listo"], "Estoy listo"),
    await habla(frases.empezamos()),
  ];

  for (const op of operaciones) {
    pasos.push(
      await fragmento(op.numero - 1, frases.operacion(op.numero, op.dictado), pausaParaCopiar(op)),
    );
  }

  pasos.push(await pedirFoto(frases.matematicasFin(operaciones.length)));

  return {
    actividadId,
    asignatura: "matematicas",
    titulo: "Operaciones",
    comandosGlobales: ["repite", "mas_despacio", "continua"],
    pasos,
  };
}

export interface OperacionCorregida {
  operacion: Operacion;
  escrito: string;
  correcta: boolean;
}

/**
 * Repaso de una tanda de operaciones.
 *
 * Con `modoPistas` la voz no da la solución de entrada: suelta una pista y
 * pregunta si ya lo ve. Solo si el niño pide una segunda pista y sigue sin
 * verlo, se le da la respuesta. Es más lento y es el objetivo: quien corrige el
 * ejercicio tiene que ser el niño.
 */
export async function guionRepasoMatematicas(
  actividadId: string,
  resultados: readonly OperacionCorregida[],
  modoPistas: boolean,
): Promise<Guion> {
  const fallos = resultados.filter((r) => !r.correcta);
  const pasos: Paso[] = [];

  if (fallos.length === 0) {
    pasos.push(await habla(frases.todoBien()));
  } else {
    pasos.push(
      await habla(
        fallos.length === 1
          ? frases.casiTodoBien(1)
          : frases.resumenFallos(fallos.length, fallos.map((f) => f.operacion.enunciado)),
      ),
    );

    for (const fallo of fallos.slice(0, MAX_FALTAS_A_REPASAR)) {
      const { operacion } = fallo;
      pasos.push(await habla(frases.fallasteEn(operacion.numero)));

      if (!modoPistas) {
        pasos.push(await habla(`${frases.solucion(operacion.respuesta)} ${operacion.explicacion}`));
        continue;
      }

      pasos.push(await habla(operacion.pistas[0]));
      pasos.push(
        await pregunta(frases.loTienes(), [
          {
            comando: "lo_tengo",
            etiqueta: "Ya lo veo",
            pasos: [await habla("Muy bien. Corrígela en el cuaderno.")],
          },
          {
            comando: "otra_pista",
            etiqueta: "Otra pista",
            pasos: [
              await habla(operacion.pistas[1]),
              await pregunta(frases.loTienes(), [
                {
                  comando: "lo_tengo",
                  etiqueta: "Ya lo veo",
                  pasos: [await habla("Eso es. Corrígela en el cuaderno.")],
                },
                {
                  comando: "otra_pista",
                  etiqueta: "Dímelo",
                  pasos: [
                    await habla(`${frases.solucion(operacion.respuesta)} ${operacion.explicacion}`),
                  ],
                },
              ]),
            ],
          },
        ]),
      );
    }
  }

  return {
    actividadId,
    asignatura: "matematicas",
    titulo: "Repaso",
    comandosGlobales: ["repite", "continua"],
    pasos,
  };
}

export type { ErrorDictado };
