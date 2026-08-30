import 'dart:math';

import '../contenido/dictados.dart';
import '../contenido/matematicas.dart';
import 'asignaturas.dart';
import 'curriculo.dart';

/// "Quince minutos al día" → una sesión concreta.
///
/// Este es el corazón del producto: la retención de una app infantil de estudio
/// se juega en que el niño abra la app y ya tenga el plan hecho, no en el tamaño
/// del catálogo de ejercicios.
class ContextoPlan {
  const ContextoPlan({
    required this.curso,
    required this.minutosDiarios,
    required this.niveles,
    this.dictadosHechos = const [],
    this.destrezasFlojas = const [],
    this.ultimaAsignatura,
  });

  final int curso;
  final int minutosDiarios;
  final Map<Asignatura, int> niveles;

  /// Dictados ya hechos, para no repetirlos.
  final List<String> dictadosHechos;

  /// Destrezas con más fallos recientes: son las que hay que trabajar.
  final List<String> destrezasFlojas;

  /// Asignatura de la última sesión, para no empezar siempre por la misma.
  final Asignatura? ultimaAsignatura;

  int nivelDe(Asignatura a) => niveles[a] ?? 3;
}

class ActividadPlanificada {
  const ActividadPlanificada({
    required this.asignatura,
    required this.nivel,
    required this.contenido,
    required this.duracionEstimadaSegundos,
  });

  final Asignatura asignatura;
  final int nivel;

  /// Se guarda tal cual en la base de datos, en JSON.
  final Map<String, dynamic> contenido;
  final int duracionEstimadaSegundos;
}

/// Operaciones por tanda. Cinco es lo que cabe en una hoja y en la cabeza.
const int operacionesPorTanda = 5;
const int _segundosPorOperacion = 55;

/// Por debajo de esto no cabe ninguna actividad que valga la pena.
const int _minimoUtilSegundos = 100;
const int _maxActividades = 3;

List<Asignatura> _rotacion(Asignatura? ultima) {
  if (ultima == null) return Asignatura.values.toList();
  // Se empieza por la que NO tocó ayer.
  return [
    ...Asignatura.values.where((a) => a != ultima),
    ...Asignatura.values.where((a) => a == ultima),
  ];
}

ActividadPlanificada? _planificarMatematicas(
  ContextoPlan ctx,
  int segundosDisponibles,
  Random azar,
) {
  final delCurso = destrezasHasta(ctx.curso, Asignatura.matematicas)
      .map((d) => d.id)
      .where(tienePlantilla)
      .toList();
  if (delCurso.isEmpty) return null;

  // Las destrezas flojas van primero; el resto rellena.
  final flojas = delCurso.where(ctx.destrezasFlojas.contains).toList();
  final resto = delCurso.where((id) => !ctx.destrezasFlojas.contains(id)).toList();
  // Las dos últimas del curso son las más avanzadas: son las que toca practicar.
  final elegidas = [
    ...flojas,
    ...resto.skip(resto.length > 2 ? resto.length - 2 : 0),
  ].take(2).toList();

  final cuantas = min(operacionesPorTanda, segundosDisponibles ~/ _segundosPorOperacion);
  if (cuantas < 2) return null;

  return ActividadPlanificada(
    asignatura: Asignatura.matematicas,
    nivel: ctx.nivelDe(Asignatura.matematicas),
    contenido: {
      'tipo': 'tanda_operaciones',
      'destrezas': elegidas,
      'cuantas': cuantas,
      // La semilla se guarda para reconstruir exactamente la misma tanda al corregir.
      'semilla': azar.nextInt(1 << 31),
    },
    duracionEstimadaSegundos: cuantas * _segundosPorOperacion,
  );
}

ActividadPlanificada? _planificarDictado(
  ContextoPlan ctx,
  int segundosDisponibles,
  Random azar,
) {
  final dictado = elegirDictado(
    ctx.nivelDe(Asignatura.dictado),
    ctx.curso,
    ctx.dictadosHechos,
    azar: azar,
  );
  if (dictado == null) return null;

  final duracion = duracionEstimadaSegundos(dictado);
  // Un dictado no se puede partir por la mitad, así que se admite algo de margen.
  if (duracion > segundosDisponibles * 1.3) return null;

  return ActividadPlanificada(
    asignatura: Asignatura.dictado,
    nivel: ctx.nivelDe(Asignatura.dictado),
    contenido: {'tipo': 'dictado', 'dictadoId': dictado.id},
    duracionEstimadaSegundos: duracion,
  );
}

List<ActividadPlanificada> planificarSesion(ContextoPlan ctx, {Random? azar}) {
  final generador = azar ?? Random();
  var restante = ctx.minutosDiarios * 60;
  final plan = <ActividadPlanificada>[];
  final orden = _rotacion(ctx.ultimaAsignatura);

  for (var vuelta = 0; vuelta < 2 && plan.length < _maxActividades; vuelta++) {
    for (final asignatura in orden) {
      if (restante < _minimoUtilSegundos || plan.length >= _maxActividades) break;

      final ya = plan.where((p) => p.asignatura == asignatura).map((p) {
        return p.contenido['dictadoId'] as String?;
      }).whereType<String>();

      final contexto = asignatura == Asignatura.dictado
          ? ContextoPlan(
              curso: ctx.curso,
              minutosDiarios: ctx.minutosDiarios,
              niveles: ctx.niveles,
              // Dentro de la misma sesión tampoco se repite dictado.
              dictadosHechos: [...ctx.dictadosHechos, ...ya],
              destrezasFlojas: ctx.destrezasFlojas,
              ultimaAsignatura: ctx.ultimaAsignatura,
            )
          : ctx;

      final actividad = asignatura == Asignatura.dictado
          ? _planificarDictado(contexto, restante, generador)
          : _planificarMatematicas(contexto, restante, generador);

      if (actividad != null) {
        plan.add(actividad);
        restante -= actividad.duracionEstimadaSegundos;
      }
    }
  }
  return plan;
}

/// Reconstruye lo que se le planteó al niño a partir de lo guardado.
///
/// Para las operaciones no se guarda la lista, se guarda la semilla: el
/// generador es determinista, así que la misma semilla devuelve exactamente la
/// misma tanda al corregir que la que se dictó.
sealed class ContenidoActividad {
  const ContenidoActividad();
}

class ContenidoDictado extends ContenidoActividad {
  const ContenidoDictado(this.dictado);
  final Dictado dictado;
}

class ContenidoOperaciones extends ContenidoActividad {
  const ContenidoOperaciones(this.operaciones);
  final List<Operacion> operaciones;
}

ContenidoActividad reconstruir(Map<String, dynamic> contenido, int nivel) {
  switch (contenido['tipo'] as String?) {
    case 'dictado':
      final dictado = dictadoPorId(contenido['dictadoId'] as String);
      if (dictado == null) {
        throw StateError('Dictado desconocido: ${contenido['dictadoId']}');
      }
      return ContenidoDictado(dictado);

    case 'tanda_operaciones':
      return ContenidoOperaciones(generarTanda(
        (contenido['destrezas'] as List).cast<String>(),
        nivel,
        contenido['cuantas'] as int,
        contenido['semilla'] as int,
      ));

    default:
      throw StateError('Tipo de actividad desconocido: ${contenido['tipo']}');
  }
}

String tituloDe(Map<String, dynamic> contenido) =>
    contenido['tipo'] == 'dictado'
        ? dictadoPorId(contenido['dictadoId'] as String)?.titulo ?? 'Dictado'
        : '${contenido['cuantas']} operaciones';
