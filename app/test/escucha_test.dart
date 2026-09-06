import 'package:flutter_test/flutter_test.dart';
import 'package:repasapp/dominio/guion.dart';
import 'package:repasapp/voz/escucha.dart';

/// Lo que el reconocedor de voz devuelve es una frase entera y desordenada
/// ("no, esa no me ha salido"), no la palabra suelta que esperamos. Estas
/// pruebas fijan cómo se decide qué ha querido decir.
void main() {
  bool oye(String dicho, Comando comando) =>
      Escucha.seOye(dicho.toLowerCase(), comando.comoSeDice);

  test('las palabras cortas se buscan enteras, no como trozo', () {
    // Si "sí" valiera como trozo, "casi" y "sino" pasarían por un sí.
    expect(oye('casi', Comando.loTengo), isFalse);
    expect(oye('sino', Comando.loTengo), isFalse);
    expect(oye('si', Comando.loTengo), isTrue);
    // Y si "vale" valiera como trozo, lo harían "avales" o "valentía".
    expect(oye('avales', Comando.listo), isFalse);
    expect(oye('vale', Comando.listo), isTrue);
  });

  test('las expresiones sí valen como trozo de la frase', () {
    expect(oye('venga, otra vez', Comando.repite), isTrue);
    expect(oye('ya he terminado', Comando.corregir), isTrue);
    expect(oye('creo que no lo veo', Comando.otraPista), isTrue);
  });

  test('reconoce las formas de decir lo mismo', () {
    expect(oye('sigue', Comando.continua), isTrue);
    expect(oye('siguiente', Comando.continua), isTrue);
    expect(oye('mas lento por favor', Comando.masDespacio), isTrue);
    expect(oye('preparado', Comando.listo), isTrue);
  });

  test('sin micrófono no se oye nada y todo sigue funcionando', () async {
    final sorda = Escucha.sorda();
    expect(await sorda.preparar(), isFalse);
    expect(sorda.disponible, isFalse);
    expect(await sorda.escucharComando([Comando.listo, Comando.repite]), isNull);
  });
}
