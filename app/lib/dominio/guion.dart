import 'asignaturas.dart';

/// El guion es lo que la app reproduce: una lista de pasos con lo que hay que
/// decir, cuánto callar y qué esperar del niño.
///
/// Aunque todo corra en local, la pedagogía sigue viviendo aquí y no en la
/// pantalla: las pantallas solo saben reproducir pasos. Cambiar cómo enseña la
/// app es cambiar quien construye el guion, sin tocar la interfaz.
enum Comando {
  listo('listo', 'Estoy listo'),
  repite('repite', 'Repite'),
  masDespacio('más despacio', 'Más despacio'),
  masRapido('más rápido', 'Más rápido'),
  continua('continúa', 'Continúa'),
  loTengo('ya lo veo', 'Ya lo veo'),
  otraPista('otra pista', 'Otra pista');

  const Comando(this.dicho, this.etiqueta);

  /// Cómo lo diría el niño en voz alta.
  final String dicho;

  /// Cómo aparece en el botón, para quien prefiera tocar la pantalla.
  final String etiqueta;
}

sealed class Paso {
  const Paso();
}

/// La voz dice algo y sigue.
class Habla extends Paso {
  const Habla(this.texto);
  final String texto;
}

/// Un trozo de dictado o una operación: se dice y se calla para que escriba.
class Fragmento extends Paso {
  const Fragmento({
    required this.indice,
    required this.texto,
    required this.pausaSegundos,
    this.avanzaSolo = true,
  });

  final int indice;
  final String texto;

  /// Cuánto se calla antes de seguir. Solo cuenta si [avanzaSolo].
  final int pausaSegundos;

  /// Si la app pasa sola al siguiente fragmento cuando se agota la pausa.
  ///
  /// En un dictado sí: un dictado tiene ritmo, y quien dicta no espera
  /// indefinidamente. En una operación no: copiar "ciento sesenta y siete por
  /// cuarenta y cuatro" de oído es un tiro único, y si la app sigue adelante
  /// mientras el niño aún está escribiendo, la cuenta se pierde para siempre.
  final bool avanzaSolo;
}

/// Se para hasta que el niño diga uno de los comandos (o pulse el botón).
class Espera extends Paso {
  const Espera(this.texto, this.comandos);
  final String texto;
  final List<Comando> comandos;
}

/// Bifurcación sencilla: según lo que conteste, se reproduce una rama u otra.
class Pregunta extends Paso {
  const Pregunta(this.texto, this.opciones);
  final String texto;
  final List<RamaPregunta> opciones;
}

class RamaPregunta {
  const RamaPregunta(this.comando, this.pasos);
  final Comando comando;
  final List<Paso> pasos;
}

/// Pide la foto del cuaderno y termina el guion.
class PedirFoto extends Paso {
  const PedirFoto(this.texto);
  final String texto;
}

class Guion {
  const Guion({
    required this.asignatura,
    required this.titulo,
    required this.pasos,
    this.comandosGlobales = const [],
  });

  final Asignatura asignatura;
  final String titulo;
  final List<Paso> pasos;

  /// Comandos que el niño puede decir en cualquier momento del guion.
  final List<Comando> comandosGlobales;
}
