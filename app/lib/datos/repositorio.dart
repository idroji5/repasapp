import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../dominio/asignaturas.dart';
import '../dominio/curriculo.dart';
import '../dominio/niveles.dart';
import '../dominio/planificador.dart';
import 'modelos.dart';

/// Acceso a los datos y a las decisiones que dependen del historial.
///
/// Aquí vive lo que necesita saber lo que pasó antes: qué sesión toca hoy, si
/// hay que subir o bajar de nivel, en qué falla más el niño. Las reglas puras
/// (planificar, ajustar nivel) están en `dominio/`; esto solo las alimenta.
class Repositorio {
  Repositorio(this._db, {Random? azar, DateTime Function()? reloj})
      : _azar = azar ?? Random(),
        _reloj = reloj ?? DateTime.now;

  final Database _db;
  final Random _azar;

  /// De dónde sale "ahora". Es inyectable porque media aplicación depende del
  /// día: la sesión diaria, la racha, y la regla de no cambiar de nivel más de
  /// una vez por semana. Sin poder mover el reloj, eso no se puede probar.
  final DateTime Function() _reloj;

  String _hoy() => _fecha(_reloj());
  static String _fecha(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
  String _ahora() => _reloj().toIso8601String();

  // ------------------------------------------------------------- niños ---

  Future<List<Nino>> ninos() async {
    final filas = await _db.query('ninos', orderBy: 'creado_en');
    return Future.wait(filas.map(_aNino));
  }

  Future<Nino?> nino(int id) async {
    final filas = await _db.query('ninos', where: 'id = ?', whereArgs: [id], limit: 1);
    return filas.isEmpty ? null : _aNino(filas.first);
  }

  Future<Nino> _aNino(Map<String, Object?> fila) async {
    final id = fila['id']! as int;
    final niveles = await _db.query('niveles', where: 'nino_id = ?', whereArgs: [id]);

    return Nino(
      id: id,
      nombre: fila['nombre']! as String,
      curso: fila['curso']! as int,
      anoNacimiento: fila['ano_nacimiento'] as int?,
      minutosDiarios: fila['minutos_diarios']! as int,
      modoPistas: (fila['modo_pistas']! as int) == 1,
      niveles: {
        for (final n in niveles)
          if (Asignatura.porClave(n['asignatura']! as String) case final a?)
            a: n['nivel']! as int,
      },
    );
  }

  Future<int> crearNino({
    required String nombre,
    required int curso,
    int? anoNacimiento,
    int minutosDiarios = 15,
    Map<Asignatura, int> niveles = const {},
  }) async {
    final id = await _db.insert('ninos', {
      'nombre': nombre,
      'curso': curso,
      'ano_nacimiento': anoNacimiento,
      'minutos_diarios': minutosDiarios,
      'modo_pistas': 1,
      'creado_en': _ahora(),
    });

    // Un nivel por asignatura desde el primer día: es lo que permite que
    // Matemáticas y Dictado vayan por caminos distintos.
    for (final asignatura in Asignatura.values) {
      await _db.insert('niveles', {
        'nino_id': id,
        'asignatura': asignatura.name,
        'nivel': niveles[asignatura] ?? 3,
      });
    }
    return id;
  }

  Future<void> actualizarNino(
    int id, {
    int? minutosDiarios,
    bool? modoPistas,
    int? curso,
  }) async {
    final cambios = <String, Object?>{
      if (minutosDiarios != null) 'minutos_diarios': minutosDiarios,
      if (modoPistas != null) 'modo_pistas': modoPistas ? 1 : 0,
      if (curso != null) 'curso': curso,
    };
    if (cambios.isEmpty) return;
    await _db.update('ninos', cambios, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> borrarNino(int id) async {
    // sqflite no fuerza las claves ajenas por defecto, así que se limpia a mano.
    for (final tabla in ['faltas', 'destrezas_nino', 'cambios_nivel', 'actividades', 'sesiones', 'niveles']) {
      await _db.delete(tabla, where: 'nino_id = ?', whereArgs: [id]);
    }
    await _db.delete('ninos', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> fijarNivel(
    int ninoId,
    Asignatura asignatura,
    int nivel, {
    bool bloqueado = true,
  }) async {
    final actual = await _nivelActual(ninoId, asignatura);

    await _db.insert(
      'niveles',
      {
        'nino_id': ninoId,
        'asignatura': asignatura.name,
        'nivel': nivelValido(nivel),
        'bloqueado': bloqueado ? 1 : 0,
        'cambiado_en': _ahora(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (actual != null && actual.nivel != nivel) {
      await _db.insert('cambios_nivel', {
        'nino_id': ninoId,
        'asignatura': asignatura.name,
        'nivel_antes': actual.nivel,
        'nivel_despues': nivelValido(nivel),
        'motivo': 'cambiado por el padre',
        'creado_en': _ahora(),
      });
    }
  }

  Future<EstadoNivel?> _nivelActual(int ninoId, Asignatura asignatura) async {
    final filas = await _db.query(
      'niveles',
      where: 'nino_id = ? and asignatura = ?',
      whereArgs: [ninoId, asignatura.name],
      limit: 1,
    );
    if (filas.isEmpty) return null;
    final f = filas.first;
    return EstadoNivel(
      nivel: f['nivel']! as int,
      bloqueado: (f['bloqueado']! as int) == 1,
      cambiadoEn: switch (f['cambiado_en'] as String?) {
        final t? => DateTime.tryParse(t),
        null => null,
      },
    );
  }

  // ---------------------------------------------------- sesión del día ---

  /// La sesión de hoy, creándola con el planificador si aún no existía.
  Future<SesionDelDia> sesionDeHoy(int ninoId) async {
    final existentes = await _db.query(
      'sesiones',
      where: 'nino_id = ? and dia = ?',
      whereArgs: [ninoId, _hoy()],
      orderBy: 'id desc',
      limit: 1,
    );

    final sesionId = existentes.isNotEmpty
        ? existentes.first['id']! as int
        : await _crearSesionDeHoy(ninoId);

    final minutos = existentes.isNotEmpty
        ? existentes.first['minutos_previstos']! as int
        : (await nino(ninoId))!.minutosDiarios;

    return SesionDelDia(
      id: sesionId,
      minutos: minutos,
      actividades: await _actividadesDe(sesionId),
    );
  }

  Future<int> _crearSesionDeHoy(int ninoId) async {
    final n = (await nino(ninoId))!;
    final plan = planificarSesion(
      ContextoPlan(
        curso: n.curso,
        minutosDiarios: n.minutosDiarios,
        niveles: n.niveles,
        dictadosHechos: await _dictadosHechos(ninoId),
        destrezasFlojas: await destrezasFlojas(ninoId),
        ultimaAsignatura: await _ultimaAsignatura(ninoId),
      ),
      azar: _azar,
    );

    return _db.transaction((txn) async {
      final sesionId = await txn.insert('sesiones', {
        'nino_id': ninoId,
        'dia': _hoy(),
        'minutos_previstos': n.minutosDiarios,
        'iniciada_en': _ahora(),
      });

      for (var i = 0; i < plan.length; i++) {
        final actividad = plan[i];
        await txn.insert('actividades', {
          'sesion_id': sesionId,
          'nino_id': ninoId,
          'asignatura': actividad.asignatura.name,
          'nivel': actividad.nivel,
          'orden': i,
          'contenido': jsonEncode(actividad.contenido),
          'estado': 'pendiente',
          'creada_en': _ahora(),
        });
      }
      return sesionId;
    });
  }

  Future<List<ActividadGuardada>> _actividadesDe(int sesionId) async {
    final filas = await _db.query(
      'actividades',
      where: 'sesion_id = ?',
      whereArgs: [sesionId],
      orderBy: 'orden',
    );
    return filas.map(_aActividad).toList();
  }

  ActividadGuardada _aActividad(Map<String, Object?> f) => ActividadGuardada(
        id: f['id']! as int,
        ninoId: f['nino_id']! as int,
        asignatura: Asignatura.porClave(f['asignatura']! as String)!,
        nivel: f['nivel']! as int,
        orden: f['orden']! as int,
        contenido: jsonDecode(f['contenido']! as String) as Map<String, dynamic>,
        estado: switch (f['estado']! as String) {
          'en_curso' => EstadoActividad.enCurso,
          'corregida' => EstadoActividad.corregida,
          'saltada' => EstadoActividad.saltada,
          _ => EstadoActividad.pendiente,
        },
        aciertos: f['aciertos'] as int?,
        total: f['total'] as int?,
      );

  Future<ActividadGuardada?> actividad(int id) async {
    final filas = await _db.query('actividades', where: 'id = ?', whereArgs: [id], limit: 1);
    return filas.isEmpty ? null : _aActividad(filas.first);
  }

  Future<void> marcarEnCurso(int actividadId) => _db.update(
        'actividades',
        {'estado': 'en_curso'},
        where: 'id = ? and estado = ?',
        whereArgs: [actividadId, 'pendiente'],
      );

  Future<void> saltarActividad(int actividadId) => _db.update(
        'actividades',
        {'estado': 'saltada'},
        where: 'id = ?',
        whereArgs: [actividadId],
      );

  Future<List<String>> _dictadosHechos(int ninoId) async {
    final filas = await _db.query(
      'actividades',
      columns: ['contenido'],
      where: 'nino_id = ? and asignatura = ?',
      whereArgs: [ninoId, Asignatura.dictado.name],
      orderBy: 'creada_en desc',
      limit: 20,
    );
    return filas
        .map((f) => (jsonDecode(f['contenido']! as String) as Map)['dictadoId'])
        .whereType<String>()
        .toList();
  }

  Future<Asignatura?> _ultimaAsignatura(int ninoId) async {
    final filas = await _db.query(
      'actividades',
      columns: ['asignatura'],
      where: 'nino_id = ?',
      whereArgs: [ninoId],
      orderBy: 'creada_en desc',
      limit: 1,
    );
    return filas.isEmpty ? null : Asignatura.porClave(filas.first['asignatura']! as String);
  }

  /// Destrezas en las que más falla últimamente: el planificador insiste en ellas.
  Future<List<String>> destrezasFlojas(int ninoId, {int cuantas = 5}) async {
    final filas = await _db.rawQuery(
      '''
      select destreza_id from destrezas_nino
       where nino_id = ? and fallos > 0
       order by (cast(fallos as real) / max(intentos, 1)) desc, ultimo_fallo_en desc
       limit ?
      ''',
      [ninoId, cuantas],
    );
    return filas.map((f) => f['destreza_id']! as String).toList();
  }

  // ----------------------------------------------------- guardar y ajustar ---

  /// Guarda el resultado de una actividad corregida y devuelve el cambio de
  /// nivel si esta actividad lo ha provocado.
  Future<CambioDeNivel?> guardarCorreccion({
    required int actividadId,
    required int ninoId,
    required Asignatura asignatura,
    required int aciertos,
    required int total,
    required List<FaltaGuardable> faltas,
    int? duracionSegundos,
  }) async {
    await _db.transaction((txn) async {
      await txn.update(
        'actividades',
        {
          'estado': 'corregida',
          'aciertos': aciertos,
          'total': total,
          'duracion_s': duracionSegundos,
          'corregida_en': _ahora(),
        },
        where: 'id = ?',
        whereArgs: [actividadId],
      );

      // Corregir es idempotente: si el niño arregla lo que el OCR leyó mal y
      // se vuelve a corregir, las faltas de la vez anterior no pueden quedarse
      // contadas dos veces.
      final previas = await txn.query(
        'faltas',
        columns: ['destreza_id'],
        where: 'actividad_id = ?',
        whereArgs: [actividadId],
      );
      for (final previa in previas) {
        await txn.rawUpdate(
          'update destrezas_nino '
          'set intentos = max(intentos - 1, 0), fallos = max(fallos - 1, 0) '
          'where nino_id = ? and destreza_id = ?',
          [ninoId, previa['destreza_id']],
        );
      }
      await txn.delete('faltas', where: 'actividad_id = ?', whereArgs: [actividadId]);
      for (final falta in faltas) {
        await txn.insert('faltas', {
          'nino_id': ninoId,
          'actividad_id': actividadId,
          'destreza_id': falta.destrezaId,
          'tipo': falta.tipo,
          'esperado': falta.esperado,
          'escrito': falta.escrito,
          'creado_en': _ahora(),
        });
        await txn.rawInsert(
          '''
          insert into destrezas_nino (nino_id, destreza_id, intentos, fallos, ultimo_fallo_en)
          values (?, ?, 1, 1, ?)
          on conflict (nino_id, destreza_id) do update set
            intentos = intentos + 1,
            fallos = fallos + 1,
            ultimo_fallo_en = excluded.ultimo_fallo_en
          ''',
          [ninoId, falta.destrezaId, _ahora()],
        );
      }
    });

    return _autoajustarNivel(ninoId, asignatura);
  }

  /// Cuántas actividades recientes mira el autoajuste de nivel.
  static const int _historialParaNivel = 3;

  Future<CambioDeNivel?> _autoajustarNivel(int ninoId, Asignatura asignatura) async {
    final estado = await _nivelActual(ninoId, asignatura);
    if (estado == null) return null;

    final filas = await _db.query(
      'actividades',
      columns: ['aciertos', 'total', 'corregida_en'],
      where: 'nino_id = ? and asignatura = ? and estado = ? and total > 0',
      whereArgs: [ninoId, asignatura.name, 'corregida'],
      orderBy: 'corregida_en desc',
      limit: _historialParaNivel,
    );

    final ajuste = ajustarNivel(
      estado,
      ahora: _reloj(),
      filas
          .map((f) => ResultadoReciente(
                f['aciertos']! as int,
                f['total']! as int,
                DateTime.parse(f['corregida_en']! as String),
              ))
          .toList(),
    );
    if (!ajuste.cambia) return null;

    await _db.update(
      'niveles',
      {'nivel': ajuste.nivelNuevo, 'cambiado_en': _ahora()},
      where: 'nino_id = ? and asignatura = ?',
      whereArgs: [ninoId, asignatura.name],
    );
    await _db.insert('cambios_nivel', {
      'nino_id': ninoId,
      'asignatura': asignatura.name,
      'nivel_antes': estado.nivel,
      'nivel_despues': ajuste.nivelNuevo,
      'motivo': ajuste.motivo,
      'creado_en': _ahora(),
    });

    return CambioDeNivel(
      asignatura: asignatura,
      antes: estado.nivel,
      despues: ajuste.nivelNuevo,
      motivo: ajuste.motivo,
    );
  }

  // ------------------------------------------------------- zona de padres ---

  /// Las estadísticas son deliberadamente pocas. Un padre quiere saber si su
  /// hijo estudia, en qué falla y si progresa; no necesita un cuadro de mando.
  Future<Estadisticas> estadisticas(int ninoId) async {
    final desde = _reloj().subtract(const Duration(days: 30)).toIso8601String();

    final porAsignatura = <ResumenAsignatura>[];
    for (final asignatura in Asignatura.values) {
      final nivel = await _nivelActual(ninoId, asignatura);
      final agregado = (await _db.rawQuery(
        '''
        select count(*) as actividades,
               coalesce(sum(aciertos), 0) as aciertos,
               coalesce(sum(total), 0)    as total
          from actividades
         where nino_id = ? and asignatura = ? and estado = 'corregida'
           and corregida_en > ?
        ''',
        [ninoId, asignatura.name, desde],
      ))
          .first;

      final total = (agregado['total']! as int?) ?? 0;
      porAsignatura.add(ResumenAsignatura(
        asignatura: asignatura,
        nivel: nivel?.nivel ?? 3,
        bloqueado: nivel?.bloqueado ?? false,
        actividades: (agregado['actividades']! as int?) ?? 0,
        porcentajeAcierto: total > 0
            ? (((agregado['aciertos']! as int) / total) * 100).round()
            : null,
      ));
    }

    final errores = await _db.rawQuery(
      '''
      select destreza_id, count(*) as fallos from faltas
       where nino_id = ? and creado_en > ?
       group by destreza_id order by fallos desc limit 5
      ''',
      [ninoId, desde],
    );

    final dias = await _db.rawQuery(
      '''
      select s.dia,
             coalesce(sum(a.duracion_s), 0) as segundos,
             count(a.id) as actividades
        from sesiones s left join actividades a
          on a.sesion_id = s.id and a.estado = 'corregida'
       where s.nino_id = ? and s.dia >= ?
       group by s.dia order by s.dia
      ''',
      [ninoId, _fecha(_reloj().subtract(const Duration(days: 7)))],
    );

    return Estadisticas(
      racha: await _racha(ninoId),
      porAsignatura: porAsignatura,
      erroresFrecuentes: errores
          .map((f) => ErrorFrecuente(
                f['destreza_id']! as String,
                nombreDestreza(f['destreza_id']! as String),
                f['fallos']! as int,
              ))
          .toList(),
      ultimosDias: dias
          .map((f) => DiaDeEstudio(
                DateTime.parse(f['dia']! as String),
                (((f['segundos']! as int?) ?? 0) / 60).round(),
                (f['actividades']! as int?) ?? 0,
              ))
          .toList(),
    );
  }

  /// Días seguidos, hasta hoy, con al menos una actividad corregida.
  Future<int> _racha(int ninoId) async {
    final filas = await _db.rawQuery(
      '''
      select distinct s.dia from sesiones s
        join actividades a on a.sesion_id = s.id and a.estado = 'corregida'
       where s.nino_id = ?
       order by s.dia desc limit 90
      ''',
      [ninoId],
    );
    if (filas.isEmpty) return 0;

    final hoy = _reloj();
    var racha = 0;

    for (var i = 0; i < filas.length; i++) {
      final esperado = _fecha(hoy.subtract(Duration(days: i)));
      final dia = filas[i]['dia']! as String;

      // Se admite que la racha empiece ayer: aún no ha estudiado hoy y no se le
      // castiga por ello a media tarde.
      if (i == 0 && dia != esperado) {
        if (dia != _fecha(hoy.subtract(const Duration(days: 1)))) return 0;
        racha++;
        continue;
      }
      if (i > 0 && dia != esperado) break;
      racha++;
    }
    return racha;
  }

  Future<List<CambioDeNivel>> historialDeNiveles(int ninoId) async {
    final filas = await _db.query(
      'cambios_nivel',
      where: 'nino_id = ?',
      whereArgs: [ninoId],
      orderBy: 'creado_en desc',
      limit: 10,
    );
    return filas
        .map((f) => CambioDeNivel(
              asignatura: Asignatura.porClave(f['asignatura']! as String)!,
              antes: f['nivel_antes']! as int,
              despues: f['nivel_despues']! as int,
              motivo: f['motivo']! as String,
            ))
        .toList();
  }

  // -------------------------------------------------------------- ajustes ---

  Future<String?> ajuste(String clave) async {
    final filas = await _db.query('ajustes',
        where: 'clave = ?', whereArgs: [clave], limit: 1);
    return filas.isEmpty ? null : filas.first['valor'] as String;
  }

  Future<void> fijarAjuste(String clave, String valor) => _db.insert(
        'ajustes',
        {'clave': clave, 'valor': valor},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  // ------------------------------------------------------------------ PIN ---

  /// El PIN protege la zona de padres. No es una medida contra un atacante: es
  /// una puerta para que el niño, que tiene el móvil en la mano, no entre a
  /// cambiarse el nivel él solo.
  Future<bool> hayPin() async =>
      (await _db.query('ajustes', where: 'clave = ?', whereArgs: ['pin'])).isNotEmpty;

  Future<void> fijarPin(String pin) async {
    final sal = List.generate(16, (_) => _azar.nextInt(256));
    final hash = sha256.convert([...sal, ...utf8.encode(pin)]).toString();
    await _db.insert(
      'ajustes',
      {'clave': 'pin', 'valor': '${base64Encode(sal)}:$hash'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> comprobarPin(String pin) async {
    final filas = await _db.query('ajustes', where: 'clave = ?', whereArgs: ['pin'], limit: 1);
    if (filas.isEmpty) return false;

    final partes = (filas.first['valor']! as String).split(':');
    if (partes.length != 2) return false;

    final sal = base64Decode(partes[0]);
    return sha256.convert([...sal, ...utf8.encode(pin)]).toString() == partes[1];
  }
}
