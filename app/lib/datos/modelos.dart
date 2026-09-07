import '../dominio/asignaturas.dart';
import '../dominio/coleccion.dart';

class Nino {
  const Nino({
    required this.id,
    required this.nombre,
    required this.curso,
    required this.minutosDiarios,
    required this.modoPistas,
    required this.niveles,
    this.anoNacimiento,
  });

  final int id;
  final String nombre;
  final int curso;
  final int? anoNacimiento;
  final int minutosDiarios;

  /// true: la app da pistas antes de la solución. false: va directa al resultado.
  final bool modoPistas;

  /// Nivel independiente por asignatura. Es la razón de ser de este modelo:
  /// edad y curso no son dificultad.
  final Map<Asignatura, int> niveles;

  int nivelDe(Asignatura a) => niveles[a] ?? 3;
}

enum EstadoActividad { pendiente, enCurso, corregida, saltada }

class ActividadGuardada {
  const ActividadGuardada({
    required this.id,
    required this.ninoId,
    required this.asignatura,
    required this.nivel,
    required this.orden,
    required this.contenido,
    required this.estado,
    this.aciertos,
    this.total,
  });

  final int id;
  final int ninoId;
  final Asignatura asignatura;
  final int nivel;
  final int orden;
  final Map<String, dynamic> contenido;
  final EstadoActividad estado;
  final int? aciertos;
  final int? total;

  bool get corregida => estado == EstadoActividad.corregida;
}

class SesionDelDia {
  const SesionDelDia({
    required this.id,
    required this.minutos,
    required this.actividades,
  });

  final int id;
  final int minutos;
  final List<ActividadGuardada> actividades;

  bool get completa => actividades.every((a) => a.corregida);
  int get hechas => actividades.where((a) => a.corregida).length;
}

class CambioDeNivel {
  const CambioDeNivel({
    required this.asignatura,
    required this.antes,
    required this.despues,
    required this.motivo,
  });

  final Asignatura asignatura;
  final int antes;
  final int despues;
  final String motivo;

  bool get sube => despues > antes;
}

/// Un fallo tal y como se guarda: sirve para las estadísticas del padre y para
/// que el planificador insista en lo que se le atraganta.
/// Una falta tal y como se guarda: la destreza a la que se imputa y qué era lo
/// correcto. Ya no se guarda qué escribió el niño porque ya no se sabe: la
/// corrección la hace él mirando la solución, no una cámara leyendo su hoja.
class FaltaGuardable {
  const FaltaGuardable({
    required this.destrezaId,
    required this.tipo,
    required this.esperado,
  });

  final String destrezaId;
  final String tipo;
  final String esperado;
}

class ResumenAsignatura {
  const ResumenAsignatura({
    required this.asignatura,
    required this.nivel,
    required this.bloqueado,
    required this.actividades,
    this.porcentajeAcierto,
  });

  final Asignatura asignatura;
  final int nivel;
  final bool bloqueado;
  final int actividades;
  final int? porcentajeAcierto;
}

class ErrorFrecuente {
  const ErrorFrecuente(this.destrezaId, this.nombre, this.fallos);
  final String destrezaId;
  final String nombre;
  final int fallos;
}

class DiaDeEstudio {
  const DiaDeEstudio(this.dia, this.minutos, this.actividades);
  final DateTime dia;
  final int minutos;
  final int actividades;
}

class Estadisticas {
  const Estadisticas({
    required this.racha,
    required this.porAsignatura,
    required this.erroresFrecuentes,
    required this.ultimosDias,
  });

  final int racha;
  final List<ResumenAsignatura> porAsignatura;
  final List<ErrorFrecuente> erroresFrecuentes;
  final List<DiaDeEstudio> ultimosDias;
}

/// Un Noun de la colección de un niño, tal y como se guarda.
///
/// El dibujo no está aquí: está en `codigo`, que son los cinco rasgos que lo
/// componen. La rareza sí se guarda, aunque se pueda recalcular, para que la
/// rejilla de la colección pueda pintar cien fichas sin reconstruir cien
/// dibujos.
class NounGuardado {
  const NounGuardado({
    required this.id,
    required this.codigo,
    required this.rareza,
    required this.dia,
  });

  final int id;
  final String codigo;
  final Rareza rareza;
  final DateTime dia;
}
