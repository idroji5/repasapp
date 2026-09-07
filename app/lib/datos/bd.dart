import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Base de datos local. Todo se queda en el dispositivo: no hay servidor, no
/// hay cuenta, y los datos del niño no salen del teléfono de la familia.
///
/// NOTA DE PRIVACIDAD: la app no hace fotos ni pide cámara. El cuaderno se
/// corrige mirando la solución en pantalla, así que lo único que se guarda es
/// el resultado: qué destreza se falló y cuál era la palabra correcta.
class BaseDatos {
  static const String _nombreFichero = 'repasapp.db';
  static const int _version = 2;

  static Future<Database> abrir({String? rutaCompleta}) async {
    final ruta =
        rutaCompleta ?? p.join(await getDatabasesPath(), _nombreFichero);
    return openDatabase(
      ruta,
      version: _version,
      onCreate: _crear,
      onUpgrade: _migrar,
    );
  }

  static Future<void> _crear(Database db, int version) async {
    await db.execute('''
      create table ninos (
        id              integer primary key autoincrement,
        nombre          text    not null,
        curso           integer not null,
        ano_nacimiento  integer,
        minutos_diarios integer not null default 15,
        modo_pistas     integer not null default 1,
        creado_en       text    not null
      )
    ''');

    // El nivel es por asignatura: un niño puede ir en Matemáticas 4/5 y en
    // Dictado 2/5. `bloqueado` lo pone el padre para congelar el autoajuste.
    await db.execute('''
      create table niveles (
        nino_id     integer not null references ninos(id) on delete cascade,
        asignatura  text    not null,
        nivel       integer not null default 3,
        bloqueado   integer not null default 0,
        cambiado_en text,
        primary key (nino_id, asignatura)
      )
    ''');

    await db.execute('''
      create table sesiones (
        id                integer primary key autoincrement,
        nino_id           integer not null references ninos(id) on delete cascade,
        dia               text    not null,
        minutos_previstos integer not null,
        iniciada_en       text    not null,
        terminada_en      text
      )
    ''');
    await db.execute(
      'create index sesiones_nino on sesiones (nino_id, dia desc)',
    );

    await db.execute('''
      create table actividades (
        id           integer primary key autoincrement,
        sesion_id    integer not null references sesiones(id) on delete cascade,
        nino_id      integer not null references ninos(id) on delete cascade,
        asignatura   text    not null,
        nivel        integer not null,
        orden        integer not null,
        contenido    text    not null,
        estado       text    not null default 'pendiente',
        aciertos     integer,
        total        integer,
        duracion_s   integer,
        creada_en    text    not null,
        corregida_en text
      )
    ''');
    await db.execute(
      'create index actividades_sesion on actividades (sesion_id, orden)',
    );
    await db.execute(
      'create index actividades_nino on actividades (nino_id, creada_en desc)',
    );

    await db.execute('''
      create table faltas (
        id           integer primary key autoincrement,
        nino_id      integer not null references ninos(id) on delete cascade,
        actividad_id integer not null references actividades(id) on delete cascade,
        destreza_id  text    not null,
        tipo         text    not null,
        esperado     text    not null,
        -- Herencia de la versión que leía la hoja con la cámara: hoy siempre
        -- va vacía. Se mantiene para no migrar las bases de datos existentes.
        escrito      text    not null,
        creado_en    text    not null
      )
    ''');
    await db.execute(
      'create index faltas_nino on faltas (nino_id, creado_en desc)',
    );

    // Acumulado por destreza: evita recorrer todas las faltas cada vez que se
    // planifica una sesión.
    await db.execute('''
      create table destrezas_nino (
        nino_id         integer not null references ninos(id) on delete cascade,
        destreza_id     text    not null,
        intentos        integer not null default 0,
        fallos          integer not null default 0,
        ultimo_fallo_en text,
        primary key (nino_id, destreza_id)
      )
    ''');

    // Historial de cambios de nivel, para que el padre vea por qué subió o bajó.
    await db.execute('''
      create table cambios_nivel (
        id            integer primary key autoincrement,
        nino_id       integer not null references ninos(id) on delete cascade,
        asignatura    text    not null,
        nivel_antes   integer not null,
        nivel_despues integer not null,
        motivo        text    not null,
        creado_en     text    not null
      )
    ''');

    await db.execute('''
      create table ajustes (
        clave text primary key,
        valor text not null
      )
    ''');

    await _crearNouns(db);
  }

  /// Las bases de datos que ya están en los móviles de las familias.
  ///
  /// Se migra hacia delante y nunca se borra nada: el historial de un niño que
  /// lleva meses estudiando no se puede perder porque la app haya aprendido a
  /// dar premios.
  static Future<void> _migrar(Database db, int desde, int hasta) async {
    if (desde < 2) await _crearNouns(db);
  }

  /// El premio del día.
  ///
  /// Un Noun no se guarda como imagen sino como su código —"1-9-5-113-3"—,
  /// que son los cinco rasgos que lo componen. El dibujo se reconstruye al
  /// enseñarlo, así que una colección de un año entero ocupa unos kilobytes.
  ///
  /// El índice único sobre (niño, día) es la regla de "uno al día", y está
  /// aquí y no en el código de la app a propósito: es la base de datos la que
  /// no deja que existan dos, pase lo que pase por encima.
  static Future<void> _crearNouns(Database db) async {
    await db.execute('''
      create table nouns (
        id        integer primary key autoincrement,
        nino_id   integer not null references ninos(id) on delete cascade,
        dia       text    not null,
        codigo    text    not null,
        rareza    text    not null,
        creado_en text    not null
      )
    ''');
    await db.execute('create unique index nouns_dia on nouns (nino_id, dia)');
    await db.execute(
      'create index nouns_nino on nouns (nino_id, creado_en desc)',
    );
  }
}
