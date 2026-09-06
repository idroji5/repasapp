import 'dart:math';

import '../dominio/curriculo.dart';

/// Banco de dictados revisados a mano.
///
/// Objetivo de contenido para producción: ~30 textos por nivel. Los de abajo son
/// la semilla inicial, escritos cuidando que ningún texto exija una regla que
/// todavía no le han explicado al niño en clase.
class Dictado {
  const Dictado({
    required this.id,
    required this.titulo,
    required this.nivel,
    required this.destrezas,
    required this.fragmentos,
    required this.palabrasClave,
  });

  final String id;
  final String titulo;
  final int nivel;

  /// Qué microdestrezas ejercita. Determina para qué cursos es apropiado.
  final List<String> destrezas;

  /// Unidades de dictado: la voz dice una, calla, y espera a que el niño escriba.
  final List<String> fragmentos;

  /// Palabras trampa. Si el niño falla alguna, la app la repasa al terminar.
  final List<String> palabrasClave;

  String get texto => fragmentos.join(' ');

  int get numeroDePalabras =>
      texto.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).length;
}

const List<Dictado> dictados = [
  // ------------------------------------------------------------- nivel 1 ---
  Dictado(
    id: 'dic-101',
    titulo: 'En el campo',
    nivel: 1,
    destrezas: ['mayuscula_inicial', 'punto_final', 'm_antes_p_b', 'c_qu'],
    fragmentos: [
      'Mi abuelo vive en el campo.',
      'Tiene un perro pequeño.',
      'Siempre come pan con queso.',
      'El campo es muy bonito.',
    ],
    palabrasClave: ['campo', 'siempre', 'pequeño', 'queso'],
  ),
  Dictado(
    id: 'dic-102',
    titulo: 'Mi casa',
    nivel: 1,
    destrezas: ['mayuscula_inicial', 'punto_final', 'm_antes_p_b', 'c_qu'],
    fragmentos: [
      'Mi casa tiene cuatro ventanas.',
      'En la cocina hay una mesa pequeña.',
      'Mi hermano juega bajo la sombra.',
      'Come una manzana con queso.',
    ],
    palabrasClave: ['cuatro', 'pequeña', 'sombra', 'queso'],
  ),
  Dictado(
    id: 'dic-103',
    titulo: 'El colegio',
    nivel: 1,
    destrezas: ['mayuscula_inicial', 'punto_final', 'm_antes_p_b', 'c_qu'],
    fragmentos: [
      'Cada mañana voy al colegio.',
      'Llevo un cuaderno y una goma.',
      'Mi maestra se llama Carmen.',
      'Siempre jugamos en el patio.',
    ],
    palabrasClave: ['cuaderno', 'Carmen', 'siempre', 'colegio'],
  ),


  Dictado(
    id: 'dic-104',
    titulo: 'El cumpleaños de Quique',
    nivel: 1,
    destrezas: ['mayuscula_inicial', 'punto_final', 'm_antes_p_b', 'c_qu'],
    fragmentos: [
      'Hoy es el cumpleaños de Quique.',
      'Su madre ha comprado una tarta.',
      'Vamos a comer bombones y queso.',
      'Todos cantamos muy contentos.',
    ],
    palabrasClave: ['Quique', 'comprado', 'bombones', 'queso'],
  ),
  Dictado(
    id: 'dic-105',
    titulo: 'El campo de fútbol',
    nivel: 1,
    destrezas: ['mayuscula_inicial', 'punto_final', 'm_antes_p_b', 'c_qu'],
    fragmentos: [
      'Los sábados juego en el campo.',
      'Mi equipo lleva camiseta blanca.',
      'Siempre marco un gol.',
      'Luego bebemos mucha agua.',
    ],
    palabrasClave: ['campo', 'equipo', 'camiseta', 'siempre'],
  ),
  Dictado(
    id: 'dic-106',
    titulo: 'La cocina',
    nivel: 1,
    destrezas: ['mayuscula_inicial', 'punto_final', 'm_antes_p_b', 'c_qu'],
    fragmentos: [
      'En la cocina huele muy bien.',
      'Mi abuela prepara un caldo.',
      'Yo pongo la mesa con cuidado.',
      'Comemos todos juntos.',
    ],
    palabrasClave: ['cocina', 'caldo', 'cuidado', 'Comemos'],
  ),
  Dictado(
    id: 'dic-107',
    titulo: 'El parque',
    nivel: 1,
    destrezas: ['mayuscula_inicial', 'punto_final', 'm_antes_p_b', 'c_qu'],
    fragmentos: [
      'Cada tarde bajo al parque.',
      'Me subo al tobogán con Marta.',
      'Ella lleva un cubo pequeño.',
      'Jugamos hasta que anochece.',
    ],
    palabrasClave: ['parque', 'Marta', 'cubo', 'pequeño'],
  ),
  Dictado(
    id: 'dic-108',
    titulo: 'Mi cuarto',
    nivel: 1,
    destrezas: ['mayuscula_inicial', 'punto_final', 'm_antes_p_b', 'c_qu'],
    fragmentos: [
      'Mi cuarto tiene una cama grande.',
      'Encima hay una manta de cuadros.',
      'Guardo los cuentos en la estantería.',
      'Por la noche apago la lámpara.',
    ],
    palabrasClave: ['cuarto', 'cuadros', 'cuentos', 'lámpara'],
  ),
  Dictado(
    id: 'dic-109',
    titulo: 'El mercado',
    nivel: 1,
    destrezas: ['mayuscula_inicial', 'punto_final', 'm_antes_p_b', 'c_qu'],
    fragmentos: [
      'Los martes vamos al mercado.',
      'Compramos manzanas y tomates.',
      'La señora nos da un caramelo.',
      'Volvemos con la bolsa llena.',
    ],
    palabrasClave: ['Compramos', 'caramelo', 'mercado', 'Volvemos'],
  ),
  Dictado(
    id: 'dic-110',
    titulo: 'El perro de Pablo',
    nivel: 1,
    destrezas: ['mayuscula_inicial', 'punto_final', 'm_antes_p_b', 'c_qu'],
    fragmentos: [
      'Pablo tiene un perro muy simpático.',
      'Come poco y duerme mucho.',
      'Siempre le pone la comida en un cuenco.',
      'Después salen juntos a la calle.',
    ],
    palabrasClave: ['Pablo', 'simpático', 'cuenco', 'Siempre'],
  ),
  Dictado(
    id: 'dic-111',
    titulo: 'El campamento',
    nivel: 1,
    destrezas: ['mayuscula_inicial', 'punto_final', 'm_antes_p_b', 'c_qu'],
    fragmentos: [
      'En verano voy a un campamento.',
      'Dormimos en tiendas de campaña.',
      'Cocinamos con una hoguera pequeña.',
      'Cantamos canciones hasta muy tarde.',
    ],
    palabrasClave: ['campamento', 'campaña', 'Cocinamos', 'pequeña'],
  ),
  Dictado(
    id: 'dic-112',
    titulo: 'La bicicleta',
    nivel: 1,
    destrezas: ['mayuscula_inicial', 'punto_final', 'm_antes_p_b', 'c_qu'],
    fragmentos: [
      'Mi bicicleta es de color blanco.',
      'Tiene un timbre que suena mucho.',
      'Cuando bajo la cuesta voy muy rápido.',
      'Nunca me olvido del casco.',
    ],
    palabrasClave: ['timbre', 'cuesta', 'casco', 'color'],
  ),

  // ------------------------------------------------------------- nivel 2 ---
  Dictado(
    id: 'dic-201',
    titulo: 'El perro de Rosa',
    nivel: 2,
    destrezas: ['mayuscula_inicial', 'punto_final', 'r_rr', 'h_frecuente', 'interrogacion_exclamacion'],
    fragmentos: [
      'Rosa tiene un perro negro.',
      'Hoy hemos ido al parque.',
      'El perro corre entre la hierba.',
      '¿Quieres jugar con nosotros?',
    ],
    palabrasClave: ['perro', 'hoy', 'hemos', 'hierba', 'corre'],
  ),
  Dictado(
    id: 'dic-202',
    titulo: 'La guitarra',
    nivel: 2,
    destrezas: ['mayuscula_inicial', 'punto_final', 'r_rr', 'h_frecuente', 'g_gu', 'interrogacion_exclamacion'],
    fragmentos: [
      'Mi hermano toca la guitarra.',
      'Hoy hay una fiesta en el barrio.',
      '¡Suena muy bien!',
      'Todos hemos bailado juntos.',
    ],
    palabrasClave: ['hermano', 'guitarra', 'hoy', 'hay', 'barrio', 'hemos'],
  ),
  Dictado(
    id: 'dic-203',
    titulo: 'El gato gordo',
    nivel: 2,
    destrezas: ['mayuscula_inicial', 'punto_final', 'r_rr', 'h_frecuente', 'g_gu', 'm_antes_p_b'],
    fragmentos: [
      'El gato gordo duerme en la alfombra.',
      'Una mosca vuela por la cocina.',
      '¿Se ha escondido en el armario?',
      'Hoy no la hemos visto.',
    ],
    palabrasClave: ['gordo', 'alfombra', 'ha', 'hemos', 'hoy'],
  ),


  Dictado(
    id: 'dic-204',
    titulo: 'La guitarra',
    nivel: 2,
    destrezas: ['mayuscula_inicial', 'punto_final', 'r_rr', 'g_gu', 'h_frecuente'],
    fragmentos: [
      'Mi hermana toca la guitarra.',
      'Ha aprendido una canción nueva.',
      'El perro se sienta a escucharla.',
      '¡Qué bien suena en casa!',
    ],
    palabrasClave: ['hermana', 'guitarra', 'Ha', 'perro'],
  ),
  Dictado(
    id: 'dic-205',
    titulo: 'El zapatero',
    nivel: 2,
    destrezas: ['mayuscula_inicial', 'punto_final', 'c_z', 'r_rr', 'h_frecuente'],
    fragmentos: [
      'En mi calle hay un zapatero.',
      'Arregla zapatos y cinturones.',
      'Hoy le he llevado mis botas.',
      'Estarán listas el martes.',
    ],
    palabrasClave: ['hay', 'zapatero', 'zapatos', 'he'],
  ),
  Dictado(
    id: 'dic-206',
    titulo: 'La hormiga',
    nivel: 2,
    destrezas: ['mayuscula_inicial', 'punto_final', 'h_frecuente', 'r_rr', 'interrogacion_exclamacion'],
    fragmentos: [
      'Una hormiga sube por la hierba.',
      'Lleva una miga enorme.',
      '¿Dónde vive esa hormiga?',
      '¡Debajo de aquella torre de arena!',
    ],
    palabrasClave: ['hormiga', 'hierba', 'torre', 'Debajo'],
  ),
  Dictado(
    id: 'dic-207',
    titulo: 'El huerto del abuelo',
    nivel: 2,
    destrezas: ['mayuscula_inicial', 'punto_final', 'h_frecuente', 'g_gu', 'c_z'],
    fragmentos: [
      'Mi abuelo tiene un huerto.',
      'Riega las lechugas cada mañana.',
      'Hoy hemos cogido cebollas.',
      'La tierra huele muy bien.',
    ],
    palabrasClave: ['huerto', 'lechugas', 'Hoy', 'cebollas'],
  ),
  Dictado(
    id: 'dic-208',
    titulo: 'El cielo de noche',
    nivel: 2,
    destrezas: ['mayuscula_inicial', 'punto_final', 'c_z', 'r_rr', 'll_y', 'interrogacion_exclamacion'],
    fragmentos: [
      'Por la noche miro el cielo.',
      'Cuento las estrellas desde la terraza.',
      '¿Cuántas habrá en total?',
      '¡Son muchísimas!',
    ],
    palabrasClave: ['cielo', 'estrellas', 'terraza', 'Cuento'],
  ),
  Dictado(
    id: 'dic-209',
    titulo: 'El barco',
    nivel: 2,
    destrezas: ['mayuscula_inicial', 'punto_final', 'c_qu', 'c_z', 'h_frecuente'],
    fragmentos: [
      'Ayer vimos un barco en el puerto.',
      'Era blanco y muy hermoso.',
      'Los marineros subían cajas.',
      'Zarpó cuando bajó la marea.',
    ],
    palabrasClave: ['hermoso', 'blanco', 'cajas', 'Zarpó'],
  ),
  Dictado(
    id: 'dic-210',
    titulo: 'La juguetería',
    nivel: 2,
    destrezas: ['mayuscula_inicial', 'punto_final', 'g_gu', 'r_rr', 'c_qu', 'interrogacion_exclamacion'],
    fragmentos: [
      'En la esquina hay una juguetería.',
      'En el escaparate hay un guitarrista de madera.',
      '¿Me lo regalarán en mi cumpleaños?',
      '¡Ojalá que sí!',
    ],
    palabrasClave: ['juguetería', 'guitarrista', 'escaparate', 'regalarán'],
  ),
  Dictado(
    id: 'dic-211',
    titulo: 'El zorro',
    nivel: 2,
    destrezas: ['mayuscula_inicial', 'punto_final', 'c_z', 'r_rr', 'h_frecuente'],
    fragmentos: [
      'Un zorro cruzó el camino.',
      'Tenía la cola muy larga.',
      'Se escondió detrás de una zarza.',
      'No hizo ningún ruido.',
    ],
    palabrasClave: ['zorro', 'cruzó', 'zarza', 'hizo'],
  ),
  Dictado(
    id: 'dic-212',
    titulo: 'La merienda',
    nivel: 2,
    destrezas: ['mayuscula_inicial', 'punto_final', 'g_gu', 'c_z', 'h_frecuente'],
    fragmentos: [
      'Hoy meriendo pan con chocolate.',
      'Mi amigo Hugo trae un zumo.',
      'Nos sentamos en el banco del portal.',
      'Después seguimos jugando.',
    ],
    palabrasClave: ['Hoy', 'Hugo', 'zumo', 'jugando'],
  ),

  // ------------------------------------------------------------- nivel 3 ---
  Dictado(
    id: 'dic-301',
    titulo: 'La excursión',
    nivel: 3,
    destrezas: ['tilde_agudas', 'b_verbos_aba', 'coma_enumeracion', 'mayuscula_inicial'],
    fragmentos: [
      'El domingo fuimos de excursión al campo.',
      'Llevaba bocadillos, fruta, agua y una manta.',
      'Mi hermano jugaba con un balón.',
      'Después merendamos junto a la fuente.',
      'Volvimos muy cansados.',
    ],
    palabrasClave: ['excursión', 'llevaba', 'jugaba', 'después', 'balón'],
  ),
  Dictado(
    id: 'dic-302',
    titulo: 'La tormenta',
    nivel: 3,
    destrezas: ['tilde_agudas', 'll_y', 'coma_enumeracion', 'mayuscula_inicial'],
    fragmentos: [
      'Ayer cayó una tormenta muy fuerte.',
      'Mi madre cerró la ventana del salón.',
      'Nosotros jugamos a las cartas, al parchís y al dominó.',
      'Cuando escampó, salimos a la calle.',
    ],
    palabrasClave: ['cayó', 'cerró', 'salón', 'parchís', 'dominó', 'escampó'],
  ),
  Dictado(
    id: 'dic-303',
    titulo: 'Los domingos de mi abuela',
    nivel: 3,
    destrezas: ['b_verbos_aba', 'tilde_agudas', 'coma_enumeracion', 'll_y'],
    fragmentos: [
      'Mi abuela cocinaba todos los domingos.',
      'Preparaba arroz, ensalada, pollo y flan.',
      'Nos llamaba desde la ventana.',
      'Después tomamos el postre en el jardín.',
    ],
    palabrasClave: ['cocinaba', 'preparaba', 'llamaba', 'pollo', 'jardín', 'después'],
  ),


  Dictado(
    id: 'dic-304',
    titulo: 'La tormenta',
    nivel: 3,
    destrezas: ['tilde_agudas', 'b_verbos_aba', 'll_y', 'mayuscula_inicial'],
    fragmentos: [
      'Ayer cayó una tormenta muy fuerte.',
      'Mi madre cerró la ventana del salón.',
      'La lluvia golpeaba los cristales.',
      'Cuando escampó, salimos a la calle.',
    ],
    palabrasClave: ['cayó', 'cerró', 'lluvia', 'golpeaba', 'escampó'],
  ),
  Dictado(
    id: 'dic-305',
    titulo: 'El mercadillo',
    nivel: 3,
    destrezas: ['tilde_agudas', 'coma_enumeracion', 'b_verbos_aba', 'mayuscula_inicial'],
    fragmentos: [
      'El sábado hubo mercadillo en el pueblo.',
      'Vendían ropa, libros, plantas y juguetes.',
      'Compré un balón por dos euros.',
      'Volví a casa muy contento.',
    ],
    palabrasClave: ['Vendían', 'balón', 'Compré', 'Volví'],
  ),
  Dictado(
    id: 'dic-306',
    titulo: 'La playa',
    nivel: 3,
    destrezas: ['ll_y', 'tilde_agudas', 'b_verbos_aba', 'coma_enumeracion', 'mayuscula_inicial'],
    fragmentos: [
      'En julio fuimos a la playa.',
      'Llevamos toallas, cubos, palas y una sombrilla.',
      'Mi hermana buscaba conchas en la orilla.',
      'Comimos un bocadillo de jamón.',
    ],
    palabrasClave: ['playa', 'Llevamos', 'buscaba', 'jamón'],
  ),
  Dictado(
    id: 'dic-307',
    titulo: 'El camión de bomberos',
    nivel: 3,
    destrezas: ['tilde_agudas', 'b_verbos_aba', 'mayuscula_inicial', 'punto_final'],
    fragmentos: [
      'Un camión de bomberos pasó por la avenida.',
      'La sirena sonaba muy fuerte.',
      'Todo el mundo se apartaba.',
      'Iban a apagar un incendio.',
    ],
    palabrasClave: ['camión', 'pasó', 'sonaba', 'apartaba'],
  ),
  Dictado(
    id: 'dic-308',
    titulo: 'La bicicleta amarilla',
    nivel: 3,
    destrezas: ['ll_y', 'b_verbos_aba', 'tilde_agudas', 'coma_enumeracion'],
    fragmentos: [
      'Mi bicicleta amarilla estaba en el trastero.',
      'Le puse aceite, aire y un timbre nuevo.',
      'Ayer pedaleé hasta el río.',
      'La llave del candado se me cayó.',
    ],
    palabrasClave: ['amarilla', 'estaba', 'llave', 'cayó'],
  ),
  Dictado(
    id: 'dic-309',
    titulo: 'El jardín de la escuela',
    nivel: 3,
    destrezas: ['tilde_agudas', 'coma_enumeracion', 'b_verbos_aba', 'll_y', 'g_j'],
    fragmentos: [
      'En la escuela plantamos un jardín.',
      'Sembramos lechugas, tomates, fresas y perejil.',
      'Cada mañana lo regaba un alumno distinto.',
      'En mayo ya había flores.',
    ],
    palabrasClave: ['jardín', 'perejil', 'regaba', 'mayo'],
  ),
  Dictado(
    id: 'dic-310',
    titulo: 'El ratón',
    nivel: 3,
    destrezas: ['tilde_agudas', 'b_verbos_aba', 'mayuscula_inicial', 'r_rr', 'c_qu'],
    fragmentos: [
      'Un ratón vivía detrás del armario.',
      'Por la noche buscaba migas de pan.',
      'El gato lo miraba sin moverse.',
      'Al final se hicieron amigos.',
    ],
    palabrasClave: ['ratón', 'buscaba', 'detrás', 'miraba'],
  ),
  Dictado(
    id: 'dic-311',
    titulo: 'El día de la bicicletada',
    nivel: 3,
    destrezas: ['tilde_agudas', 'coma_enumeracion', 'll_y', 'c_qu', 'mayuscula_inicial'],
    fragmentos: [
      'El domingo hubo una bicicletada.',
      'Participaron niños, padres, abuelos y maestros.',
      'La calle estaba llena de gente.',
      'Terminamos en el parque con un refresco.',
    ],
    palabrasClave: ['llena', 'calle', 'parque', 'refresco'],
  ),
  Dictado(
    id: 'dic-312',
    titulo: 'El gallo',
    nivel: 3,
    destrezas: ['ll_y', 'b_verbos_aba', 'tilde_agudas', 'mayuscula_inicial'],
    fragmentos: [
      'En el corral había un gallo.',
      'Cantaba todas las mañanas.',
      'Las gallinas lo seguían por el patio.',
      'Mi abuelo les echaba maíz.',
    ],
    palabrasClave: ['gallo', 'Cantaba', 'gallinas', 'echaba'],
  ),

  // ------------------------------------------------------------- nivel 4 ---
  Dictado(
    id: 'dic-401',
    titulo: 'El pingüino',
    nivel: 4,
    destrezas: ['dieresis', 'tilde_esdrujulas', 'g_j', 'tilde_llanas'],
    fragmentos: [
      'El pingüino vive en lugares muy fríos.',
      'Es un animal tranquilo y simpático.',
      'Nada rapidísimo debajo del agua.',
      'Su plumaje parece un traje elegante.',
      'Nunca se queja del frío.',
    ],
    palabrasClave: ['pingüino', 'simpático', 'rapidísimo', 'plumaje', 'queja'],
  ),
  Dictado(
    id: 'dic-402',
    titulo: 'El árbol del jardín',
    nivel: 4,
    destrezas: ['tilde_llanas', 'tilde_esdrujulas', 'g_j', 'g_gu', 'mayuscula_inicial'],
    fragmentos: [
      'En el jardín hay un árbol muy antiguo.',
      'Sus ramas dan una sombra agradable.',
      'Los pájaros hacen allí su nido.',
      'Es el lugar más tranquilo de la casa.',
    ],
    palabrasClave: ['jardín', 'árbol', 'antiguo', 'pájaros', 'allí'],
  ),
  Dictado(
    id: 'dic-403',
    titulo: 'La bicicleta nueva',
    nivel: 4,
    destrezas: ['tilde_esdrujulas', 'v_adjetivos', 'g_j', 'tilde_agudas'],
    fragmentos: [
      'Mi primo tiene una bicicleta ligera.',
      'El sábado bajamos juntos al parque.',
      'Aprendió a frenar rápidamente.',
      'Ahora es un chico muy activo y deportivo.',
    ],
    palabrasClave: ['ligera', 'sábado', 'aprendió', 'rápidamente', 'activo', 'deportivo'],
  ),


  Dictado(
    id: 'dic-404',
    titulo: 'El pájaro carpintero',
    nivel: 4,
    destrezas: ['tilde_esdrujulas', 'tilde_llanas', 'g_j', 'c_qu', 'mayuscula_inicial'],
    fragmentos: [
      'Un pájaro carpintero golpea el tronco.',
      'Su pico es rapidísimo y fuerte.',
      'La gente se para a mirarlo.',
      'Después vuela hacia el bosque.',
    ],
    palabrasClave: ['pájaro', 'rapidísimo', 'gente', 'tronco'],
  ),
  Dictado(
    id: 'dic-405',
    titulo: 'La clase de música',
    nivel: 4,
    destrezas: ['tilde_esdrujulas', 'tilde_llanas', 'g_j', 'c_qu', 'mayuscula_inicial'],
    fragmentos: [
      'Los jueves tenemos clase de música.',
      'Tocamos la flauta y el triángulo.',
      'El profesor marca el ritmo con las manos.',
      'Es mi asignatura favorita.',
    ],
    palabrasClave: ['música', 'triángulo', 'jueves', 'Tocamos'],
  ),
  Dictado(
    id: 'dic-406',
    titulo: 'El pingüino',
    nivel: 4,
    destrezas: ['dieresis', 'tilde_llanas', 'tilde_esdrujulas', 'c_z', 'mayuscula_inicial'],
    fragmentos: [
      'El pingüino camina muy despacio.',
      'Vive donde el agua está helada.',
      'Nada rapidísimo para buscar peces.',
      'Es un animal simpático y torpe.',
    ],
    palabrasClave: ['pingüino', 'rapidísimo', 'simpático', 'peces'],
  ),
  Dictado(
    id: 'dic-407',
    titulo: 'El viaje en tren',
    nivel: 4,
    destrezas: ['g_j', 'tilde_llanas', 'tilde_esdrujulas', 'coma_enumeracion'],
    fragmentos: [
      'Hicimos un viaje muy largo en tren.',
      'En la maleta llevaba libros, jerséis y un mapa.',
      'El paisaje pasaba rápido por la ventanilla.',
      'Llegamos a Málaga por la mañana.',
    ],
    palabrasClave: ['viaje', 'jerséis', 'rápido', 'Málaga'],
  ),
  Dictado(
    id: 'dic-408',
    titulo: 'La brújula',
    nivel: 4,
    destrezas: ['tilde_esdrujulas', 'tilde_llanas', 'v_adjetivos', 'g_j', 'mayuscula_inicial'],
    fragmentos: [
      'Mi tío me regaló una brújula.',
      'La aguja siempre señala el norte.',
      'Es un objeto pequeño y muy útil.',
      'La llevo en todas las excursiones.',
    ],
    palabrasClave: ['brújula', 'útil', 'objeto', 'regaló'],
  ),
  Dictado(
    id: 'dic-409',
    titulo: 'La jirafa del zoo',
    nivel: 4,
    destrezas: ['g_j', 'tilde_llanas', 'tilde_esdrujulas', 'mayuscula_inicial'],
    fragmentos: [
      'En el zoo vimos una jirafa altísima.',
      'Comía hojas de la rama más alta.',
      'A su lado había un cocodrilo dormido.',
      'Fue una mañana estupenda.',
    ],
    palabrasClave: ['jirafa', 'altísima', 'Comía', 'hojas'],
  ),
  Dictado(
    id: 'dic-410',
    titulo: 'El árbol del patio',
    nivel: 4,
    destrezas: ['tilde_llanas', 'tilde_esdrujulas', 'g_j', 'coma_enumeracion', 'mayuscula_inicial'],
    fragmentos: [
      'En el patio hay un árbol enorme.',
      'Debajo jugamos, hablamos y merendamos.',
      'En otoño sus hojas se vuelven amarillas.',
      'El jardinero lo poda en diciembre.',
    ],
    palabrasClave: ['árbol', 'jugamos', 'jardinero', 'hojas'],
  ),
  Dictado(
    id: 'dic-411',
    titulo: 'El teléfono antiguo',
    nivel: 4,
    destrezas: ['tilde_esdrujulas', 'tilde_llanas', 'v_adjetivos', 'g_gu', 'g_j'],
    fragmentos: [
      'En el desván hay un teléfono antiguo.',
      'Es un aparato pesado y muy curioso.',
      'Mi abuela dice que era carísimo.',
      'Todavía funciona, aunque suena raro.',
    ],
    palabrasClave: ['teléfono', 'antiguo', 'carísimo', 'Todavía'],
  ),
  Dictado(
    id: 'dic-412',
    titulo: 'La lámpara mágica',
    nivel: 4,
    destrezas: ['tilde_esdrujulas', 'tilde_llanas', 'g_j', 'mayuscula_inicial'],
    fragmentos: [
      'El cuento hablaba de una lámpara mágica.',
      'Dentro vivía un genio simpático.',
      'Concedía tres deseos difíciles.',
      'Al final, el protagonista pidió un libro.',
    ],
    palabrasClave: ['lámpara', 'mágica', 'genio', 'difíciles'],
  ),

  // ------------------------------------------------------------- nivel 5 ---
  Dictado(
    id: 'dic-501',
    titulo: 'La carta',
    nivel: 5,
    destrezas: ['tilde_diacritica', 'homofonos', 'porque', 'x_s', 'b_v_reglas'],
    fragmentos: [
      'Ayer recibí una carta tuya.',
      'Me preguntabas por qué no había ido.',
      'Sí, tenía muchas ganas de verte.',
      'Pero tú sabes que el examen era difícil.',
      'Ahí está la razón de mi silencio.',
    ],
    palabrasClave: ['recibí', 'había', 'sí', 'tú', 'ahí', 'examen'],
  ),
  Dictado(
    id: 'dic-502',
    titulo: 'El día del examen',
    nivel: 5,
    destrezas: ['hiato', 'b_v_reglas', 'porque', 'tilde_diacritica'],
    fragmentos: [
      'Aquel día me levanté muy temprano.',
      'No sabía si había estudiado bastante.',
      'Mi hermana me dijo que no me preocupara.',
      'Cuando salí, sonreía porque todo había salido bien.',
    ],
    palabrasClave: ['día', 'sabía', 'había', 'sonreía', 'porque'],
  ),
  Dictado(
    id: 'dic-503',
    titulo: 'A ver qué pasa',
    nivel: 5,
    destrezas: ['homofonos', 'tilde_diacritica', 'b_v_reglas', 'interrogacion_exclamacion'],
    fragmentos: [
      'Vamos a ver si hay entradas para el concierto.',
      'Ahí mismo, en la taquilla, lo sabremos.',
      'Debe de haber mucha gente esperando.',
      '¡Ay, ojalá queden algunas!',
    ],
    palabrasClave: ['ver', 'hay', 'Ahí', 'haber', 'Ay', 'ojalá'],
  ),

  Dictado(
    id: 'dic-504',
    titulo: 'El examen',
    nivel: 5,
    destrezas: ['tilde_diacritica', 'x_s', 'b_v_reglas', 'tilde_llanas'],
    fragmentos: [
      'Mañana tengo el examen de ciencias.',
      'Sé que he estudiado bastante.',
      'Aun así, estoy un poco nervioso.',
      'Mi hermana dice que me saldrá bien.',
    ],
    palabrasClave: ['examen', 'Sé', 'bastante', 'Aun'],
  ),
  Dictado(
    id: 'dic-505',
    titulo: 'El día de lluvia',
    nivel: 5,
    destrezas: ['hiato', 'tilde_diacritica', 'b_v_reglas', 'll_y'],
    fragmentos: [
      'Aquel día llovía sin parar.',
      'El río bajaba lleno de agua.',
      'Mi tía nos llevó al museo.',
      'Volvimos a casa cuando ya oscurecía.',
    ],
    palabrasClave: ['día', 'llovía', 'río', 'tía'],
  ),
  Dictado(
    id: 'dic-506',
    titulo: 'La excursión al río',
    nivel: 5,
    destrezas: ['x_s', 'hiato', 'coma_enumeracion', 'tilde_diacritica'],
    fragmentos: [
      'La excursión salió muy temprano.',
      'Llevábamos mochilas, cantimploras, gorras y mapas.',
      'El sendero subía entre pinos.',
      'Al mediodía comimos junto al río.',
    ],
    palabrasClave: ['excursión', 'Llevábamos', 'subía', 'río'],
  ),
  Dictado(
    id: 'dic-507',
    titulo: 'El texto de la pizarra',
    nivel: 5,
    destrezas: ['x_s', 'tilde_diacritica', 'b_v_reglas', 'tilde_llanas'],
    fragmentos: [
      'La maestra escribió un texto en la pizarra.',
      'Nos explicó cada palabra difícil.',
      'Yo lo copié en mi cuaderno.',
      'Él prefirió aprendérselo de memoria.',
    ],
    palabrasClave: ['texto', 'explicó', 'difícil', 'Él'],
  ),
  Dictado(
    id: 'dic-508',
    titulo: 'La bicicleta nueva',
    nivel: 5,
    destrezas: ['b_v_reglas', 'tilde_diacritica', 'hiato', 'tilde_llanas'],
    fragmentos: [
      'Mi tío me ha traído una bicicleta nueva.',
      'Antes tenía una muy vieja.',
      'Sí, todavía la guardo en el garaje.',
      'Con esta subiré la cuesta sin cansarme.',
    ],
    palabrasClave: ['bicicleta', 'tenía', 'Sí', 'vieja'],
  ),
  Dictado(
    id: 'dic-509',
    titulo: 'El taxi',
    nivel: 5,
    destrezas: ['x_s', 'tilde_diacritica', 'tilde_llanas', 'mayuscula_inicial'],
    fragmentos: [
      'Cogimos un taxi hasta la estación.',
      'El conductor era muy amable.',
      'Nos explicó por dónde se iba más rápido.',
      'Llegamos justo a tiempo.',
    ],
    palabrasClave: ['taxi', 'estación', 'explicó', 'rápido'],
  ),
  Dictado(
    id: 'dic-510',
    titulo: 'La sonrisa de mi abuela',
    nivel: 5,
    destrezas: ['hiato', 'b_v_reglas', 'tilde_llanas', 'tilde_diacritica'],
    fragmentos: [
      'Mi abuela sonreía cada vez que me veía.',
      'Vivía en una casa con un patio grande.',
      'Allí había un limonero enorme.',
      'Aún recuerdo el olor de su cocina.',
    ],
    palabrasClave: ['sonreía', 'Vivía', 'había', 'Aún'],
  ),
  Dictado(
    id: 'dic-511',
    titulo: 'El experimento',
    nivel: 5,
    destrezas: ['x_s', 'tilde_llanas', 'b_v_reglas', 'coma_enumeracion'],
    fragmentos: [
      'Hicimos un experimento en clase.',
      'Necesitábamos agua, sal, un vaso y una cuchara.',
      'El profesor explicó cada paso.',
      'El resultado fue increíble.',
    ],
    palabrasClave: ['experimento', 'Necesitábamos', 'vaso', 'increíble'],
  ),
  Dictado(
    id: 'dic-512',
    titulo: 'El maíz del huerto',
    nivel: 5,
    destrezas: ['hiato', 'b_v_reglas', 'tilde_diacritica', 'tilde_llanas'],
    fragmentos: [
      'En el huerto crecía el maíz.',
      'Mi padre lo regaba todos los días.',
      'Él decía que era el mejor del pueblo.',
      'Ese verano tuvimos una cosecha buenísima.',
    ],
    palabrasClave: ['crecía', 'maíz', 'Él', 'días'],
  ),
];

final Map<String, Dictado> _porId = {for (final d in dictados) d.id: d};

Dictado? dictadoPorId(String id) => _porId[id];

/// Veces que se lee cada frase antes de callar para que el niño escriba.
///
/// Dos: la primera para enterarse, la segunda —más despacio— para escribirla.
const int vecesPorFrase = 2;

/// Cuánto callar tras las lecturas de un fragmento para que le dé tiempo a
/// escribirlo.
///
/// Un niño de nivel 1 escribe bastante más despacio que uno de nivel 5, así que
/// la pausa no es fija: depende del número de palabras y del nivel.
int pausaSegundos(String fragmento, int nivel) {
  final palabras =
      fragmento.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).length;
  final segundosPorPalabra = nivel <= 2 ? 2.8 : (nivel <= 3 ? 2.4 : 2.0);
  return (palabras * segundosPorPalabra + 2).round();
}

/// Duración estimada de la actividad completa, para encajarla en la sesión diaria.
///
/// Cada frase se lee [vecesPorFrase] veces, la segunda más despacio, y entre
/// palabra y palabra se calla. Con eso, decir una frase cuesta bastante más que
/// leerla. Quedarse corto aquí no alarga el dictado: hace que el planificador
/// meta otra actividad detrás que no cabe.
int duracionEstimadaSegundos(Dictado d) {
  var total = 0.0;
  for (final f in d.fragmentos) {
    final palabras = f.split(RegExp(r'\s+')).length;
    // Por palabra: lo que se tarda en decirla más el silencio de después.
    total += pausaSegundos(f, d.nivel) + palabras * 1.7 * vecesPorFrase + 2;
  }
  return (total + 45).round(); // + preparación y corrección
}

/// Elige un dictado del nivel pedido que además sea apropiado para el curso.
/// `yaHechos` evita repetir; si no queda ninguno sin hacer, se recicla antes que
/// dejar al niño sin actividad.
Dictado? elegirDictado(int nivel, int curso, List<String> yaHechos, {Random? azar}) {
  final apropiados = dictados
      .where((d) => d.nivel == nivel && apropiadoParaCurso(d.destrezas, curso))
      .toList();

  if (apropiados.isEmpty) {
    // Sin material del nivel exacto, se baja un escalón antes que fallar.
    return nivel > 1 ? elegirDictado(nivel - 1, curso, yaHechos, azar: azar) : null;
  }

  final nuevos = apropiados.where((d) => !yaHechos.contains(d.id)).toList();
  final candidatos = nuevos.isNotEmpty ? nuevos : apropiados;
  return candidatos[(azar ?? Random()).nextInt(candidatos.length)];
}
