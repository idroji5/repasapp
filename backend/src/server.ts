import { mkdir } from "node:fs/promises";
import { resolve } from "node:path";
import Fastify from "fastify";
import multipart from "@fastify/multipart";
import estatico from "@fastify/static";
import { config } from "./config.js";
import { rutasAuth } from "./rutas/auth.js";
import { rutasNinos } from "./rutas/ninos.js";
import { rutasPadres } from "./rutas/padres.js";
import { rutasSesiones } from "./rutas/sesiones.js";

/** Tope de la foto del cuaderno. La app la redimensiona antes de enviarla. */
const MAX_FOTO_BYTES = 8 * 1024 * 1024;

export async function construirServidor() {
  const app = Fastify({
    logger: { level: config.entorno === "production" ? "info" : "debug" },
    bodyLimit: 1024 * 1024,
  });

  await app.register(multipart, { limits: { fileSize: MAX_FOTO_BYTES, files: 1 } });

  // Los MP3 de la caché de voz. Son inmutables: la URL lleva el hash del texto,
  // así que se pueden cachear para siempre en el dispositivo.
  await mkdir(config.voz.cacheDir, { recursive: true });
  await app.register(estatico, {
    root: resolve(config.voz.cacheDir),
    prefix: "/audio/",
    cacheControl: true,
    maxAge: "365d",
    immutable: true,
  });

  app.get("/salud", async () => ({
    ok: true,
    voz: config.voz.activa ? "elevenlabs" : "silencio (sin clave)",
    vision: config.vision.activa ? "activa" : "desactivada (sin clave)",
  }));

  await app.register(rutasAuth);
  await app.register(rutasNinos);
  await app.register(rutasSesiones);
  await app.register(rutasPadres);

  return app;
}

if (process.argv[1]?.endsWith("server.ts") || process.argv[1]?.endsWith("server.js")) {
  const app = await construirServidor();
  await app.listen({ port: config.puerto, host: "0.0.0.0" });
}
