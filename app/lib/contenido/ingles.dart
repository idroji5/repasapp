/// Ejercicios de inglés, escritos a mano uno a uno.
///
/// Aquí no hay generador: una cuenta se puede parametrizar, una frase en otro
/// idioma no. "My sister is tall" o está bien escrita o enseña a escribir mal,
/// así que cada ejercicio está revisado.
///
/// El inglés de referencia es el británico, que es el que se da en el colegio
/// en España. Lo que va entre «comillas angulares» se dice con voz inglesa; el
/// resto, en castellano.
library;

import 'dart:math';

import 'ejercicio.dart';
import 'generador.dart';

/// Qué se le pide hacer. Un ejercicio de inglés no es solo traducir: se
/// escribe, se completa, se contesta y se recuerda vocabulario, que son cosas
/// distintas y cansan de maneras distintas.
enum TipoIngles {
  /// Una palabra suelta, del castellano al inglés.
  vocabulario,

  /// Una frase entera, del castellano al inglés.
  alIngles,

  /// Una frase entera, del inglés al castellano.
  alEspanol,

  /// Falta una palabra en una frase inglesa.
  completar,

  /// Una pregunta en inglés que hay que contestar en inglés.
  responder,

  /// Inventarse una frase con algo dentro.
  escribir,
}

class ItemIngles {
  const ItemIngles(
    this.destrezaId,
    this.nivel,
    this.tipo,
    this.pide,
    this.respuesta, {
    this.nota,
  });

  final String destrezaId;

  /// 1 a 5, la dificultad dentro de la destreza.
  final int nivel;

  final TipoIngles tipo;

  /// Lo que se le da: la palabra, la frase, el hueco o la pregunta.
  final String pide;

  /// La solución. En los abiertos —contestar, inventar— es un modelo válido,
  /// no la única respuesta buena: quien decide si la suya vale es el niño.
  final String respuesta;

  /// Por qué es así, cuando hay una regla que merezca decirse.
  final String? nota;

  /// Si lo que se le da está en inglés (y por tanto hay que leerlo en inglés).
  bool get pideEnIngles => switch (tipo) {
        TipoIngles.vocabulario || TipoIngles.alIngles => false,
        TipoIngles.alEspanol ||
        TipoIngles.completar ||
        TipoIngles.responder ||
        TipoIngles.escribir =>
          true,
      };

  /// Si la solución está en inglés.
  bool get respondeEnIngles => tipo != TipoIngles.alEspanol;
}

// ---------------------------------------------------------------- el banco ---

const List<ItemIngles> ejerciciosDeIngles = [
  // ------------------------------------------------------- 1.º: saludos ---
  ItemIngles('ingles_saludos', 1, TipoIngles.vocabulario, 'hola', 'hello'),
  ItemIngles('ingles_saludos', 1, TipoIngles.vocabulario, 'adiós', 'goodbye'),
  ItemIngles('ingles_saludos', 2, TipoIngles.vocabulario, 'por favor', 'please'),
  ItemIngles('ingles_saludos', 2, TipoIngles.vocabulario, 'gracias', 'thank you'),
  ItemIngles('ingles_saludos', 3, TipoIngles.alEspanol, 'Good morning', 'Buenos días'),
  ItemIngles('ingles_saludos', 3, TipoIngles.alEspanol, 'Good night', 'Buenas noches'),
  ItemIngles('ingles_saludos', 4, TipoIngles.responder, 'How are you?', "I'm fine, thank you",
      nota: 'Se contesta con una frase, no con una palabra suelta.'),

  // ------------------------------------------------------- 1.º: colores ---
  ItemIngles('ingles_colores', 1, TipoIngles.vocabulario, 'rojo', 'red'),
  ItemIngles('ingles_colores', 1, TipoIngles.vocabulario, 'azul', 'blue'),
  ItemIngles('ingles_colores', 1, TipoIngles.vocabulario, 'verde', 'green'),
  ItemIngles('ingles_colores', 2, TipoIngles.vocabulario, 'amarillo', 'yellow'),
  ItemIngles('ingles_colores', 2, TipoIngles.vocabulario, 'negro', 'black'),
  ItemIngles('ingles_colores', 3, TipoIngles.vocabulario, 'morado', 'purple'),
  ItemIngles('ingles_colores', 4, TipoIngles.alIngles, 'Mi color favorito es el verde',
      'My favourite colour is green',
      nota: 'En inglés británico "colour" lleva u; el color va detrás del verbo.'),

  // ------------------------------------------------------- 1.º: números ---
  ItemIngles('ingles_numeros', 1, TipoIngles.vocabulario, 'tres', 'three'),
  ItemIngles('ingles_numeros', 1, TipoIngles.vocabulario, 'siete', 'seven'),
  ItemIngles('ingles_numeros', 2, TipoIngles.vocabulario, 'doce', 'twelve'),
  ItemIngles('ingles_numeros', 3, TipoIngles.vocabulario, 'veinte', 'twenty'),
  ItemIngles('ingles_numeros', 3, TipoIngles.alEspanol, 'I am nine years old', 'Tengo nueve años',
      nota: 'La edad en inglés se dice con "to be", no con "tener": I AM nine.'),
  ItemIngles('ingles_numeros', 4, TipoIngles.completar,
      'I have got ... brothers. (dos)', 'two'),

  // ------------------------------------------------------- 2.º: familia ---
  ItemIngles('ingles_familia', 1, TipoIngles.vocabulario, 'madre', 'mother'),
  ItemIngles('ingles_familia', 1, TipoIngles.vocabulario, 'hermano', 'brother'),
  ItemIngles('ingles_familia', 2, TipoIngles.vocabulario, 'abuela', 'grandmother'),
  ItemIngles('ingles_familia', 2, TipoIngles.vocabulario, 'primo', 'cousin'),
  ItemIngles('ingles_familia', 3, TipoIngles.alEspanol, 'This is my sister', 'Esta es mi hermana'),
  ItemIngles('ingles_familia', 4, TipoIngles.alIngles, 'Mi padre es alto', 'My father is tall'),
  ItemIngles('ingles_familia', 4, TipoIngles.responder, 'Have you got a sister?',
      'Yes, I have / No, I have not'),

  // ------------------------------------------------------- 2.º: animales ---
  ItemIngles('ingles_animales', 1, TipoIngles.vocabulario, 'perro', 'dog'),
  ItemIngles('ingles_animales', 1, TipoIngles.vocabulario, 'gato', 'cat'),
  ItemIngles('ingles_animales', 2, TipoIngles.vocabulario, 'caballo', 'horse'),
  ItemIngles('ingles_animales', 2, TipoIngles.vocabulario, 'pájaro', 'bird'),
  ItemIngles('ingles_animales', 3, TipoIngles.vocabulario, 'mariposa', 'butterfly'),
  ItemIngles('ingles_animales', 3, TipoIngles.alEspanol, 'The cat is under the table',
      'El gato está debajo de la mesa'),
  ItemIngles('ingles_animales', 4, TipoIngles.escribir, 'dog', 'My dog is black'),

  // --------------------------------------------------------- 2.º: to be ---
  ItemIngles('ingles_to_be', 1, TipoIngles.completar, 'I ... a student.', 'am',
      nota: 'Con "I" siempre va "am".'),
  ItemIngles('ingles_to_be', 2, TipoIngles.completar, 'You ... my friend.', 'are',
      nota: 'Con "you", "we" y "they" va "are".'),
  ItemIngles('ingles_to_be', 2, TipoIngles.completar, 'She ... my teacher.', 'is',
      nota: 'Con "he", "she" e "it" va "is".'),
  ItemIngles('ingles_to_be', 3, TipoIngles.alIngles, 'Soy español', 'I am Spanish'),
  ItemIngles('ingles_to_be', 4, TipoIngles.alIngles, 'Ella no es mi hermana',
      'She is not my sister',
      nota: 'Para negar se pone "not" detrás del verbo: is not.'),

  // --------------------------------------------------------- 3.º: clase ---
  ItemIngles('ingles_clase', 1, TipoIngles.vocabulario, 'libro', 'book'),
  ItemIngles('ingles_clase', 1, TipoIngles.vocabulario, 'lápiz', 'pencil'),
  ItemIngles('ingles_clase', 2, TipoIngles.vocabulario, 'mochila', 'schoolbag'),
  ItemIngles('ingles_clase', 2, TipoIngles.vocabulario, 'pizarra', 'blackboard'),
  ItemIngles('ingles_clase', 3, TipoIngles.alEspanol, 'Open your book, please',
      'Abre tu libro, por favor'),
  ItemIngles('ingles_clase', 4, TipoIngles.alIngles, 'Mi mochila es azul',
      'My schoolbag is blue'),

  // ------------------------------------------------------ 3.º: plurales ---
  ItemIngles('ingles_plurales', 1, TipoIngles.alIngles, 'dos libros', 'two books',
      nota: 'El plural normal se hace añadiendo una -s.'),
  ItemIngles('ingles_plurales', 2, TipoIngles.alIngles, 'tres cajas', 'three boxes',
      nota: 'Las palabras que acaban en -x, -s, -ch o -sh hacen el plural en -es.'),
  ItemIngles('ingles_plurales', 3, TipoIngles.completar, 'I can see three ... . (niños)',
      'children',
      nota: 'El plural de "child" no lleva -s: es "children".'),
  ItemIngles('ingles_plurales', 4, TipoIngles.completar, 'My ... are new. (pies)', 'feet',
      nota: 'Otro plural irregular: foot, feet.'),
  ItemIngles('ingles_plurales', 4, TipoIngles.alEspanol, 'These are my books',
      'Estos son mis libros'),

  // ----------------------------------------------------- 3.º: have got ---
  ItemIngles('ingles_have_got', 1, TipoIngles.alIngles, 'Tengo un perro', 'I have got a dog'),
  ItemIngles('ingles_have_got', 2, TipoIngles.completar, 'She ... got a bike.', 'has',
      nota: 'Con "he", "she" e "it" se dice "has got", no "have got".'),
  ItemIngles('ingles_have_got', 3, TipoIngles.alEspanol, 'We have got a big house',
      'Tenemos una casa grande'),
  ItemIngles('ingles_have_got', 4, TipoIngles.responder, 'Have you got a pet?',
      'Yes, I have got a dog'),

  // -------------------------------------------------------- 3.º: comida ---
  ItemIngles('ingles_comida', 1, TipoIngles.vocabulario, 'leche', 'milk'),
  ItemIngles('ingles_comida', 1, TipoIngles.vocabulario, 'pan', 'bread'),
  ItemIngles('ingles_comida', 2, TipoIngles.vocabulario, 'manzana', 'apple'),
  ItemIngles('ingles_comida', 2, TipoIngles.vocabulario, 'queso', 'cheese'),
  ItemIngles('ingles_comida', 3, TipoIngles.alEspanol, 'I like fish', 'Me gusta el pescado',
      nota: '"I like" se traduce por "me gusta", aunque en inglés el sujeto sea yo.'),
  ItemIngles('ingles_comida', 4, TipoIngles.escribir, 'I like', 'I like apples'),

  // ---------------------------------------------- 4.º: presente simple ---
  ItemIngles('ingles_presente_simple', 1, TipoIngles.alIngles, 'Juego al fútbol',
      'I play football'),
  ItemIngles('ingles_presente_simple', 2, TipoIngles.completar, 'He ... football. (jugar)',
      'plays',
      nota: 'Con "he", "she" e "it" el verbo lleva una -s al final.'),
  ItemIngles('ingles_presente_simple', 3, TipoIngles.alIngles, 'Ella vive en Madrid',
      'She lives in Madrid'),
  ItemIngles('ingles_presente_simple', 4, TipoIngles.alIngles, 'No me gusta el café',
      "I don't like coffee",
      nota: 'Para negar en presente, "do not" se junta en "don\'t".'),
  ItemIngles('ingles_presente_simple', 5, TipoIngles.completar,
      '... she like music? (¿le gusta?)', 'Does',
      nota: 'Las preguntas con "he", "she" e "it" empiezan por "Does".'),

  // ---------------------------------------------------------- 4.º: hora ---
  ItemIngles('ingles_hora', 2, TipoIngles.alIngles, 'Son las tres en punto',
      "It's three o'clock"),
  ItemIngles('ingles_hora', 3, TipoIngles.alEspanol, "It's half past four",
      'Son las cuatro y media',
      nota: '"Half past" es "y media", y va después de la hora.'),
  ItemIngles('ingles_hora', 4, TipoIngles.alEspanol, "It's quarter to nine",
      'Son las nueve menos cuarto'),
  ItemIngles('ingles_hora', 4, TipoIngles.responder, 'What time is it?', "It's ten o'clock"),

  // ------------------------------------------------- 4.º: preposiciones ---
  ItemIngles('ingles_preposiciones', 1, TipoIngles.vocabulario, 'en (dentro de)', 'in'),
  ItemIngles('ingles_preposiciones', 2, TipoIngles.vocabulario, 'debajo de', 'under'),
  ItemIngles('ingles_preposiciones', 3, TipoIngles.completar,
      'The book is ... the table. (encima)', 'on'),
  ItemIngles('ingles_preposiciones', 3, TipoIngles.alEspanol, 'The cat is behind the door',
      'El gato está detrás de la puerta'),
  ItemIngles('ingles_preposiciones', 4, TipoIngles.alIngles, 'El perro está entre las sillas',
      'The dog is between the chairs'),

  // ----------------------------------------------------- 4.º: adjetivos ---
  ItemIngles('ingles_adjetivos', 1, TipoIngles.vocabulario, 'grande', 'big'),
  ItemIngles('ingles_adjetivos', 1, TipoIngles.vocabulario, 'pequeño', 'small'),
  ItemIngles('ingles_adjetivos', 2, TipoIngles.vocabulario, 'viejo', 'old'),
  ItemIngles('ingles_adjetivos', 3, TipoIngles.alIngles, 'Una casa grande', 'A big house',
      nota: 'En inglés el adjetivo va DELANTE del nombre: big house, no house big.'),
  ItemIngles('ingles_adjetivos', 4, TipoIngles.alEspanol, 'She has got long brown hair',
      'Ella tiene el pelo largo y castaño'),

  // -------------------------------------------- 5.º: presente continuo ---
  ItemIngles('ingles_presente_continuo', 2, TipoIngles.alIngles, 'Estoy leyendo',
      'I am reading',
      nota: 'Lo que pasa ahora mismo se dice con "to be" + verbo terminado en -ing.'),
  ItemIngles('ingles_presente_continuo', 3, TipoIngles.completar,
      'She is ... to music. (escuchando)', 'listening'),
  ItemIngles('ingles_presente_continuo', 4, TipoIngles.alEspanol,
      'They are playing in the garden', 'Están jugando en el jardín'),
  ItemIngles('ingles_presente_continuo', 5, TipoIngles.responder, 'What are you doing?',
      'I am doing my homework'),

  // ------------------------------------------------- 5.º: there is/are ---
  ItemIngles('ingles_there_is', 2, TipoIngles.alIngles, 'Hay un libro en la mesa',
      'There is a book on the table',
      nota: '"Hay" es "there is" en singular y "there are" en plural.'),
  ItemIngles('ingles_there_is', 3, TipoIngles.completar, 'There ... four chairs.', 'are'),
  ItemIngles('ingles_there_is', 4, TipoIngles.alEspanol, 'There are two windows in my room',
      'Hay dos ventanas en mi habitación'),
  ItemIngles('ingles_there_is', 5, TipoIngles.escribir, 'There are', 'There are trees in the park'),

  // ------------------------------------------------------- 5.º: rutinas ---
  ItemIngles('ingles_rutinas', 2, TipoIngles.alIngles, 'Me levanto a las siete',
      'I get up at seven'),
  ItemIngles('ingles_rutinas', 3, TipoIngles.alEspanol, 'I go to school by bus',
      'Voy al colegio en autobús',
      nota: 'El medio de transporte va con "by": by bus, by car, by bike.'),
  ItemIngles('ingles_rutinas', 4, TipoIngles.alIngles, 'Siempre desayuno leche',
      'I always have milk for breakfast'),
  ItemIngles('ingles_rutinas', 5, TipoIngles.responder, 'What time do you get up?',
      'I get up at half past seven'),

  // ------------------------------------------------- 6.º: pasado simple ---
  ItemIngles('ingles_pasado_simple', 2, TipoIngles.completar, 'Yesterday I ... at home.',
      'was',
      nota: 'El pasado de "am" y "is" es "was"; el de "are" es "were".'),
  ItemIngles('ingles_pasado_simple', 3, TipoIngles.alIngles, 'Ayer jugué al fútbol',
      'Yesterday I played football',
      nota: 'Los verbos regulares hacen el pasado añadiendo -ed.'),
  ItemIngles('ingles_pasado_simple', 4, TipoIngles.completar, 'We ... to the cinema. (fuimos)',
      'went',
      nota: '"Go" es irregular: su pasado es "went", no "goed".'),
  ItemIngles('ingles_pasado_simple', 5, TipoIngles.alEspanol, 'She bought a new bike',
      'Ella compró una bici nueva'),

  // -------------------------------------------------- 6.º: comparativos ---
  ItemIngles('ingles_comparativos', 3, TipoIngles.alIngles, 'Soy más alto que tú',
      'I am taller than you',
      nota: 'Con adjetivos cortos se añade -er y luego "than".'),
  ItemIngles('ingles_comparativos', 4, TipoIngles.completar,
      'This book is more ... than that one. (interesante)', 'interesting',
      nota: 'Con adjetivos largos no se añade -er: se pone "more" delante.'),
  ItemIngles('ingles_comparativos', 5, TipoIngles.alEspanol, 'My bike is better than yours',
      'Mi bici es mejor que la tuya',
      nota: '"Good" es irregular: su comparativo es "better".'),

  // ----------------------------------------------------- 6.º: preguntas ---
  ItemIngles('ingles_preguntas', 2, TipoIngles.alEspanol, 'Where do you live?',
      '¿Dónde vives?'),
  ItemIngles('ingles_preguntas', 3, TipoIngles.alEspanol, 'Why are you sad?',
      '¿Por qué estás triste?'),
  ItemIngles('ingles_preguntas', 4, TipoIngles.alIngles, '¿Cuándo empiezan las clases?',
      'When do classes start?'),
  ItemIngles('ingles_preguntas', 5, TipoIngles.responder, 'Where do you live?',
      'I live in Madrid'),
];

// ---------------------------------------------------------- cómo se plantea ---

/// Lo que la voz dice para plantear el ejercicio.
String enunciadoHablado(ItemIngles item) => switch (item.tipo) {
      TipoIngles.vocabulario => 'Escribe en inglés: ${item.pide}.',
      TipoIngles.alIngles => 'Escribe en inglés: ${item.pide}.',
      TipoIngles.alEspanol => 'Traduce al español: «${item.pide}».',
      TipoIngles.completar =>
        'Completa la frase, y escríbela entera: «${_sinAyuda(item.pide)}»'
            '${_ayudaDe(item.pide)}',
      TipoIngles.responder => 'Contesta en inglés: «${item.pide}».',
      TipoIngles.escribir => 'Escribe una frase en inglés con «${item.pide}».',
    };

/// Lo que se ve escrito del ejercicio.
String enunciadoEscrito(ItemIngles item) => switch (item.tipo) {
      TipoIngles.vocabulario || TipoIngles.alIngles => '${item.pide} (en inglés)',
      TipoIngles.alEspanol => '${item.pide} (en español)',
      TipoIngles.completar => item.pide,
      TipoIngles.responder => item.pide,
      TipoIngles.escribir => 'Una frase con "${item.pide}"',
    };

/// Los huecos llevan la pista entre paréntesis —"(dos)"— para que la frase se
/// pueda plantear de oído. Al decirla en voz alta van por separado: dentro de
/// la frase inglesa sonaría a otra palabra más.
String _sinAyuda(String pide) =>
    pide.replaceAll(RegExp(r'\s*\([^)]*\)\s*'), ' ').trim();

String _ayudaDe(String pide) {
  final ayuda = RegExp(r'\(([^)]*)\)').firstMatch(pide)?.group(1);
  return ayuda == null ? '' : ' La palabra que falta es: $ayuda.';
}

/// Dos pistas por ejercicio, sacadas de la propia respuesta.
///
/// La primera empuja sin dar nada; la segunda deletrea, que en inglés es
/// justo lo que hace falta: el problema no suele ser saber la palabra, es
/// saber cómo se escribe.
List<String> pistasDe(ItemIngles item) {
  final primera = switch (item.tipo) {
    TipoIngles.vocabulario ||
    TipoIngles.alIngles =>
      'Empieza por la letra «${item.respuesta[0]}».',
    TipoIngles.alEspanol => 'Ve palabra por palabra y luego dilo como lo dirías tú.',
    TipoIngles.completar =>
      'La palabra que falta tiene ${item.respuesta.replaceAll(' ', '').length} letras.',
    TipoIngles.responder => 'Contesta con una frase entera, no con una palabra suelta.',
    TipoIngles.escribir => 'Una frase corta vale: tres o cuatro palabras.',
  };

  final segunda = item.respondeEnIngles && item.respuesta.length <= 14
      ? 'Se escribe: «${item.respuesta.split('').join(' ')}».'
      : 'Empieza así: ${_medioPrincipio(item.respuesta)}…';

  return [primera, segunda];
}

String _medioPrincipio(String respuesta) {
  final palabras = respuesta.split(' ');
  final trozo = palabras.take(palabras.length > 3 ? 2 : 1).join(' ');
  return '«$trozo»';
}

String _explicacion(ItemIngles item) {
  final solucion = item.respondeEnIngles
      ? 'Se escribe «${item.respuesta}».'
      : 'Es «${item.respuesta}».';
  return item.nota == null ? solucion : '$solucion ${item.nota}';
}

// ----------------------------------------------------------------- la tanda ---

/// Los ejercicios que se saben plantear de una destreza.
bool hayEjerciciosDe(String destrezaId) =>
    ejerciciosDeIngles.any((e) => e.destrezaId == destrezaId);

List<String> get destrezasConEjerciciosDeIngles =>
    ejerciciosDeIngles.map((e) => e.destrezaId).toSet().toList();

/// Arma una tanda de inglés.
///
/// Misma semilla, misma tanda: hace falta para poder reconstruir la actividad
/// al corregirla, igual que en matemáticas.
List<Ejercicio> tandaDeIngles(
  List<String> destrezas,
  int nivel,
  int cuantas,
  int semilla,
) {
  final azar = Azar(semilla);

  // Se agrupa por destreza y se va cogiendo de una en una, rotando: así una
  // tanda de cinco no sale entera de vocabulario.
  final porDestreza = <String, List<ItemIngles>>{};
  for (final item in ejerciciosDeIngles) {
    if (!destrezas.contains(item.destrezaId)) continue;
    // Del nivel del niño o de un escalón alrededor: ni regalado ni imposible.
    if ((item.nivel - nivel).abs() > 1) continue;
    porDestreza.putIfAbsent(item.destrezaId, () => []).add(item);
  }

  // Sin nada del nivel exacto, se abre la mano antes que dejarle sin inglés.
  if (porDestreza.isEmpty) {
    for (final item in ejerciciosDeIngles) {
      if (!destrezas.contains(item.destrezaId)) continue;
      porDestreza.putIfAbsent(item.destrezaId, () => []).add(item);
    }
  }
  if (porDestreza.isEmpty) return const [];

  final orden = porDestreza.keys.toList()..shuffle(_comoAzar(azar));
  for (final lista in porDestreza.values) {
    lista.shuffle(_comoAzar(azar));
  }

  final elegidos = <ItemIngles>[];
  for (var vuelta = 0; elegidos.length < cuantas; vuelta++) {
    var quedaAlgo = false;
    for (final destreza in orden) {
      final lista = porDestreza[destreza]!;
      if (vuelta >= lista.length) continue;
      quedaAlgo = true;
      elegidos.add(lista[vuelta]);
      if (elegidos.length == cuantas) break;
    }
    if (!quedaAlgo) break;
  }

  return [
    for (final (i, item) in elegidos.indexed)
      Ejercicio(
        numero: i + 1,
        destrezaId: item.destrezaId,
        enunciado: enunciadoEscrito(item),
        dictado: enunciadoHablado(item),
        respuesta: item.respuesta,
        respuestaDicha:
            item.respondeEnIngles ? '«${item.respuesta}»' : item.respuesta,
        pistas: pistasDe(item),
        explicacion: _explicacion(item),
      ),
  ];
}

/// `shuffle` pide un Random y aquí manda la semilla determinista de la app.
Random _comoAzar(Azar azar) => _RandomDeAzar(azar);

class _RandomDeAzar implements Random {
  _RandomDeAzar(this._azar);
  final Azar _azar;

  @override
  int nextInt(int max) => (_azar.siguiente() * max).floor();

  @override
  double nextDouble() => _azar.siguiente();

  @override
  bool nextBool() => _azar.siguiente() < 0.5;
}
