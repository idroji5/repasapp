import '../voz/locutora.dart';
import 'asignaturas.dart';

/// El guion es lo que la app reproduce: una lista de pasos con lo que hay que
/// decir, cuánto callar y qué esperar del niño.
///
/// Aunque todo corra en local, la pedagogía sigue viviendo aquí y no en la
/// pantalla: las pantallas solo saben reproducir pasos. Cambiar cómo enseña la
/// app es cambiar quien construye el guion, sin tocar la interfaz.
enum Comando {
  listo('Estoy listo'),
  repite('Repite'),
  masDespacio('Más despacio'),
  masRapido('Más rápido'),
  continua('Siguiente'),
  corregir('Corregir'),
  loTengo('Ya lo veo'),
  otraPista('Otra pista');

  const Comando(this.etiqueta);

  /// Cómo aparece en el botón.
  ///
  /// Todo comando es un botón y nada más. Se probó a escucharlos por el
  /// micrófono y no salía a cuenta: el reconocimiento de voz infantil falla
  /// mucho, y sobre todo el reconocedor de Android pita cada vez que se pone a
  /// escuchar. En medio de un dictado ese pitido tapa la palabra siguiente y
  /// hace justo lo contrario de lo que la app pretende.
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
    this.veces = 1,
    this.escrito,
    this.palabraAPalabra = true,
  });

  final int indice;
  final String texto;

  /// Cómo se escribe esto en el cuaderno, si no se escribe como se dice.
  ///
  /// Una cuenta se dicta "setecientos cuarenta y dos entre siete" y se escribe
  /// "742 : 7"; un problema se lee entero y se escribe con sus cifras. Es lo
  /// que se enseña cuando el niño pide verlo.
  final String? escrito;

  /// Si hay que decirlo palabra por palabra, con silencio entre cada una.
  ///
  /// Un dictado sí: se copia tal cual, y lo que hace falta es tiempo entre
  /// palabra y palabra. Un enunciado de matemáticas no: se entiende de
  /// corrido, y trocearlo igual solo consigue que no se entienda.
  final bool palabraAPalabra;

  /// Cuántas veces seguidas se dice antes de callar.
  ///
  /// Un maestro que dicta no lee la frase una sola vez: la dice, deja un
  /// respiro, y la repite algo más despacio para quien se ha quedado atrás. Con
  /// una sola lectura el niño escribe a la carrera y pide "repite" cada frase,
  /// que es la manera lenta de hacer lo mismo.
  final int veces;
}

/// Se para hasta que el niño pulse uno de los botones.
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

/// Termina el guion y pasa a corregir con el niño delante de la pantalla.
class Revisar extends Paso {
  const Revisar(this.texto);
  final String texto;
}

class Guion {
  const Guion({
    required this.asignatura,
    required this.titulo,
    required this.pasos,
    this.comandosGlobales = const [],
    this.velocidadInicial,
  });

  final Asignatura asignatura;
  final String titulo;
  final List<Paso> pasos;

  /// Comandos que el niño tiene a mano en cualquier momento del guion.
  final List<Comando> comandosGlobales;

  /// A qué ritmo empieza a dictarse esto, si el guion tiene una opinión.
  ///
  /// La tiene el dictado: a un niño de segundo no se le dicta al mismo ritmo
  /// que a uno de quinto, y esperar a que sea él quien pida "más despacio"
  /// es esperar a que ya haya perdido media frase. El niño puede cambiarlo
  /// igualmente durante la actividad.
  final Velocidad? velocidadInicial;
}
