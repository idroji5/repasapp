import type { Nivel } from "../domain/asignaturas.js";
import { apropiadoParaCurso } from "../domain/curriculo.js";

/**
 * Banco de dictados revisados a mano.
 *
 * Aquí NO genera texto la IA. Un modelo de lenguaje generando dictados en vivo
 * acabaría colando una tilde mal o una palabra impropia para la edad, y ese
 * error va derecho al cuaderno del niño. La IA selecciona y adapta lo que ya
 * está revisado; escribir el texto es trabajo humano.
 *
 * Objetivo de contenido para producción: ~30 textos por nivel. Los de abajo son
 * la semilla inicial.
 */
export interface Dictado {
  id: string;
  titulo: string;
  nivel: Nivel;
  /** Qué microdestrezas ejercita. Determina para qué cursos es apropiado. */
  destrezas: string[];
  /** Unidades de dictado: la voz dice una, calla, y espera a que el niño escriba. */
  fragmentos: string[];
  /** Palabras trampa. Si el niño falla alguna, la app la repasa al terminar. */
  palabrasClave: string[];
}

export const DICTADOS: readonly Dictado[] = [
  // ------------------------------------------------------------- nivel 1 ---
  {
    id: "dic-101",
    titulo: "En el campo",
    nivel: 1,
    destrezas: ["mayuscula_inicial", "punto_final", "m_antes_p_b", "c_qu"],
    fragmentos: [
      "Mi abuelo vive en el campo.",
      "Tiene un perro pequeño.",
      "Siempre come pan con queso.",
      "El campo es muy bonito.",
    ],
    palabrasClave: ["campo", "siempre", "pequeño", "queso"],
  },
  {
    id: "dic-102",
    titulo: "Mi casa",
    nivel: 1,
    destrezas: ["mayuscula_inicial", "punto_final", "m_antes_p_b", "c_qu"],
    fragmentos: [
      "Mi casa tiene cuatro ventanas.",
      "En la cocina hay una mesa pequeña.",
      "Mi hermano juega bajo la sombra.",
      "Come una manzana con queso.",
    ],
    palabrasClave: ["cuatro", "pequeña", "sombra", "queso"],
  },
  {
    id: "dic-103",
    titulo: "El colegio",
    nivel: 1,
    destrezas: ["mayuscula_inicial", "punto_final", "m_antes_p_b", "c_qu"],
    fragmentos: [
      "Cada mañana voy al colegio.",
      "Llevo un cuaderno y una goma.",
      "Mi maestra se llama Carmen.",
      "Siempre jugamos en el patio.",
    ],
    palabrasClave: ["cuaderno", "maestra", "siempre", "colegio"],
  },

  // ------------------------------------------------------------- nivel 2 ---
  {
    id: "dic-201",
    titulo: "El perro de Rosa",
    nivel: 2,
    destrezas: ["mayuscula_inicial", "punto_final", "r_rr", "h_frecuente", "interrogacion_exclamacion"],
    fragmentos: [
      "Rosa tiene un perro negro.",
      "Hoy hemos ido al parque.",
      "El perro corre entre la hierba.",
      "¿Quieres jugar con nosotros?",
    ],
    palabrasClave: ["perro", "hoy", "hemos", "hierba", "corre"],
  },
  {
    id: "dic-202",
    titulo: "La guitarra",
    nivel: 2,
    destrezas: ["mayuscula_inicial", "punto_final", "r_rr", "h_frecuente", "g_gu", "interrogacion_exclamacion"],
    fragmentos: [
      "Mi hermano toca la guitarra.",
      "Hoy hay una fiesta en el barrio.",
      "¡Suena muy bien!",
      "Todos hemos bailado juntos.",
    ],
    palabrasClave: ["hermano", "guitarra", "hoy", "hay", "barrio", "hemos"],
  },
  {
    id: "dic-203",
    titulo: "El gato gordo",
    nivel: 2,
    destrezas: ["mayuscula_inicial", "punto_final", "r_rr", "h_frecuente", "g_gu", "m_antes_p_b"],
    fragmentos: [
      "El gato gordo duerme en la alfombra.",
      "Una mosca vuela por la cocina.",
      "¿Se ha escondido en el armario?",
      "Hoy no la hemos visto.",
    ],
    palabrasClave: ["gordo", "alfombra", "escondido", "hemos", "hoy"],
  },

  // ------------------------------------------------------------- nivel 3 ---
  {
    id: "dic-301",
    titulo: "La excursión",
    nivel: 3,
    destrezas: ["tilde_agudas", "b_verbos_aba", "coma_enumeracion", "mayuscula_inicial"],
    fragmentos: [
      "El domingo fuimos de excursión al campo.",
      "Llevaba bocadillos, fruta, agua y una manta.",
      "Mi hermano jugaba con un balón.",
      "Después merendamos junto a la fuente.",
      "Volvimos muy cansados.",
    ],
    palabrasClave: ["excursión", "llevaba", "jugaba", "después", "balón"],
  },
  {
    id: "dic-302",
    titulo: "La tormenta",
    nivel: 3,
    destrezas: ["tilde_agudas", "ll_y", "coma_enumeracion", "mayuscula_inicial"],
    fragmentos: [
      "Ayer cayó una tormenta muy fuerte.",
      "Mi madre cerró la ventana del salón.",
      "Nosotros jugamos a las cartas, al parchís y al dominó.",
      "Cuando escampó, salimos a la calle.",
    ],
    palabrasClave: ["cayó", "cerró", "salón", "parchís", "dominó", "escampó"],
  },
  {
    id: "dic-303",
    titulo: "Los domingos de mi abuela",
    nivel: 3,
    destrezas: ["b_verbos_aba", "tilde_agudas", "coma_enumeracion", "ll_y"],
    fragmentos: [
      "Mi abuela cocinaba todos los domingos.",
      "Preparaba arroz, ensalada, pollo y flan.",
      "Nos llamaba desde la ventana.",
      "Después tomamos el postre en el jardín.",
    ],
    palabrasClave: ["cocinaba", "preparaba", "llamaba", "pollo", "jardín", "después"],
  },

  // ------------------------------------------------------------- nivel 4 ---
  {
    id: "dic-401",
    titulo: "El pingüino",
    nivel: 4,
    destrezas: ["dieresis", "tilde_esdrujulas", "g_j", "tilde_llanas"],
    fragmentos: [
      "El pingüino vive en lugares muy fríos.",
      "Es un animal tranquilo y simpático.",
      "Nada rapidísimo debajo del agua.",
      "Su plumaje parece un traje elegante.",
      "Nunca se queja del frío.",
    ],
    palabrasClave: ["pingüino", "simpático", "rapidísimo", "plumaje", "queja"],
  },
  {
    id: "dic-402",
    titulo: "El árbol del jardín",
    nivel: 4,
    destrezas: ["tilde_llanas", "tilde_esdrujulas", "g_j", "mayuscula_inicial"],
    fragmentos: [
      "En el jardín hay un árbol muy antiguo.",
      "Sus ramas dan una sombra agradable.",
      "Los pájaros hacen allí su nido.",
      "Es el lugar más tranquilo de la casa.",
    ],
    palabrasClave: ["jardín", "árbol", "agradable", "pájaros", "allí"],
  },
  {
    id: "dic-403",
    titulo: "La bicicleta nueva",
    nivel: 4,
    destrezas: ["tilde_esdrujulas", "v_adjetivos", "g_j", "tilde_agudas"],
    fragmentos: [
      "Mi primo tiene una bicicleta ligera.",
      "El sábado bajamos juntos al parque.",
      "Aprendió a frenar rápidamente.",
      "Ahora es un chico muy activo y deportivo.",
    ],
    palabrasClave: ["ligera", "sábado", "aprendió", "rápidamente", "activo", "deportivo"],
  },

  // ------------------------------------------------------------- nivel 5 ---
  {
    id: "dic-501",
    titulo: "La carta",
    nivel: 5,
    destrezas: ["tilde_diacritica", "homofonos", "porque", "x_s", "b_v_reglas"],
    fragmentos: [
      "Ayer recibí una carta tuya.",
      "Me preguntabas por qué no había ido.",
      "Sí, tenía muchas ganas de verte.",
      "Pero tú sabes que el examen era difícil.",
      "Ahí está la razón de mi silencio.",
    ],
    palabrasClave: ["recibí", "por qué", "había", "sí", "tú", "ahí", "examen"],
  },
  {
    id: "dic-502",
    titulo: "El día del examen",
    nivel: 5,
    destrezas: ["hiato", "b_v_reglas", "porque", "tilde_diacritica"],
    fragmentos: [
      "Aquel día me levanté muy temprano.",
      "No sabía si había estudiado bastante.",
      "Mi hermana me dijo que no me preocupara.",
      "Cuando salí, sonreía porque todo había salido bien.",
    ],
    palabrasClave: ["día", "sabía", "había", "sonreía", "porque", "si"],
  },
  {
    id: "dic-503",
    titulo: "A ver qué pasa",
    nivel: 5,
    destrezas: ["homofonos", "tilde_diacritica", "b_v_reglas", "interrogacion_exclamacion"],
    fragmentos: [
      "Vamos a ver si hay entradas para el concierto.",
      "Ahí mismo, en la taquilla, lo sabremos.",
      "Debe de haber mucha gente esperando.",
      "¡Ay, ojalá queden algunas!",
    ],
    palabrasClave: ["a ver", "hay", "ahí", "haber", "ay", "ojalá"],
  },
];

const POR_ID = new Map(DICTADOS.map((d) => [d.id, d]));

export function dictadoPorId(id: string): Dictado | undefined {
  return POR_ID.get(id);
}

export function textoCompleto(d: Dictado): string {
  return d.fragmentos.join(" ");
}

export function numeroDePalabras(d: Dictado): number {
  return textoCompleto(d).split(/\s+/).filter(Boolean).length;
}

/**
 * Cuánto callar tras un fragmento para que al niño le dé tiempo a escribirlo.
 * Un niño de nivel 1 escribe bastante más despacio que uno de nivel 5, así que
 * la pausa no es fija: depende del número de palabras y del nivel.
 */
export function pausaSegundos(fragmento: string, nivel: Nivel): number {
  const palabras = fragmento.split(/\s+/).filter(Boolean).length;
  const segundosPorPalabra = nivel <= 2 ? 2.4 : nivel <= 3 ? 2.0 : 1.6;
  return Math.round(palabras * segundosPorPalabra + 1.5);
}

/** Duración estimada de la actividad completa, para encajarla en la sesión diaria. */
export function duracionEstimadaSegundos(d: Dictado): number {
  const dictando = d.fragmentos.reduce(
    (t, f) => t + pausaSegundos(f, d.nivel) + f.split(/\s+/).length * 0.6,
    0,
  );
  return Math.round(dictando + 40); // + preparación y foto
}

/**
 * Elige un dictado del nivel pedido que además sea apropiado para el curso.
 * `yaHechos` evita repetir; si no queda ninguno sin hacer, se recicla el más
 * antiguo antes que dejar al niño sin actividad.
 */
export function elegirDictado(
  nivel: Nivel,
  curso: number,
  yaHechos: readonly string[] = [],
): Dictado | undefined {
  const apropiados = DICTADOS.filter(
    (d) => d.nivel === nivel && apropiadoParaCurso(d.destrezas, curso),
  );
  if (apropiados.length === 0) {
    // Sin material del nivel exacto, se baja un escalón antes que fallar.
    return nivel > 1 ? elegirDictado((nivel - 1) as Nivel, curso, yaHechos) : undefined;
  }
  const nuevos = apropiados.filter((d) => !yaHechos.includes(d.id));
  const candidatos = nuevos.length > 0 ? nuevos : apropiados;
  return candidatos[Math.floor(Math.random() * candidatos.length)];
}
