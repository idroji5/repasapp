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
  static const Color fallo = Color(0xFFB91C1C);
  static const Color falloSuave = Color(0xFFFDECEC);

  static const Color dictado = Color(0xFF4F46E5);
  static const Color matematicas = Color(0xFF0F766E);

  static const double radio = 20;

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

  static Color colorDe(String asignatura) =>
      asignatura == 'dictado' ? dictado : matematicas;

  static BoxDecoration get cajaTarjeta => BoxDecoration(
        color: tarjeta,
        borderRadius: BorderRadius.circular(radio),
        border: Border.all(color: borde),
      );
}
