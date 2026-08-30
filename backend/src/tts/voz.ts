import { createHash } from "node:crypto";
import { mkdir, writeFile, access } from "node:fs/promises";
import { join } from "node:path";
import { config } from "../config.js";

/**
 * Voz de la app: femenina, castellana, siempre la misma.
 *
 * Nada se sintetiza en el momento de reproducirlo. Cada frase se genera una vez,
 * se guarda como MP3 y a partir de ahí se sirve del disco. Las consecuencias
 * importan: el audio suena al instante, funciona sin cobertura, el coste de TTS
 * tiende a cero según crece la base de usuarios, y —lo que de verdad importa en
 * un dictado— cuando el niño dice "repite" oye exactamente lo mismo que oyó la
 * primera vez, no una síntesis nueva con otra entonación.
 */

export type Velocidad = "lenta" | "normal" | "rapida";

/**
 * La velocidad se hornea en el MP3 en lugar de acelerar el reproductor: cambiar
 * la velocidad de reproducción distorsiona el tono y la voz deja de sonar humana,
 * que es justo lo contrario de lo que queremos.
 */
const FACTOR_VELOCIDAD: Record<Velocidad, number> = {
  lenta: 0.8,
  normal: 1.0,
  rapida: 1.15,
};

const API = "https://api.elevenlabs.io/v1";

function clave(texto: string, velocidad: Velocidad): string {
  return createHash("sha256")
    .update(`${config.voz.voiceId}|${config.voz.modelId}|${velocidad}|${texto}`)
    .digest("hex")
    .slice(0, 32);
}

async function existe(ruta: string): Promise<boolean> {
  try {
    await access(ruta);
    return true;
  } catch {
    return false;
  }
}

// ------------------------------------------------- MP3 de silencio (dev) ---

/**
 * Sin clave de ElevenLabs se sirve un MP3 silencioso de la duración estimada.
 * Permite desarrollar y probar la app entera —tiempos, pausas, navegación— sin
 * gastar un solo crédito de síntesis.
 */
function mp3Silencioso(segundos: number): Buffer {
  // Cabecera MPEG-1 Layer III, 128 kbps, 44,1 kHz: cada trama dura 1152/44100 s.
  const cabecera = Buffer.from([0xff, 0xfb, 0x90, 0x64]);
  const trama = Buffer.concat([cabecera, Buffer.alloc(417 - cabecera.length)]);
  const tramas = Math.max(1, Math.ceil(segundos / (1152 / 44100)));
  return Buffer.concat(Array.from({ length: tramas }, () => trama));
}

/** Cuánto dura leer un texto en voz alta, para dimensionar el silencio y las pausas. */
export function duracionEstimada(texto: string, velocidad: Velocidad = "normal"): number {
  const palabras = texto.split(/\s+/).filter(Boolean).length;
  return (palabras / 2.6 + 0.5) / FACTOR_VELOCIDAD[velocidad];
}

// ------------------------------------------------------------- síntesis ---

async function sintetizar(texto: string, velocidad: Velocidad): Promise<Buffer> {
  const respuesta = await fetch(
    `${API}/text-to-speech/${config.voz.voiceId}?output_format=mp3_44100_128`,
    {
      method: "POST",
      headers: {
        "xi-api-key": config.voz.apiKey,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        text: texto,
        model_id: config.voz.modelId,
        voice_settings: {
          stability: 0.5,
          similarity_boost: 0.75,
          // Un punto de expresividad: la voz debe sonar a persona que enseña,
          // no a locutor de aeropuerto.
          style: 0.2,
          speed: FACTOR_VELOCIDAD[velocidad],
        },
      }),
    },
  );

  if (!respuesta.ok) {
    const detalle = await respuesta.text().catch(() => "");
    throw new Error(`ElevenLabs devolvió ${respuesta.status}: ${detalle.slice(0, 300)}`);
  }
  return Buffer.from(await respuesta.arrayBuffer());
}

/** Peticiones en vuelo, para no sintetizar dos veces la misma frase a la vez. */
const enCurso = new Map<string, Promise<string>>();

/**
 * Devuelve la URL del audio de un texto, generándolo solo si no estaba en caché.
 * La URL es estable: el mismo texto y la misma velocidad dan siempre la misma.
 */
export async function audioDe(texto: string, velocidad: Velocidad = "normal"): Promise<string> {
  const hash = clave(texto, velocidad);
  const nombre = `${hash}.mp3`;
  const url = `/audio/${nombre}`;

  const pendiente = enCurso.get(hash);
  if (pendiente) return pendiente;

  const trabajo = (async () => {
    const ruta = join(config.voz.cacheDir, nombre);
    if (await existe(ruta)) return url;

    await mkdir(config.voz.cacheDir, { recursive: true });
    const audio = config.voz.activa
      ? await sintetizar(texto, velocidad)
      : mp3Silencioso(duracionEstimada(texto, velocidad));
    await writeFile(ruta, audio);
    return url;
  })().finally(() => enCurso.delete(hash));

  enCurso.set(hash, trabajo);
  return trabajo;
}

/** Genera las tres velocidades de un mismo texto (las que usa el dictado). */
export async function audioEnTresVelocidades(
  texto: string,
): Promise<Record<Velocidad, string>> {
  const [lenta, normal, rapida] = await Promise.all([
    audioDe(texto, "lenta"),
    audioDe(texto, "normal"),
    audioDe(texto, "rapida"),
  ]);
  return { lenta, normal, rapida };
}
