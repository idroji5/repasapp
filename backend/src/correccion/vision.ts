import Anthropic from "@anthropic-ai/sdk";
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import { z } from "zod";
import { config } from "../config.js";

/**
 * Lectura del cuaderno.
 *
 * PRIVACIDAD — la foto no se guarda en ningún sitio. Llega como buffer en
 * memoria, se codifica para la petición y se descarta al volver de esta
 * función. No se escribe en disco, no va a la base de datos, no se sube a
 * ningún almacenamiento. De cada foto solo sobrevive el resultado estructurado
 * (qué escribió el niño), y ese es el único dato que se conserva.
 *
 * Sobre el reconocimiento: ML Kit y compañía no leen caligrafía infantil de
 * forma fiable —están hechos para texto impreso—. Lo que hace viable esto es
 * que ya sabemos qué debería haber escrito: pasarle el texto de referencia al
 * modelo convierte "descifrar la letra de un niño de nueve años" en "comparar
 * contra un texto conocido", que es un problema muchísimo más tratable.
 */

const MODELO = "claude-opus-5";

const TIPOS_ACEPTADOS = ["image/jpeg", "image/png", "image/webp"] as const;
export type TipoImagen = (typeof TIPOS_ACEPTADOS)[number];

export function esTipoAceptado(tipo: string): tipo is TipoImagen {
  return (TIPOS_ACEPTADOS as readonly string[]).includes(tipo);
}

let cliente: Anthropic | null = null;
function anthropic(): Anthropic {
  cliente ??= new Anthropic({ apiKey: config.vision.apiKey });
  return cliente;
}

/**
 * La instrucción que más importa de todo el fichero: el modelo debe transcribir
 * las faltas, no arreglarlas. Su reflejo natural es normalizar la ortografía, y
 * si lo hace la app corrige un dictado perfecto que el niño no ha escrito.
 */
const SISTEMA = `Eres un transcriptor de cuadernos escolares de Primaria.

Tu única tarea es escribir EXACTAMENTE lo que hay en el papel, letra por letra.

Reglas absolutas:
- NO corrijas la ortografía. Si el niño escribió "avia", transcribe "avia".
- NO añadas tildes que no estén escritas. Si escribió "habia", transcribe "habia".
- NO completes palabras ni frases que falten.
- Respeta mayúsculas y minúsculas tal y como están escritas.
- Transcribe la puntuación que veas, y solo la que veas.
- Si una palabra es ilegible, escríbela entre corchetes: [ilegible].

Se te dará el texto que se le dictó al niño. Úsalo ÚNICAMENTE para orientarte
sobre dónde empieza y acaba cada palabra cuando la letra sea difícil. NO lo
copies: si lo que hay escrito difiere del texto de referencia, gana siempre lo
que hay escrito. Encontrar diferencias es el objetivo, no un problema.`;

const EsquemaDictado = z.object({
  legible: z.boolean().describe("false si la foto está borrosa, cortada o vacía"),
  transcripcion: z.string().describe("Lo escrito en el papel, tal cual, con sus faltas"),
  confianza: z.enum(["alta", "media", "baja"]),
  aviso: z
    .string()
    .describe("Problema con la foto que convenga decirle al niño, o cadena vacía"),
});

export type LecturaDictado = z.infer<typeof EsquemaDictado>;

const EsquemaMatematicas = z.object({
  legible: z.boolean(),
  ejercicios: z.array(
    z.object({
      numero: z.number().int().describe("Número de ejercicio, empezando en 1"),
      encontrado: z.boolean().describe("false si ese ejercicio no aparece en la hoja"),
      operacionEscrita: z.string().describe("La operación tal y como la copió el niño"),
      resultadoEscrito: z.string().describe("El resultado al que llegó, solo el número"),
    }),
  ),
  aviso: z.string(),
});

export type LecturaMatematicas = z.infer<typeof EsquemaMatematicas>;

export class VisionNoConfigurada extends Error {
  constructor() {
    super("Falta ANTHROPIC_API_KEY: la corrección por foto está desactivada");
    this.name = "VisionNoConfigurada";
  }
}

export class FotoIlegible extends Error {
  constructor(public readonly aviso: string) {
    super(aviso);
    this.name = "FotoIlegible";
  }
}

function bloqueImagen(foto: Buffer, tipo: TipoImagen) {
  return {
    type: "image" as const,
    source: { type: "base64" as const, media_type: tipo, data: foto.toString("base64") },
  };
}

/**
 * Los clasificadores de seguridad pueden declinar una petición devolviendo 200
 * con `stop_reason: "refusal"`. En una hoja de deberes es improbable, pero si
 * pasa hay que tratarlo como foto no legible en vez de romper la sesión del niño.
 */
function comprobarNegativa(stopReason: string | null): void {
  if (stopReason === "refusal") {
    throw new FotoIlegible("No he podido leer esta foto. Vamos a hacer otra.");
  }
}

/** Transcribe un dictado escrito a mano. La foto se descarta al terminar. */
export async function leerDictado(
  foto: Buffer,
  tipo: TipoImagen,
  textoDictado: string,
): Promise<LecturaDictado> {
  if (!config.vision.activa) throw new VisionNoConfigurada();

  const respuesta = await anthropic().messages.parse({
    model: MODELO,
    max_tokens: 4000,
    system: SISTEMA,
    thinking: { type: "adaptive" },
    output_config: { format: zodOutputFormat(EsquemaDictado), effort: "high" },
    messages: [
      {
        role: "user",
        content: [
          bloqueImagen(foto, tipo),
          {
            type: "text",
            text: `Texto que se le dictó (solo como referencia de dónde separar las palabras):\n\n${textoDictado}\n\nTranscribe lo que hay escrito en la foto.`,
          },
        ],
      },
    ],
  });

  comprobarNegativa(respuesta.stop_reason);
  const lectura = respuesta.parsed_output;
  if (!lectura) throw new FotoIlegible("No he entendido la foto. Prueba otra vez.");
  if (!lectura.legible) throw new FotoIlegible(lectura.aviso || "La foto no se ve bien.");
  return lectura;
}

/** Lee una tanda de operaciones resueltas. La foto se descarta al terminar. */
export async function leerMatematicas(
  foto: Buffer,
  tipo: TipoImagen,
  enunciados: readonly string[],
): Promise<LecturaMatematicas> {
  if (!config.vision.activa) throw new VisionNoConfigurada();

  const listado = enunciados.map((e, i) => `${i + 1}. ${e}`).join("\n");

  const respuesta = await anthropic().messages.parse({
    model: MODELO,
    max_tokens: 4000,
    system: SISTEMA,
    thinking: { type: "adaptive" },
    output_config: { format: zodOutputFormat(EsquemaMatematicas), effort: "high" },
    messages: [
      {
        role: "user",
        content: [
          bloqueImagen(foto, tipo),
          {
            type: "text",
            text:
              `Operaciones que se le dictaron:\n${listado}\n\n` +
              "Para cada una, dime la operación que copió el niño y el resultado al " +
              "que llegó. Si copió mal la operación, transcribe lo que copió: copiar " +
              "mal el enunciado también es un error que hay que detectar. Si un " +
              "ejercicio no está en la hoja, marca encontrado como false.",
          },
        ],
      },
    ],
  });

  comprobarNegativa(respuesta.stop_reason);
  const lectura = respuesta.parsed_output;
  if (!lectura) throw new FotoIlegible("No he entendido la foto. Prueba otra vez.");
  if (!lectura.legible) throw new FotoIlegible(lectura.aviso || "La foto no se ve bien.");
  return lectura;
}
