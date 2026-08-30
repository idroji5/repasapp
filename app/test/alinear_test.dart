import 'package:flutter_test/flutter_test.dart';
import 'package:repasapp/correccion/alinear.dart';

void main() {
  test('clasifica el tipo de fallo ortográfico', () {
    expect(clasificar('había', 'habia'), TipoFalta.tilde);
    expect(clasificar('también', 'tambien'), TipoFalta.tilde);
    expect(clasificar('hola', 'ola'), TipoFalta.h);
    expect(clasificar('bailado', 'vailado'), TipoFalta.bV);
    expect(clasificar('llevaba', 'yevaba'), TipoFalta.llY);
    expect(clasificar('jardín', 'gardin'), TipoFalta.gJ);
    expect(clasificar('zapato', 'sapato'), TipoFalta.cZ);
    expect(clasificar('perro', 'pero'), TipoFalta.rRr);
    expect(clasificar('campo', 'canpo'), TipoFalta.mAntesPB);
    expect(clasificar('Rosa', 'rosa'), TipoFalta.mayuscula);
    expect(clasificar('ventana', 'mesa'), TipoFalta.ortografia);
  });

  test('la eñe no es una ene con adorno', () {
    // Quitar la tilde no puede convertir "año" en "ano": si lo hiciera, la app
    // daría por buena una falta grave.
    expect(sinTildes('año'), 'año');
    expect(clasificar('año', 'ano'), TipoFalta.ortografia);
    expect(clasificar('pequeño', 'pequeno'), TipoFalta.ortografia);
  });

  test('distingue aguda, llana y esdrújula', () {
    expect(tipoAcentual('balón'), 'aguda');
    expect(tipoAcentual('árbol'), 'llana');
    expect(tipoAcentual('simpático'), 'esdrujula');
    expect(tipoAcentual('casa'), isNull);
  });

  test('imputa la tilde a la destreza correcta', () {
    final c = corregirDictado('Cayó un balón.', 'Cayo un balon.');
    expect(c.faltas.length, 2);
    expect(c.faltas.every((f) => f.tipo == TipoFalta.tilde), isTrue);
    expect(c.faltas.every((f) => f.destrezaId == 'tilde_agudas'), isTrue);
  });

  test('la tilde diacrítica va a su propia destreza', () {
    final c = corregirDictado('Pero tú sabes.', 'Pero tu sabes.');
    expect(c.faltas.first.destrezaId, 'tilde_diacritica');
  });

  test('los verbos en -aba se imputan a su regla, no a b/v general', () {
    final c = corregirDictado('Ella cocinaba.', 'Ella cocinava.');
    expect(c.faltas.first.tipo, TipoFalta.bV);
    expect(c.faltas.first.destrezaId, 'b_verbos_aba');
  });

  test('un dictado perfecto no tiene faltas', () {
    const texto = 'Mi abuelo vive en el campo. Tiene un perro pequeño.';
    final c = corregirDictado(texto, texto);
    expect(c.faltas, isEmpty);
    expect(c.aciertos, c.totalPalabras);
  });

  test('detecta palabras omitidas y añadidas', () {
    final c = corregirDictado('Mi abuelo vive en el campo.', 'Mi abuelo vive el campo.');
    expect(c.faltas.firstWhere((f) => f.tipo == TipoFalta.omision).esperado, 'en');

    final c2 = corregirDictado('Mi abuelo vive.', 'Mi querido abuelo vive.');
    expect(c2.faltas.any((f) => f.tipo == TipoFalta.adicion && f.escrito == 'querido'), isTrue);
  });

  test('detecta que el niño separó una palabra en dos', () {
    final c = corregirDictado(
        'Sonreía porque todo salió bien.', 'Sonreía por que todo salió bien.');
    final sep = c.faltas.firstWhere((f) => f.tipo == TipoFalta.unionSeparacion);
    expect(sep.esperado, 'porque');
    expect(sep.escrito, 'por que');
    expect(sep.destrezaId, 'porque');
  });

  test('detecta que el niño unió dos palabras en una', () {
    final c = corregirDictado('Vamos a ver si hay entradas.', 'Vamos aver si hay entradas.');
    final sep = c.faltas.firstWhere((f) => f.tipo == TipoFalta.unionSeparacion);
    expect(sep.esperado, 'a ver');
    expect(sep.escrito, 'aver');
  });

  test('avisa de la puntuación que falta, pero sin inundar', () {
    final c = corregirDictado('¿Quieres jugar? ¡Vamos, corre!', 'Quieres jugar Vamos corre');
    final puntuacion = c.faltas.where((f) => f.tipo == TipoFalta.puntuacion).toList();
    expect(puntuacion, isNotEmpty);
    expect(puntuacion.length, lessThanOrEqualTo(2));
  });

  test('una palabra puede acumular dos faltas: falta la hache y la be es uve', () {
    final c = corregirDictado('No había ido.', 'No avía ido.');
    expect(c.faltas.first.tipo, TipoFalta.h);
    expect(c.faltas.first.tambien, [TipoFalta.bV]);
    expect(c.faltas.first.destrezaId, 'h_frecuente');
  });

  test('caso realista: un dictado de nivel 5 con tres faltas', () {
    const referencia = 'Me preguntabas por qué no había ido. Sí, tenía muchas ganas de verte.';
    const escrito = 'Me preguntabas por que no avía ido. Si, tenía muchas ganas de verte.';
    final c = corregirDictado(referencia, escrito);

    expect(c.faltas.length, 3);
    expect(c.faltas.map((f) => f.esperado).toList(), ['qué', 'había', 'Sí']);
    expect(c.faltas.map((f) => f.destrezaId).toList(),
        ['tilde_diacritica', 'h_frecuente', 'tilde_diacritica']);
    expect(c.totalPalabras, 13);
    expect(c.aciertos, 10);
  });
}
