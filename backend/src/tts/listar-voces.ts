/**
 * Lista las voces de la cuenta de ElevenLabs para elegir la de la app.
 *
 *   npm run tts:voces
 *
 * Busca una voz femenina en castellano (es-ES, no neutro latino): el niño tiene
 * que oír la misma variedad del idioma que le hablan en clase.
 */
import { config } from "../config.js";

if (!config.voz.apiKey) {
  console.error("Falta ELEVENLABS_API_KEY en .env");
  process.exit(1);
}

const r = await fetch("https://api.elevenlabs.io/v1/voices", {
  headers: { "xi-api-key": config.voz.apiKey },
});

if (!r.ok) {
  console.error(`ElevenLabs devolvió ${r.status}: ${await r.text()}`);
  process.exit(1);
}

const { voices } = (await r.json()) as {
  voices: { voice_id: string; name: string; labels?: Record<string, string> }[];
};

for (const v of voices) {
  const etiquetas = Object.entries(v.labels ?? {})
    .map(([k, val]) => `${k}=${val}`)
    .join(" ");
  console.log(`${v.voice_id}  ${v.name.padEnd(24)} ${etiquetas}`);
}
console.log("\nCopia el voice_id elegido a ELEVENLABS_VOICE_ID en .env");
