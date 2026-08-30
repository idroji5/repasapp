import "dotenv/config";

function requerido(nombre: string, pordefecto?: string): string {
  const v = process.env[nombre] ?? pordefecto;
  if (v === undefined || v === "") {
    throw new Error(`Falta la variable de entorno ${nombre}. Copia .env.example a .env.`);
  }
  return v;
}

export const config = {
  puerto: Number(process.env.PORT ?? 3000),
  entorno: process.env.NODE_ENV ?? "development",
  jwtSecret: requerido("JWT_SECRET", "secreto-de-desarrollo-no-usar-en-produccion"),
  databaseUrl: requerido("DATABASE_URL", "postgres://repasapp:repasapp@localhost:5433/repasapp"),

  voz: {
    apiKey: process.env.ELEVENLABS_API_KEY ?? "",
    voiceId: process.env.ELEVENLABS_VOICE_ID ?? "",
    modelId: process.env.ELEVENLABS_MODEL_ID ?? "eleven_multilingual_v2",
    cacheDir: process.env.AUDIO_CACHE_DIR ?? "./data/audio",
    /** Sin clave el servidor sigue funcionando y sirve MP3 silenciosos. */
    get activa() {
      return this.apiKey !== "" && this.voiceId !== "";
    },
  },

  vision: {
    apiKey: process.env.ANTHROPIC_API_KEY ?? "",
    get activa() {
      return this.apiKey !== "";
    },
  },
} as const;
