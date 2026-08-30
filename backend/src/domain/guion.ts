import type { Asignatura } from "./asignaturas.js";
import { audioDe, audioEnTresVelocidades, type Velocidad } from "../tts/voz.js";

/**
 * El guion es la unidad de comunicación entre backend y app.
 *
 * La app es un reproductor tonto: recibe una lista de pasos con su audio ya
 * generado y los ejecuta. Toda la pedagogía —qué se dice, en qué orden, cuánto
 * se calla, cuándo se pide una foto— vive en el servidor. Cambiar cómo enseña
 * la app no exige publicar una versión nueva en las tiendas.
 */

export type Comando =
  | "listo"
  | "repite"
  | "mas_despacio"
  | "mas_rapido"
  | "continua"
  | "lo_tengo"
  | "otra_pista";

export type Paso =
  /** La voz dice algo y sigue. */
  | { tipo: "habla"; texto: string; audio: string }
  /**
   * Un trozo de dictado. Viene en las tres velocidades para que "más despacio"
   * sea instantáneo y no haya que volver al servidor.
   */
  | {
      tipo: "fragmento";
      indice: number;
      texto: string;
      audio: Record<Velocidad, string>;
      pausaSegundos: number;
    }
  /** Se para hasta que el niño diga uno de los comandos (o pulse el botón). */
  | { tipo: "espera"; texto: string; audio: string; comandos: Comando[]; etiquetaBoton: string }
  /** Bifurcación sencilla: según lo que conteste, se reproduce una rama u otra. */
  | {
      tipo: "pregunta";
      texto: string;
      audio: string;
      opciones: { comando: Comando; etiqueta: string; pasos: Paso[] }[];
    }
  /** Pide la foto del cuaderno y termina el guion. */
  | { tipo: "foto"; texto: string; audio: string };

export interface Guion {
  actividadId: string;
  asignatura: Asignatura;
  titulo: string;
  /** Comandos que el niño puede decir en cualquier momento del guion. */
  comandosGlobales: Comando[];
  pasos: Paso[];
}

// ------------------------------------------------------- constructores ---

export async function habla(texto: string): Promise<Paso> {
  return { tipo: "habla", texto, audio: await audioDe(texto) };
}

export async function espera(
  texto: string,
  comandos: Comando[],
  etiquetaBoton: string,
): Promise<Paso> {
  return { tipo: "espera", texto, audio: await audioDe(texto), comandos, etiquetaBoton };
}

export async function fragmento(
  indice: number,
  texto: string,
  pausaSegundos: number,
): Promise<Paso> {
  return {
    tipo: "fragmento",
    indice,
    texto,
    audio: await audioEnTresVelocidades(texto),
    pausaSegundos,
  };
}

export async function pedirFoto(texto: string): Promise<Paso> {
  return { tipo: "foto", texto, audio: await audioDe(texto) };
}

export async function pregunta(
  texto: string,
  opciones: { comando: Comando; etiqueta: string; pasos: Paso[] }[],
): Promise<Paso> {
  return { tipo: "pregunta", texto, audio: await audioDe(texto), opciones };
}
