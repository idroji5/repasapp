import 'package:flutter/material.dart';

/// Lenguaje visual de RepasApp.
///
/// Dos criterios mandan sobre todo lo demás:
///
/// 1. El niño mira la pantalla de reojo, con las manos ocupadas en el papel.
///    Por eso el texto es grande, el contraste alto y los botones enormes: se
///    tienen que poder acertar sin dejar el lápiz.
/// 2. Esto no es un juego. Nada de colores chillones ni de confeti. Es una
///    herramienta de estudio y tiene que transmitir calma, no excitación.
class Tema {
  const Tema._();

  // Papel y tinta: el fondo tira a crema, como un cuaderno.
  static const Color fondo = Color(0xFFFDF8F3);
  static const Color tarjeta = Color(0xFFFFFFFF);
  static const Color tinta = Color(0xFF2B2118);
  static const Color tintaSuave = Color(0xFF7A6A5C);
  static const Color borde = Color(0xFFEADFD2);

  /// Verde profundo para todo lo que hay que pulsar. Serio y legible.
  static const Color accion = Color(0xFF0F766E);
  static const Color accionSuave = Color(0xFFD3EDE9);

  /// Ámbar para la racha y los logros.
  static const Color logro = Color(0xFFB45309);
  static const Color logroSuave = Color(0xFFFDF0D5);

  static const Color acierto = Color(0xFF15803D);
  static const Color aciertoSuave = Color(0xFFDCF5E3);
  static const Color fallo = Color(0xFFB91C1C);
  static const Color falloSuave = Color(0xFFFDECEC);

  static const Color dictado = Color(0xFF4F46E5);
  static const Color matematicas = Color(0xFF0F766E);
  static const Color ingles = Color(0xFFB45309);

  static const double radio = 20;

  /// Letra ligada, la del cuaderno, para enseñarle al niño el texto del
  /// dictado. Ver escrito "había" con la misma letra con la que él acaba de
  /// escribirlo hace la comparación inmediata; en tipografía de pantalla es un
  /// texto más que hay que traducir mentalmente.
  static const String caligrafica = 'Caligrafica';

  /// Manuscrita sin ligar para números y cuentas. La ligada es preciosa para
  /// una frase y un desastre para un 4, un 7 o un 1: en una corrección el niño
  /// tiene que leer la cifra sin dudar ni un segundo.
  static const String manuscrita = 'Manuscrita';

  /// Texto de dictado, con la letra del cuaderno.
  static TextStyle deCuaderno({
    double tamano = 30,
    Color color = tinta,
    FontWeight peso = FontWeight.w400,
    TextDecoration? decoracion,
  }) =>
      TextStyle(
        fontFamily: caligrafica,
        fontSize: tamano,
        height: 1.5,
        color: color,
        fontWeight: peso,
        decoration: decoracion,
        decorationColor: color,
        decorationThickness: 2,
      );

  /// Cuentas y resultados, con la manuscrita legible.
  static TextStyle deNumeros({
    double tamano = 26,
    Color color = tinta,
    FontWeight peso = FontWeight.w400,
  }) =>
      TextStyle(
        fontFamily: manuscrita,
        fontSize: tamano,
        height: 1.35,
        color: color,
        fontWeight: peso,
      );

  static ThemeData construir() {
    const base = ColorScheme.light(
      primary: accion,
      onPrimary: Colors.white,
      secondary: logro,
      surface: tarjeta,
      onSurface: tinta,
      error: fallo,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: fondo,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: fondo,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: tinta,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: tinta),
      ),
      textTheme: const TextTheme(
        // El texto que el niño lee mientras la voz habla.
        displayMedium: TextStyle(
          fontSize: 34,
          height: 1.25,
          fontWeight: FontWeight.w600,
          color: tinta,
        ),
        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: tinta,
        ),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: tinta),
        titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: tinta),
        bodyLarge: TextStyle(fontSize: 17, height: 1.45, color: tinta),
        bodyMedium: TextStyle(fontSize: 15, height: 1.45, color: tintaSuave),
        labelLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      dividerTheme: const DividerThemeData(color: borde, thickness: 1, space: 1),
    );
  }

  static Color colorDe(String asignatura) => switch (asignatura) {
        'dictado' => dictado,
        'ingles' => ingles,
        _ => matematicas,
      };

  static BoxDecoration get cajaTarjeta => BoxDecoration(
        color: tarjeta,
        borderRadius: BorderRadius.circular(radio),
        border: Border.all(color: borde),
      );
}
