import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// La colección de Nouns: el arte, el sorteo y las rarezas.
///
/// El arte es el de Nouns (nouns.wtf), que está en dominio público. No son
/// PNG: cada rasgo viene comprimido como tiras de píxeles del mismo color, y
/// por eso los 442 dibujos caben en 148 KB y la app los lleva dentro sin
/// necesitar conexión ni una sola imagen suelta.
///
/// Nouns no tiene rarezas —todos sus rasgos salen con la misma probabilidad—,
/// así que las cuatro que ve el niño las pone RepasApp. Están en
/// `assets/nouns/catalogo.json`, que genera `characters/herramientas/`.

enum Rareza {
  normal('normal', 'Normal', 'Normal'),
  raro('raro', 'Raro', 'Rare'),
  extraRaro('extra_raro', 'Extra raro', 'Extra rare'),
  especial('especial', 'Especial', 'Special');

  const Rareza(this.clave, this.etiqueta, this.sello);

  final String clave;

  /// Como se dice en la app, que está en castellano.
  final String etiqueta;

  /// Como va impreso en el cromo.
  ///
  /// El cromo va en inglés a propósito, con los rasgos tal y como los nombra
  /// Nouns: es lo que hace que parezca un cromo de una colección de verdad y
  /// no una ficha traducida.
  final String sello;

  static Rareza porClave(String clave) =>
      values.firstWhere((r) => r.clave == clave, orElse: () => Rareza.normal);
}

class Rasgo {
  const Rasgo({
    required this.indice,
    required this.clave,
    required this.nombre,
    required this.rareza,
  });

  /// Su posición dentro del arte de Nouns. Es lo que se guarda en la base de
  /// datos, así que no puede cambiar aunque se retire un rasgo del catálogo.
  final int indice;
  final String clave;
  final String nombre;
  final Rareza rareza;
}

/// Un Noun concreto: cinco rasgos y nada más.
///
/// No guarda píxeles ni imagen. Un Noun ocupa lo que ocupa su código —
/// "1-9-5-113-3"— y el dibujo se reconstruye cuando hace falta enseñarlo.
class Noun {
  const Noun({required this.fondo, required this.rasgos});

  final int fondo;
  final Map<String, Rasgo> rasgos;

  /// Fondo y los cuatro rasgos, en orden de pintado.
  String get codigo => [
    fondo,
    for (final capa in CatalogoNouns.capas) rasgos[capa]!.indice,
  ].join('-');

  /// La del rasgo más raro que le haya tocado.
  Rareza get rareza => rasgos.values
      .map((r) => r.rareza)
      .reduce((a, b) => a.index >= b.index ? a : b);

  /// Cool o warm: los dos únicos fondos que tiene Nouns.
  String get fondoClave => fondo == 0 ? 'cool' : 'warm';
}

class CatalogoNouns {
  CatalogoNouns._({
    required this.fondos,
    required this.rasgos,
    required this.probabilidades,
    required List<String> paleta,
    required List<String> coloresDeFondo,
    required Map<String, List<String>> arte,
    required Map<String, List<double>> pesos,
  }) : _paleta = paleta,
       _coloresDeFondo = coloresDeFondo,
       _arte = arte,
       _pesos = pesos,
       _porIndice = {
         for (final e in rasgos.entries)
           e.key: {for (final r in e.value) r.indice: r},
       };

  /// El orden de pintado, que es el de Nouns: el accesorio va sobre el cuerpo,
  /// la cabeza tapa el cuello y las gafas van encima de todo.
  static const List<String> capas = [
    'bodies',
    'accessories',
    'heads',
    'glasses',
  ];

  static const int lado = 32;

  /// El orden en que se leen los rasgos en el cromo, y cómo se llaman.
  ///
  /// No es el orden de pintado: en el cromo manda la cabeza, que es lo que se
  /// mira primero, y el fondo va al final porque es lo que menos distingue a
  /// un cromo de otro.
  static const List<(String, String)> fichaCapas = [
    ('heads', 'Head'),
    ('glasses', 'Glasses'),
    ('bodies', 'Body'),
    ('accessories', 'Accessory'),
  ];

  // --- el nombre del cromo -------------------------------------------------
  //
  // Nouns no pone nombre a los suyos: se llaman "Noun 1042". Un número no se
  // dice en voz alta ni se cambia en el patio, así que cada cromo tiene aquí
  // una palabra inventada.
  //
  // Sale de sus cinco rasgos y de nada más: los mismos rasgos dan siempre el
  // mismo nombre, y no hay dos cromos distintos que compartan uno. Se
  // consigue escribiendo el número del cromo en base 85 —17 consonantes por 5
  // vocales, cuatro sílabas— porque 85^4 = 52.200.625 y cromos hay 50.124.360,
  // así que caben todos con sitio de sobra.
  static const String _consonantes = 'bcdfgjklmnprstvyz';
  static const String _vocales = 'aeiou';
  static const int _silabas = 85; // 17 x 5
  static const int _espacioNombres = 52200625; // 85^4

  /// Baraja el número antes de convertirlo en sílabas.
  ///
  /// Sin esto, dos cromos que solo se diferencian en el fondo salen con
  /// nombres casi idénticos, y el nombre deja de servir para distinguirlos de
  /// un vistazo. Multiplicar por 3^17 los reparte por todo el abecedario y
  /// sigue siendo una biyección: 3^17 no comparte factores con 85^4 = 5^4·17^4.
  static const int _mezclador = 129140163; // 3^17

  final int fondos;
  final Map<String, List<Rasgo>> rasgos;

  /// Cada cuánto sale cada rareza, calculado y no estimado a ojo. Es lo que
  /// permite comprobar que el sorteo hace lo que promete.
  final Map<Rareza, double> probabilidades;

  final List<String> _paleta;
  final List<String> _coloresDeFondo;
  final Map<String, List<String>> _arte;
  final Map<String, List<double>> _pesos;
  final Map<String, Map<int, Rasgo>> _porIndice;

  static CatalogoNouns desdeJson(String arteJson, String catalogoJson) {
    final arte = jsonDecode(arteJson) as Map<String, dynamic>;
    final cat = jsonDecode(catalogoJson) as Map<String, dynamic>;

    final masas = {
      for (final e in (cat['masas'] as Map<String, dynamic>).entries)
        Rareza.porClave(e.key): (e.value as num).toDouble(),
    };

    final rasgos = <String, List<Rasgo>>{};
    final pesos = <String, List<double>>{};
    for (final capa in capas) {
      final lista = [
        for (final r in cat['capas'][capa] as List)
          Rasgo(
            indice: r['i'] as int,
            clave: r['clave'] as String,
            nombre: r['nombre'] as String,
            rareza: Rareza.porClave(r['rareza'] as String),
          ),
      ];
      rasgos[capa] = lista;
      pesos[capa] = _pesosDe(lista, masas);
    }

    return CatalogoNouns._(
      fondos: (arte['bgcolors'] as List).length,
      rasgos: rasgos,
      pesos: pesos,
      probabilidades: _probabilidades(rasgos, pesos),
      paleta: (arte['palette'] as List).cast<String>(),
      coloresDeFondo: (arte['bgcolors'] as List).cast<String>(),
      arte: {
        for (final capa in capas)
          capa: [
            for (final i in arte['images'][capa] as List) i['data'] as String,
          ],
      },
    );
  }

  /// Reparte la masa de cada rareza entre los rasgos que la componen.
  ///
  /// Se reparte masa y no un peso fijo por rasgo porque las capas tienen
  /// tamaños muy distintos: 23 gafas y 247 cabezas. Con un peso por rasgo, la
  /// cabeza especial saldría diez veces menos que las gafas especiales sin que
  /// nadie lo hubiera decidido.
  static List<double> _pesosDe(List<Rasgo> rasgos, Map<Rareza, double> masas) {
    final cuantos = <Rareza, int>{};
    for (final r in rasgos) {
      cuantos[r.rareza] = (cuantos[r.rareza] ?? 0) + 1;
    }
    final crudo = [
      for (final r in rasgos) masas[r.rareza]! / cuantos[r.rareza]!,
    ];
    final total = crudo.reduce((a, b) => a + b);
    return [for (final p in crudo) p / total];
  }

  /// La probabilidad exacta de cada rareza.
  ///
  /// La rareza de un Noun es la de su rasgo más raro, así que se calcula por
  /// acumulación: la de "hasta raro" menos la de "hasta normal" es la de raro.
  static Map<Rareza, double> _probabilidades(
    Map<String, List<Rasgo>> rasgos,
    Map<String, List<double>> pesos,
  ) {
    final fuera = <Rareza, double>{};
    var anterior = 0.0;
    for (final rareza in Rareza.values) {
      var hasta = 1.0;
      for (final capa in capas) {
        var suma = 0.0;
        for (var i = 0; i < rasgos[capa]!.length; i++) {
          if (rasgos[capa]![i].rareza.index <= rareza.index) {
            suma += pesos[capa]![i];
          }
        }
        hasta *= suma;
      }
      fuera[rareza] = hasta - anterior;
      anterior = hasta;
    }
    return fuera;
  }

  /// "1 de cada 50".
  ///
  /// No se le enseña al niño: de un cromo se dice lo que es, no lo que cuesta,
  /// y un número al lado del nombre lo convierte en una cotización. Se sigue
  /// calculando porque es lo que demuestra que las cuatro rarezas son
  /// honradas, y `coleccion_test.dart` lo comprueba contra el sorteo.
  int unoDeCada(Rareza rareza) {
    final p = probabilidades[rareza] ?? 0;
    return p <= 0 ? 0 : (1 / p).round();
  }

  /// Un Noun al azar.
  ///
  /// Sin memoria y sin contexto: no depende del niño, ni del día, ni de cómo
  /// le haya ido la actividad. Es deliberado. Si el bicho dependiera de lo
  /// bien que ha ido el dictado, dejaría de ser un premio y sería otra nota.
  Noun tirar([Random? azar]) {
    final r = azar ?? Random.secure();
    return Noun(
      fondo: r.nextInt(fondos),
      rasgos: {
        for (final capa in capas)
          capa: _elegir(rasgos[capa]!, _pesos[capa]!, r),
      },
    );
  }

  static Rasgo _elegir(List<Rasgo> rasgos, List<double> pesos, Random azar) {
    var tirada = azar.nextDouble();
    for (var i = 0; i < rasgos.length; i++) {
      tirada -= pesos[i];
      if (tirada <= 0) return rasgos[i];
    }
    return rasgos.last;
  }

  /// Reconstruye un Noun a partir de lo guardado en la base de datos.
  ///
  /// Devuelve null si el código no se entiende. Puede pasar de verdad: si un
  /// día se retira un rasgo del catálogo, los Nouns que ya lo tenían siguen en
  /// la colección de algún niño, y perder su ficha entera es peor que no
  /// enseñarlo.
  Noun? desdeCodigo(String codigo) {
    final partes = codigo.split('-');
    if (partes.length != capas.length + 1) return null;

    final fondo = int.tryParse(partes.first);
    if (fondo == null || fondo < 0 || fondo >= fondos) return null;

    final elegidos = <String, Rasgo>{};
    for (var i = 0; i < capas.length; i++) {
      final indice = int.tryParse(partes[i + 1]);
      final rasgo = indice == null ? null : _porIndice[capas[i]]![indice];
      if (rasgo == null) return null;
      elegidos[capas[i]] = rasgo;
    }
    return Noun(fondo: fondo, rasgos: elegidos);
  }

  /// El número del cromo: uno distinto para cada combinación de rasgos.
  ///
  /// Se cuenta sobre TODOS los rasgos que tiene el arte de Nouns, no sobre los
  /// que el catálogo deja pasar. Así el nombre de un cromo ya guardado no
  /// cambia el día que se retire un rasgo del sorteo.
  int numeroDe(Noun noun) {
    var n = 0;
    for (final capa in capas) {
      n = n * _arte[capa]!.length + noun.rasgos[capa]!.indice;
    }
    return n * fondos + noun.fondo;
  }

  /// El nombre del cromo: "Prepepodo", "Magucebo", "Jatoyubi".
  String nombreDe(Noun noun) {
    var n = (numeroDe(noun) * _mezclador) % _espacioNombres;
    final silabas = <String>[];
    for (var i = 0; i < 4; i++) {
      final j = n % _silabas;
      n ~/= _silabas;
      silabas.add('${_consonantes[j ~/ 5]}${_vocales[j % 5]}');
    }
    final palabra = silabas.reversed.join();
    return palabra[0].toUpperCase() + palabra.substring(1);
  }

  /// El color del paspartú: el fondo con el que Nouns dibuja a los suyos.
  int colorDeFondo(Noun noun) => _rgb(_coloresDeFondo[noun.fondo]);

  /// El color que manda en el dibujo, para teñir la banda del título.
  ///
  /// Es el más repetido sin contar el fondo. Con esto no hay dos cromos
  /// iguales aunque compartan rareza, que es lo que hace que apetezca
  /// tenerlos todos: el marco lo pone la rareza y la banda, el dibujo.
  int colorVivoDe(Noun noun) => _vivos[noun.codigo] ??= _calcularVivo(noun);

  final Map<String, int> _vivos = {};

  int _calcularVivo(Noun noun) {
    final fondo = colorDeFondo(noun);
    final pixeles = this.pixeles(noun);
    final cuantos = <int, int>{};
    for (var i = 0; i < pixeles.length; i += 4) {
      final rgb = pixeles[i] << 16 | pixeles[i + 1] << 8 | pixeles[i + 2];
      if (rgb == fondo) continue;
      cuantos[rgb] = (cuantos[rgb] ?? 0) + 1;
    }
    if (cuantos.isEmpty) return fondo;

    var mejor = fondo;
    var mas = -1;
    for (final e in cuantos.entries) {
      // A igualdad de píxeles gana el color más bajo, y no el que salga
      // primero del mapa: si no, la banda cambiaría de color entre ejecuciones.
      if (e.value > mas || (e.value == mas && e.key < mejor)) {
        mejor = e.key;
        mas = e.value;
      }
    }
    return mejor;
  }

  /// Si sobre ese color hay que escribir en blanco o en tinta oscura.
  static bool esClaro(int rgb) {
    final r = (rgb >> 16 & 0xff) / 255;
    final g = (rgb >> 8 & 0xff) / 255;
    final b = (rgb & 0xff) / 255;
    return 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.58;
  }

  /// El dibujo, 32x32 en RGBA, listo para volcar en una imagen.
  Uint8List pixeles(Noun noun) {
    final lienzo = Uint8List(lado * lado * 4);
    _rellenar(lienzo, _rgb(_coloresDeFondo[noun.fondo]));
    for (final capa in capas) {
      _pintar(lienzo, _arte[capa]![noun.rasgos[capa]!.indice]);
    }
    return lienzo;
  }

  static void _rellenar(Uint8List lienzo, int rgb) {
    for (var i = 0; i < lienzo.length; i += 4) {
      lienzo[i] = rgb >> 16 & 0xff;
      lienzo[i + 1] = rgb >> 8 & 0xff;
      lienzo[i + 2] = rgb & 0xff;
      lienzo[i + 3] = 0xff;
    }
  }

  static int _rgb(String hex) => int.parse(hex, radix: 16);

  /// Pinta un rasgo encima de lo que ya hay.
  ///
  /// El formato es el de la cadena on-chain de Nouns: un byte de paleta, la
  /// caja que ocupa el dibujo (arriba, derecha, abajo, izquierda) y después
  /// parejas de (cuántos píxeles seguidos, qué color). El color 0 no es un
  /// color: es "aquí no pinto nada".
  void _pintar(Uint8List lienzo, String datos) {
    final d = datos.startsWith('0x') ? datos.substring(2) : datos;
    final arriba = int.parse(d.substring(2, 4), radix: 16);
    final derecha = int.parse(d.substring(4, 6), radix: 16);
    final izquierda = int.parse(d.substring(8, 10), radix: 16);

    var x = izquierda;
    var y = arriba;
    for (var i = 10; i + 4 <= d.length; i += 4) {
      final largo = int.parse(d.substring(i, i + 2), radix: 16);
      final color = int.parse(d.substring(i + 2, i + 4), radix: 16);
      final rgb = color == 0 ? null : _rgb(_paleta[color]);

      // Un tramo puede seguir en la fila siguiente: en la cabeza de canguro
      // hay tres que lo hacen. Pintarlo entero en la misma fila deja el dibujo
      // escalonado, cada fila un poco más a la derecha que la anterior.
      var resto = largo;
      while (resto > 0) {
        final cabe = min(resto, derecha - x);
        if (rgb != null && y >= 0 && y < lado) {
          for (var k = 0; k < cabe; k++) {
            final px = x + k;
            if (px < 0 || px >= lado) continue;
            final p = (y * lado + px) * 4;
            lienzo[p] = rgb >> 16 & 0xff;
            lienzo[p + 1] = rgb >> 8 & 0xff;
            lienzo[p + 2] = rgb & 0xff;
            lienzo[p + 3] = 0xff;
          }
        }
        x += cabe;
        resto -= cabe;
        if (x >= derecha) {
          x = izquierda;
          y++;
        }
      }
    }
  }
}
