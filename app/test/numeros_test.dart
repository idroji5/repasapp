import 'package:flutter_test/flutter_test.dart';
import 'package:repasapp/contenido/numeros.dart';

void main() {
  test('unidades y decenas', () {
    expect(enteroALetras(0), 'cero');
    expect(enteroALetras(15), 'quince');
    expect(enteroALetras(16), 'dieciséis');
    expect(enteroALetras(21), 'veintiuno');
    expect(enteroALetras(31), 'treinta y uno');
    expect(enteroALetras(99), 'noventa y nueve');
  });

  test('centenas', () {
    expect(enteroALetras(100), 'cien');
    expect(enteroALetras(101), 'ciento uno');
    expect(enteroALetras(500), 'quinientos');
    expect(enteroALetras(742), 'setecientos cuarenta y dos');
    expect(enteroALetras(999), 'novecientos noventa y nueve');
  });

  test('millares, con apócope de uno', () {
    expect(enteroALetras(1000), 'mil');
    expect(enteroALetras(21000), 'veintiún mil');
    expect(enteroALetras(31000), 'treinta y un mil');
    expect(enteroALetras(100000), 'cien mil');
    expect(enteroALetras(345678),
        'trescientos cuarenta y cinco mil seiscientos setenta y ocho');
  });

  test('millones', () {
    expect(enteroALetras(1000000), 'un millón');
    expect(enteroALetras(2000000), 'dos millones');
  });

  test('negativos y decimales', () {
    expect(numeroALetras(-5), 'menos cinco');
    expect(numeroALetras(3.5), 'tres coma cinco');
    expect(numeroALetras(2.25), 'dos coma veinticinco');
  });

  test('ordinales femeninos', () {
    expect(ordinalFemenino(1), 'primera');
    expect(ordinalFemenino(5), 'quinta');
  });
}
