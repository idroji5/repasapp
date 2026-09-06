/// Números a letras en castellano.
///
/// El motor de voz del móvil lee "742" razonablemente bien, pero no controlamos
/// cómo. Generando nosotros el texto decidimos exactamente qué oye el niño
/// ("setecientos cuarenta y dos dividido entre siete") y suena igual en
/// cualquier teléfono. Cubre 0 – 999.999.999 y decimales.
library;

const _unidades = [
  'cero', 'uno', 'dos', 'tres', 'cuatro', 'cinco', 'seis', 'siete', 'ocho',
  'nueve', 'diez', 'once', 'doce', 'trece', 'catorce', 'quince', 'dieciséis',
  'diecisiete', 'dieciocho', 'diecinueve', 'veinte', 'veintiuno', 'veintidós',
  'veintitrés', 'veinticuatro', 'veinticinco', 'veintiséis', 'veintisiete',
  'veintiocho', 'veintinueve',
];

const _decenas = [
  '', '', 'veinte', 'treinta', 'cuarenta', 'cincuenta',
  'sesenta', 'setenta', 'ochenta', 'noventa',
];

const _centenas = [
  '', 'ciento', 'doscientos', 'trescientos', 'cuatrocientos', 'quinientos',
  'seiscientos', 'setecientos', 'ochocientos', 'novecientos',
];

/// "uno" se apocopa a "un" delante de un sustantivo: veintiún mil, treinta y un
/// millones.
String _apocopar(String texto) {
  if (texto == 'uno') return 'un';
  if (texto.endsWith('veintiuno')) {
    return '${texto.substring(0, texto.length - 'veintiuno'.length)}veintiún';
  }
  if (texto.endsWith(' y uno')) {
    return '${texto.substring(0, texto.length - ' y uno'.length)} y un';
  }
  return texto;
}

String _menorDeCien(int n) {
  if (n < 30) return _unidades[n];
  final d = n ~/ 10;
  final u = n % 10;
  return u == 0 ? _decenas[d] : '${_decenas[d]} y ${_unidades[u]}';
}

String _menorDeMil(int n) {
  if (n == 100) return 'cien';
  if (n < 100) return _menorDeCien(n);
  final c = n ~/ 100;
  final r = n % 100;
  return r == 0 ? _centenas[c] : '${_centenas[c]} ${_menorDeCien(r)}';
}

String _menorDeMillon(int n) {
  if (n < 1000) return _menorDeMil(n);
  final miles = n ~/ 1000;
  final r = n % 1000;
  final cabeza = miles == 1 ? 'mil' : '${_apocopar(_menorDeMil(miles))} mil';
  return r == 0 ? cabeza : '$cabeza ${_menorDeMil(r)}';
}

/// Lectura en castellano de un entero no negativo.
String enteroALetras(int n) {
  if (n < 0) {
    throw RangeError('enteroALetras espera un entero no negativo, recibió $n');
  }
  if (n < 1000000) return _menorDeMillon(n);

  final millones = n ~/ 1000000;
  final r = n % 1000000;
  final cabeza = millones == 1
      ? 'un millón'
      : '${_apocopar(_menorDeMillon(millones))} millones';
  return r == 0 ? cabeza : '$cabeza ${_menorDeMillon(r)}';
}

/// Lectura de cualquier número, con signo y decimales. La parte decimal se lee
/// como número si tiene una o dos cifras ("dos coma veinticinco") y cifra a
/// cifra si tiene más.
String numeroALetras(num n) {
  final signo = n < 0 ? 'menos ' : '';
  final abs = n.abs();
  final entera = abs.truncate();

  if (abs == entera) return '$signo${enteroALetras(entera)}';

  final texto = abs.toString();
  final decimales = texto.contains('.') ? texto.split('.')[1] : '';
  final lectura = decimales.length <= 2
      ? enteroALetras(int.parse(decimales))
      : decimales.split('').map((d) => _unidades[int.parse(d)]).join(' ');

  return '$signo${enteroALetras(entera)} coma $lectura';
}

const _ordinalesFemeninos = [
  'primera', 'segunda', 'tercera', 'cuarta', 'quinta',
  'sexta', 'séptima', 'octava', 'novena', 'décima',
];

/// Ordinales que usa la voz al enumerar ejercicios: "Primera:", "Segunda:"…
String ordinalFemenino(int n) => n >= 1 && n <= _ordinalesFemeninos.length
    ? _ordinalesFemeninos[n - 1]
    : 'número ${enteroALetras(n)}';

// ------------------------------------- números dentro de una frase escrita ---

final RegExp _milesConPunto = RegExp(r'\b(\d{1,3})(?:\.(\d{3}))+\b');
final RegExp _importeEnEuros = RegExp(r'(\d+),(\d{2})\s*€');
final RegExp _enEuros = RegExp(r'(\d+)\s+(euros?)');
final RegExp _eurosRedondos = RegExp(r'(\d+)\s*€');
final RegExp _cualquierNumero = RegExp(r'\d+(?:,\d+)?');

/// Un numeral que va delante de un nombre concuerda con él: son "veintiún
/// cromos", "veintiuna canicas" y "doscientas galletas", nunca "veintiuno
/// galletas". La app le está enseñando a escribir al niño; no puede hablarle
/// mal.
String numeralAnteNombre(String numeral, {bool femenino = false}) {
  if (femenino) {
    final t = numeral.replaceAll('cientos', 'cientas');
    return t.endsWith('uno') ? '${t.substring(0, t.length - 3)}una' : t;
  }
  if (numeral.endsWith('veintiuno')) {
    return '${numeral.substring(0, numeral.length - 9)}veintiún';
  }
  return numeral.endsWith('uno')
      ? '${numeral.substring(0, numeral.length - 3)}un'
      : numeral;
}

/// "dos euros con cuarenta céntimos", que es como se dice un precio.
String importeALetras(int euros, int centimos) {
  final parte =
      '${numeralAnteNombre(enteroALetras(euros))} ${euros == 1 ? "euro" : "euros"}';
  if (centimos == 0) return parte;
  return '$parte con ${enteroALetras(centimos)} céntimos';
}

/// Reescribe una frase para leerla en voz alta, pasando a letras los números
/// que lleva en cifras.
///
/// Un problema con enunciado se enseña escrito —"Ana compra 3 cajas de 12
/// lápices"— porque en la pantalla las cifras se leen de un vistazo. Pero al
/// oído hay que decirlo con todas las letras: si se le pasa "12" al motor de
/// voz, cada teléfono lo lee a su manera y no controlamos qué oye el niño.
///
/// `femenino` es el género de aquello que se está contando, para que los
/// numerales concuerden: "doscientas galletas", no "doscientos galletas".
String numerosALetras(String texto, {bool femenino = false}) {
  var t = texto.replaceAllMapped(
      _milesConPunto, (m) => m.group(0)!.replaceAll('.', ''));
  t = t.replaceAllMapped(
      _importeEnEuros,
      (m) => importeALetras(int.parse(m.group(1)!), int.parse(m.group(2)!)));
  t = t.replaceAllMapped(_eurosRedondos,
      (m) => importeALetras(int.parse(m.group(1)!), 0));
  t = t.replaceAllMapped(
      _enEuros, (m) => '${enteroALetras(int.parse(m.group(1)!))} ${m.group(2)}');
  return t.replaceAllMapped(_cualquierNumero, (m) {
    final valor = num.parse(m.group(0)!.replaceAll(',', '.'));
    final letras = numeroALetras(valor);
    // Solo los enteros van delante de un nombre; un decimal se lee tal cual.
    return valor is int || valor == valor.truncate()
        ? numeralAnteNombre(letras, femenino: femenino)
        : letras;
  });
}
