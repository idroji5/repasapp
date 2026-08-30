import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Base de datos local. Todo se queda en el dispositivo: no hay servidor, no
/// hay cuenta, y los datos del niño no salen del teléfono de la familia.
///
/// NOTA DE PRIVACIDAD: no hay ninguna tabla de fotos, y es deliberado. La foto
/// del cuaderno se procesa en memoria, se reconoce con ML Kit y se descarta.
/// De cada foto solo sobrevive el resultado (qué se escribió mal).
class BaseDatos {
  static const String _nombreFichero = 'repasapp.db';
  static const int _version = 1;

  static Future<Database> abrir({String? rutaCompleta}) async {
    final ruta = rutaCompleta ?? p.join(await getDatabasesPath(), _nombreFichero);
    return openDatabase(ruta, version: _version, onCreate: _crear);
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
    await db.execute('create index sesiones_nino on sesiones (nino_id, dia desc)');

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
    await db.execute('create index actividades_sesion on actividades (sesion_id, orden)');
    await db.execute('create index actividades_nino on actividades (nino_id, creada_en desc)');

    await db.execute('''
      create table faltas (
        id           integer primary key autoincrement,
        nino_id      integer not null references ninos(id) on delete cascade,
        actividad_id integer not null references actividades(id) on delete cascade,
        destreza_id  text    not null,
        tipo         text    not null,
        esperado     text    not null,
        escrito      text    not null,
        creado_en    text    not null
      )
    ''');
    await db.execute('create index faltas_nino on faltas (nino_id, creado_en desc)');

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
  }
}
