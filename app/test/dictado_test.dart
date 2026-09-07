import 'package:flutter_test/flutter_test.dart';
import 'package:repasapp/contenido/dictados.dart';
import 'package:repasapp/dominio/actividades.dart';
import 'package:repasapp/dominio/guion.dart';
import 'package:repasapp/voz/locutora.dart';

/// Cómo se dicta a un niño pequeño: despacio, corto y sin prisa.
void main() {
  Dictado deNivel(int nivel) => dictados.firstWhere((d) => d.nivel == nivel);

  test('en los cursos bajos se dicta menos texto', () {
    final pequeno = deNivel(1);
    final mayor = deNivel(5);

    expect(pequeno.frasesDictadas, hasLength(3));
    expect(pequeno.frasesDictadas.length,
        lessThan(pequeno.fragmentos.length),
        reason: 'un texto de cuatro frases se le hace larguísimo');
    expect(mayor.frasesDictadas, mayor.fragmentos,
        reason: 'de tercero en adelante se dicta entero');
  });

  test('se corrige exactamente lo que se ha dictado', () {
    for (final d in dictados) {
      final dictadas = d.frasesDictadas.join(' ');
      expect(d.texto, dictadas,
          reason: '${d.id}: corregir una frase que no se ha dictado es '
              'suspender al niño por algo que nunca oyó');
      for (final clave in d.palabrasClaveDictadas) {
        expect(d.texto.toLowerCase(), contains(clave.toLowerCase()),
            reason: '${d.id}: $clave');
      }
    }
  });

  test('el guion dicta una frase por paso y a ritmo de niño pequeño', () {
    final pequeno = deNivel(1);
    final guion = guionDictado(pequeno);
    final fragmentos = guion.pasos.whereType<Fragmento>().toList();

    expect(fragmentos, hasLength(pequeno.frasesDictadas.length));
    expect(fragmentos.map((f) => f.texto), pequeno.frasesDictadas);
    expect(guion.velocidadInicial, Velocidad.lenta);
    expect(guionDictado(deNivel(5)).velocidadInicial, Velocidad.normal);
  });

  test('nada avanza solo: siempre hay un botón para seguir', () {
    // Antes había cuenta atrás y la frase siguiente entraba sola. Para un niño
    // que todavía dibuja cada letra eso es una carrera perdida.
    final guion = guionDictado(deNivel(1));
    expect(guion.comandosGlobales, contains(Comando.continua));
    expect(guion.comandosGlobales, contains(Comando.repite));
    expect(guion.comandosGlobales, contains(Comando.masDespacio));
  });

  test('dictar va más despacio que hablar, y "más despacio" aún más', () {
    expect(Velocidad.lenta.tasa, lessThan(Velocidad.normal.tasa));
    expect(Velocidad.normal.tasa, lessThan(Locutora.tasaAlExplicar));
    expect(Velocidad.lenta.pausaEntrePalabras,
        greaterThan(Velocidad.normal.pausaEntrePalabras));
    // Un segundo largo entre palabra y palabra: es lo que tarda la mano.
    expect(Velocidad.lenta.pausaEntrePalabras, greaterThanOrEqualTo(1200));
  });
}
