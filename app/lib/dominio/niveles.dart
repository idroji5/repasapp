import 'asignaturas.dart';

/// Resultado de una actividad ya corregida.
class ResultadoReciente {
  const ResultadoReciente(this.aciertos, this.total, this.corregidaEn);
  final int aciertos;
  final int total;
  final DateTime corregidaEn;

  double get porcentaje => total == 0 ? 0 : aciertos / total;
}

class EstadoNivel {
  const EstadoNivel({
    required this.nivel,
    required this.bloqueado,
    this.cambiadoEn,
  });

  final int nivel;
  final bool bloqueado;
  final DateTime? cambiadoEn;
}

class Ajuste {
  const Ajuste(this.nivelNuevo, this.cambia, this.motivo);
  final int nivelNuevo;
  final bool cambia;
  final String motivo;
}

/// Sube tras 3 actividades seguidas con al menos este acierto.
const double _umbralSubida = 0.85;
const int _actividadesParaSubir = 3;

/// Baja tras 2 actividades seguidas por debajo de este acierto.
const double _umbralBajada = 0.5;
const int _actividadesParaBajar = 2;

/// Nunca más de un cambio de nivel por semana: los saltos bruscos desorientan.
const int _diasEntreCambios = 7;

/// Decide si el nivel de una asignatura debe cambiar.
///
/// Función pura: no toca la base de datos. `recientes` viene ordenado de más
/// reciente a más antigua e incluye solo actividades ya corregidas de esa
/// asignatura.
Ajuste ajustarNivel(
  EstadoNivel estado,
  List<ResultadoReciente> recientes, {
  DateTime? ahora,
}) {
  final momento = ahora ?? DateTime.now();
  Ajuste sinCambio(String motivo) => Ajuste(estado.nivel, false, motivo);

  if (estado.bloqueado) return sinCambio('nivel fijado por el padre');

  final cambiadoEn = estado.cambiadoEn;
  if (cambiadoEn != null &&
      momento.difference(cambiadoEn).inDays < _diasEntreCambios) {
    return sinCambio('cambió hace menos de una semana');
  }

  // Solo se cuentan actividades con ejercicios; una tanda vacía no dice nada.
  final validas = recientes.where((r) => r.total > 0).toList();

  final paraSubir = validas.take(_actividadesParaSubir).toList();
  if (paraSubir.length == _actividadesParaSubir &&
      estado.nivel < nivelMaximo &&
      paraSubir.every((r) => r.porcentaje >= _umbralSubida)) {
    return Ajuste(
      estado.nivel + 1,
      true,
      '$_actividadesParaSubir actividades seguidas por encima del '
      '${(_umbralSubida * 100).round()}%',
    );
  }

  final paraBajar = validas.take(_actividadesParaBajar).toList();
  if (paraBajar.length == _actividadesParaBajar &&
      estado.nivel > nivelMinimo &&
      paraBajar.every((r) => r.porcentaje < _umbralBajada)) {
    return Ajuste(
      estado.nivel - 1,
      true,
      '$_actividadesParaBajar actividades seguidas por debajo del '
      '${(_umbralBajada * 100).round()}%',
    );
  }

  return sinCambio('sin datos suficientes para cambiar');
}
