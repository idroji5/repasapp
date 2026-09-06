import 'package:flutter_test/flutter_test.dart';
import 'package:repasapp/contenido/dictados.dart';
import 'package:repasapp/correccion/dictado.dart';
import 'package:repasapp/correccion/ortografia.dart';
import 'package:repasapp/dominio/curriculo.dart';
import 'package:repasapp/voz/frases.dart';

void main() {
  test('la eñe no es una ene con adorno', () {
    // Si quitar la tilde convirtiera "año" en "ano", la app daría por buena una
    // falta grave.
    expect(sinTildes('año'), 'año');
    expect(sinTildes('había'), 'habia');
  });

  test('distingue aguda, llana y esdrújula', () {
    expect(tipoAcentual('balón'), 'aguda');
    expect(tipoAcentual('árbol'), 'llana');
    expect(tipoAcentual('simpático'), 'esdrujula');
    expect(tipoAcentual('casa'), isNull);
  });

  test('reconoce qué regla pone a prueba cada palabra', () {
    expect(ejercita('h_frecuente', 'había'), isTrue);
    expect(ejercita('h_frecuente', 'campo'), isFalse);
    expect(ejercita('b_verbos_aba', 'cocinaba'), isTrue);
    expect(ejercita('b_verbos_aba', 'bien'), isFalse);
    expect(ejercita('r_rr', 'perro'), isTrue);
    expect(ejercita('r_rr', 'pero'), isFalse);
    expect(ejercita('m_antes_p_b', 'campo'), isTrue);
    expect(ejercita('m_antes_p_b', 'canta'), isFalse);
    expect(ejercita('tilde_esdrujulas', 'simpático'), isTrue);
    expect(ejercita('tilde_esdrujulas', 'balón'), isFalse);
    expect(ejercita('dieresis', 'pingüino'), isTrue);
    expect(ejercita('c_z', 'zapato'), isTrue);
  });

  test('imputa la palabra a la destreza que el dictado trabaja', () {
    final falta = faltaDePalabra('balón', ['tilde_agudas', 'mayuscula_inicial']);
    expect(falta.tipo, TipoFalta.tilde);
    expect(falta.destrezaId, 'tilde_agudas');
  });

  test('entre dos reglas posibles gana la de la letra, no la mayúscula', () {
    // "Había" empieza por mayúscula y lleva hache. Lo que se le ha caído es la
    // hache; decirle que empieza por mayúscula no le enseña nada.
    final falta = faltaDePalabra('Había', ['mayuscula_inicial', 'h_frecuente']);
    expect(falta.destrezaId, 'h_frecuente');
  });

  test('los verbos en -aba van a su regla, no a la general de b y v', () {
    final falta = faltaDePalabra('cocinaba', ['b_v_reglas', 'b_verbos_aba']);
    expect(falta.destrezaId, 'b_verbos_aba');
  });

  test('la tilde se explica aunque el dictado no la tuviera entre sus destrezas', () {
    final falta = faltaDePalabra('árbol', ['h_frecuente']);
    expect(falta.tipo, TipoFalta.tilde);
    expect(falta.destrezaId, 'tilde_llanas');
  });

  test('una palabra sin regla no se inventa una explicación', () {
    final falta = faltaDePalabra('mesa', ['tilde_agudas']);
    expect(falta.tipo, TipoFalta.ortografia);
    expect(falta.destrezaId, isNull);
  });

  test('toda falta se puede leer en voz alta', () {
    for (final tipo in TipoFalta.values) {
      final texto = razonDe(Falta(esperado: 'había', tipo: tipo));
      expect(texto, isNotEmpty);
    }
  });

  test('la nota sale de las palabras que ha tachado', () {
    final dictado = dictadoPorId('dic-101')!;
    final c = corregirDictadoMarcado(dictado, const ['campo', 'queso', 'mesa']);

    expect(c.faltas, 3);
    expect(c.totalPalabras, dictado.numeroDePalabras);
    expect(c.aciertos, dictado.numeroDePalabras - 3);
    expect(c.perfecto, isFalse);
  });

  test('cada palabra tachada se explica', () {
    final dictado = dictadoPorId('dic-101')!;
    final c = corregirDictadoMarcado(dictado, const ['campo', 'queso']);

    expect(c.explicadas.length, 2);
    expect(c.explicadas.first.esperado, 'campo');
    expect(c.explicadas.first.destrezaId, 'm_antes_p_b');
  });

  test('también se puede tachar una palabra que no era de las difíciles', () {
    // El niño puede fallar cualquier palabra, no solo las que el dictado pone a
    // prueba. De esas la app no tiene regla que dar, pero sí cuentan.
    final dictado = dictadoPorId('dic-101')!;
    final c = corregirDictadoMarcado(dictado, const ['mesa']);

    expect(c.faltas, 1);
    expect(c.explicadas.single.tipo, TipoFalta.ortografia);
    expect(c.explicadas.single.destrezaId, isNull);
  });

  test('sin tachar nada, el dictado es perfecto', () {
    final dictado = dictadoPorId('dic-101')!;
    final c = corregirDictadoMarcado(dictado, const []);
    expect(c.perfecto, isTrue);
    expect(c.aciertos, c.totalPalabras);
  });

  test('el banco tiene textos de sobra para no repetirse en semanas', () {
    for (var nivel = 1; nivel <= 5; nivel++) {
      final delNivel = dictados.where((d) => d.nivel == nivel).length;
      expect(delNivel, greaterThanOrEqualTo(10),
          reason: 'el nivel $nivel se queda corto y se repetirá enseguida');
    }
    expect(dictados.map((d) => d.id).toSet(), hasLength(dictados.length),
        reason: 'hay ids repetidos');
  });

  test('las palabras difíciles están de verdad en el texto', () {
    // Si una palabra clave no aparece en el dictado, no se puede tocar para
    // marcarla: el aviso en negrita señalaría a algo que no existe.
    final fantasmas = <String>[];
    for (final dictado in dictados) {
      final texto = palabrasDe(dictado.texto).map((p) => p.toLowerCase()).toSet();
      for (final clave in dictado.palabrasClave) {
        if (!texto.contains(clave.toLowerCase())) {
          fantasmas.add('${dictado.id}: $clave');
        }
      }
    }
    expect(fantasmas, isEmpty);
  });

  test('cada dictado solo usa destrezas que existen', () {
    final conocidas = destrezas.map((d) => d.id).toSet();
    for (final dictado in dictados) {
      for (final id in dictado.destrezas) {
        expect(conocidas, contains(id), reason: '${dictado.id}: $id');
      }
      expect(dictado.fragmentos.length, greaterThanOrEqualTo(3),
          reason: '${dictado.id} es demasiado corto');
      expect(dictado.palabrasClave, isNotEmpty, reason: dictado.id);
    }
  });

  test('las palabras clave de todos los dictados se saben explicar', () {
    // Si una palabra trampa no encaja en ninguna destreza del dictado que la
    // contiene, la app se queda sin nada que enseñar justo cuando el niño la
    // marca: es el peor momento para no tener respuesta.
    final sinRegla = <String>[];
    for (final dictado in dictados) {
      for (final palabra in dictado.palabrasClave) {
        final falta = faltaDePalabra(palabra, dictado.destrezas);
        if (falta.destrezaId == null) sinRegla.add('${dictado.id}: $palabra');
      }
    }
    expect(sinRegla, isEmpty);
  });
}
