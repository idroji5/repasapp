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

/// Un problema con enunciado se dicta entero, palabra a palabra y dos veces, y
/// encima hay que pensarlo antes de escribir nada. La tanda mixta se estima
/// larga a propósito: quedarse corto aquí es meter detrás otra actividad que
/// no cabe en los minutos del día.
const int _segundosPorOperacion = 85;

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

/// A qué familia de cuentas pertenece una destreza. Sirve para que una tanda no
/// se convierta en cinco divisiones seguidas.
String familiaDe(String destrezaId) {
  if (destrezaId.startsWith('problema_')) return 'problema';
  if (destrezaId.startsWith('suma')) return 'suma';
  if (destrezaId.startsWith('resta')) return 'resta';
  if (destrezaId.startsWith('mult') || destrezaId.startsWith('tablas')) {
    return 'multiplicacion';
  }
  if (destrezaId.startsWith('div')) return 'division';
  return destrezaId;
}

/// Cuántas destrezas flojas caben en una tanda.
///
/// Dos. Repasar lo que falla es el objetivo, pero una tanda entera de lo que
/// peor se te da no es repasar: es castigar.
const int _maxFlojas = 2;

/// Elige las destrezas de una tanda de matemáticas.
///
/// Antes se cogían "las dos últimas del curso", que son las dos más avanzadas
/// del catálogo, y por eso a un niño de 5.º le salían cinco divisiones un día
/// detrás de otro. Ahora se coge una destreza por familia —sumar, restar,
/// multiplicar, dividir, decimales— y siempre entra un problema con enunciado,
/// que es lo que de verdad cuesta y lo que nunca tocaba.
///
/// Función pura y sembrada: con el mismo azar sale la misma selección, así que
/// se puede probar.
List<String> elegirDestrezasDeMates(
  List<String> delCurso,
  List<String> flojas,
  int cuantas,
  Random azar,
) {
  final elegidas = <String>[];

  void anadir(Iterable<String> candidatas) {
    for (final id in candidatas) {
      if (elegidas.length >= cuantas) return;
      if (!elegidas.contains(id)) elegidas.add(id);
    }
  }

  // 1. Lo que falla, primero, pero sin llenar la tanda.
  anadir((delCurso.where(flojas.contains).toList()..shuffle(azar)).take(_maxFlojas));

  // 2. Un problema con enunciado. Si el curso tiene varios, el más avanzado de
  //    los que el niño ya puede hacer.
  final problemas = delCurso.where((id) => familiaDe(id) == 'problema').toList();
  if (problemas.isNotEmpty && !elegidas.any((id) => familiaDe(id) == 'problema')) {
    anadir([problemas.last]);
  }

  // 3. Una de cada familia, la más avanzada del curso, en orden aleatorio: las
  //    familias van sin repetir hasta que se agotan.
  final porFamilia = <String, String>{};
  for (final id in delCurso.where((id) => familiaDe(id) != 'problema')) {
    porFamilia[familiaDe(id)] = id; // delCurso viene de menos a más avanzado
  }
  anadir(porFamilia.values.toList()..shuffle(azar));

  // 4. Si aún falta, cualquier otra del curso antes que repetir destreza.
  anadir(delCurso.reversed);

  return elegidas;
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

  final cuantas = min(operacionesPorTanda, segundosDisponibles ~/ _segundosPorOperacion);
  if (cuantas < 2) return null;

  final elegidas =
      elegirDestrezasDeMates(delCurso, ctx.destrezasFlojas, cuantas, azar);

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
      final tanda = generarTanda(
        (contenido['destrezas'] as List).cast<String>(),
        nivel,
        contenido['cuantas'] as int,
        contenido['semilla'] as int,
      );
      // "solo" son los que se van a repetir porque salieron mal. Se generan
      // los cinco igual —la semilla manda— y se queda con esos, renumerados,
      // para que la voz diga "la primera" y sea la primera de verdad.
      final solo = (contenido['solo'] as List?)?.cast<int>();
      if (solo == null) return ContenidoOperaciones(tanda);

      return ContenidoOperaciones([
        for (final (i, op) in tanda.where((o) => solo.contains(o.numero)).indexed)
          op.conNumero(i + 1),
      ]);

    default:
      throw StateError('Tipo de actividad desconocido: ${contenido['tipo']}');
  }
}

/// El contenido de una actividad que se va a repetir.
///
/// Queda marcado como repetición, y eso importa más allá del título: una
/// repetición no cuenta para subir o bajar de nivel. Acaba de ver las
/// soluciones, así que bordarla no demuestra nada.
///
/// [soloEstos] son los ejercicios que se quieren repetir, numerados como
/// estaban en la actividad que se repite. Si esa ya era una repetición, se
/// traducen a los números de la tanda original: la semilla genera siempre la
/// tanda entera y "solo" recorta sobre ella, así que un recorte de un recorte
/// habría cogido los ejercicios equivocados.
Map<String, dynamic> contenidoRepetido(
  Map<String, dynamic> original, {
  List<int>? soloEstos,
}) {
  final copia = Map<String, dynamic>.from(original)..['repetido'] = true;

  if (copia['tipo'] == 'dictado' || soloEstos == null) return copia;

  final recorteAnterior = (original['solo'] as List?)?.cast<int>();
  copia['solo'] = recorteAnterior == null
      ? soloEstos
      : [for (final n in soloEstos) recorteAnterior[n - 1]];
  return copia;
}

String tituloDe(Map<String, dynamic> contenido) {
  if (contenido['tipo'] == 'dictado') {
    final titulo = dictadoPorId(contenido['dictadoId'] as String)?.titulo ?? 'Dictado';
    return contenido['repetido'] == true ? '$titulo (otra vez)' : titulo;
  }

  final solo = (contenido['solo'] as List?)?.cast<int>();
  if (solo != null) {
    return solo.length == 1
        ? 'La que falló, otra vez'
        : 'Las ${solo.length} que fallaron';
  }

  final destrezas = (contenido['destrezas'] as List?)?.cast<String>() ?? const [];
  final conProblemas = destrezas.any((id) => familiaDe(id) == 'problema');
  return '${contenido['cuantas']} ${conProblemas ? "ejercicios" : "operaciones"}';
}
