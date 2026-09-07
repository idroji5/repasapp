import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:repasapp/datos/bd.dart';
import 'package:repasapp/datos/repositorio.dart';
import 'package:repasapp/dominio/coleccion.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// El premio del día: un Noun al azar por día terminado.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late CatalogoNouns catalogo;

  setUpAll(() {
    catalogo = CatalogoNouns.desdeJson(
      File('assets/nouns/image-data.json').readAsStringSync(),
      File('assets/nouns/catalogo.json').readAsStringSync(),
    );
  });

  // ------------------------------------------------------------ el arte ---

  test('el dibujo se reconstruye entero desde el código', () {
    final noun = catalogo.tirar(Random(1));
    final pixeles = catalogo.pixeles(noun);

    expect(pixeles, hasLength(32 * 32 * 4));
    // Nada transparente: el fondo cubre el lienzo y los rasgos van encima.
    for (var i = 3; i < pixeles.length; i += 4) {
      expect(pixeles[i], 255);
    }
    // Y el mismo código da exactamente los mismos píxeles, siempre.
    expect(catalogo.pixeles(catalogo.desdeCodigo(noun.codigo)!), pixeles);
  });

  test('un código de ida y vuelta es el mismo Noun', () {
    final azar = Random(7);
    for (var i = 0; i < 200; i++) {
      final noun = catalogo.tirar(azar);
      final vuelta = catalogo.desdeCodigo(noun.codigo);
      expect(vuelta, isNotNull);
      expect(vuelta!.codigo, noun.codigo);
      expect(vuelta.rareza, noun.rareza);
      expect(vuelta.nombre, noun.nombre);
    }
  });

  test('un código roto no revienta la colección', () {
    // Pasa de verdad si algún día se retira un rasgo: los Nouns que ya lo
    // tenían siguen guardados. Perder la ficha es peor que no enseñarla.
    for (final malo in [
      '',
      'hola',
      '1-2-3',
      '9-0-0-0-0',
      '0-0-0-99999-0',
      '0-x-0-0-0',
    ]) {
      expect(catalogo.desdeCodigo(malo), isNull, reason: malo);
    }
  });

  test('todos los rasgos del catálogo tienen nombre en español', () {
    for (final capa in ['bodies', 'heads', 'glasses']) {
      for (final rasgo in catalogo.rasgos[capa]!) {
        expect(rasgo.nombre, isNotEmpty);
        // Las claves de Nouns llevan guiones y cifras ("grayscale-1",
        // "taco-classic"); un nombre en español, no. Si aparece uno es que
        // se coló la clave sin traducir y el niño la vería tal cual.
        expect(
          rasgo.nombre,
          isNot(contains('-')),
          reason: '$capa/${rasgo.clave} se quedó sin traducir',
        );
        expect(
          rasgo.nombre,
          isNot(matches(RegExp(r'[0-9]'))),
          reason: '$capa/${rasgo.clave} se quedó sin traducir',
        );
      }
    }
  });

  test('no hay alcohol ni drogas en el catálogo', () {
    final claves = [
      for (final capa in CatalogoNouns.capas)
        for (final r in catalogo.rasgos[capa]!) r.clave,
    ];
    for (final fuera in [
      'beer',
      'wine',
      'wine-barrel',
      'weed',
      'peyote',
      'pipe',
      'pill',
      'stains-blood',
    ]) {
      expect(claves, isNot(contains(fuera)));
    }
  });

  // ----------------------------------------------------------- rarezas ---

  test('las rarezas salen con la frecuencia que se le promete al niño', () {
    final azar = Random(20260907);
    final cuenta = <Rareza, int>{};
    const tiradas = 200000;
    for (var i = 0; i < tiradas; i++) {
      final r = catalogo.tirar(azar).rareza;
      cuenta[r] = (cuenta[r] ?? 0) + 1;
    }

    for (final rareza in Rareza.values) {
      final medido = (cuenta[rareza] ?? 0) / tiradas;
      final teorico = catalogo.probabilidades[rareza]!;
      // El "1 de cada N" de la ficha sale de `teorico`, así que si el sorteo
      // se desviara de él la app estaría mintiéndole al niño.
      expect(medido, closeTo(teorico, teorico * 0.05), reason: rareza.clave);
    }

    // Lo que se le enseña al niño tiene que significar algo: "raro" no puede
    // ser uno de cada tres.
    expect(catalogo.probabilidades[Rareza.normal], closeTo(0.70, 0.03));
    expect(catalogo.unoDeCada(Rareza.raro), inInclusiveRange(4, 7));
    expect(catalogo.unoDeCada(Rareza.extraRaro), inInclusiveRange(10, 16));
    expect(catalogo.unoDeCada(Rareza.especial), inInclusiveRange(40, 70));
  });

  test('la rareza de un Noun es la de su rasgo más raro', () {
    final azar = Random(3);
    for (var i = 0; i < 500; i++) {
      final noun = catalogo.tirar(azar);
      final masRaro = noun.rasgos.values
          .map((r) => r.rareza.index)
          .reduce((a, b) => a > b ? a : b);
      expect(noun.rareza.index, masRaro);
      // Y si no es normal se puede decir por qué, que es lo que se enseña.
      expect(
        noun.rasgoRaro?.rareza,
        noun.rareza == Rareza.normal ? null : noun.rareza,
      );
      // Y no se repite el nombre: si lo raro es la cabeza, no hay nada que
      // explicar porque la cabeza ya es el nombre del Noun.
      if (noun.rasgoRaroQueExplicar case final explicar?) {
        expect(explicar.nombre, isNot(noun.nombre));
      }
    }
  });

  // ------------------------------------------------------ uno por día ---

  Future<(Repositorio, int)> conNinoQueTerminaHoy(DateTime cuando) async {
    final db = await BaseDatos.abrir(rutaCompleta: inMemoryDatabasePath);
    final repo = Repositorio(db, azar: Random(5), reloj: () => cuando);
    final ninoId = await repo.crearNino(
      nombre: 'Pedro',
      curso: 5,
      minutosDiarios: 30,
    );
    return (repo, ninoId);
  }

  Future<void> terminarElDia(Repositorio repo, int ninoId) async {
    final sesion = await repo.sesionDeHoy(ninoId);
    for (final actividad in sesion.actividades) {
      await repo.guardarCorreccion(
        actividadId: actividad.id,
        ninoId: ninoId,
        asignatura: actividad.asignatura,
        aciertos: 5,
        total: 5,
        faltas: const [],
      );
    }
  }

  test('sin terminar el día no hay premio', () async {
    final (repo, ninoId) = await conNinoQueTerminaHoy(DateTime(2026, 9, 7, 18));
    final sesion = await repo.sesionDeHoy(ninoId);
    expect(sesion.actividades.length, greaterThan(1));

    // Todas menos la última.
    for (final actividad in sesion.actividades.sublist(
      0,
      sesion.actividades.length - 1,
    )) {
      await repo.guardarCorreccion(
        actividadId: actividad.id,
        ninoId: ninoId,
        asignatura: actividad.asignatura,
        aciertos: 5,
        total: 5,
        faltas: const [],
      );
      expect(await repo.premioDelDia(ninoId, catalogo), isNull);
    }
    expect(await repo.coleccion(ninoId), isEmpty);
  });

  test('al terminar las tres se gana uno, y solo uno', () async {
    final (repo, ninoId) = await conNinoQueTerminaHoy(DateTime(2026, 9, 7, 18));
    await terminarElDia(repo, ninoId);

    final premio = await repo.premioDelDia(ninoId, catalogo);
    expect(premio, isNotNull);
    expect(catalogo.desdeCodigo(premio!.codigo), isNotNull);

    // Llamarlo otra vez no da un segundo: la corrección llama a esto cada vez
    // que se corrige algo, incluidas las repeticiones del mismo día.
    expect(await repo.premioDelDia(ninoId, catalogo), isNull);
    expect(await repo.coleccion(ninoId), hasLength(1));
    expect((await repo.nounDeHoy(ninoId))!.codigo, premio.codigo);
  });

  test('mañana toca otro', () async {
    var hoy = DateTime(2026, 9, 7, 18);
    final db = await BaseDatos.abrir(rutaCompleta: inMemoryDatabasePath);
    final repo = Repositorio(db, azar: Random(11), reloj: () => hoy);
    final ninoId = await repo.crearNino(
      nombre: 'Ana',
      curso: 4,
      minutosDiarios: 30,
    );

    await terminarElDia(repo, ninoId);
    expect(await repo.premioDelDia(ninoId, catalogo), isNotNull);

    hoy = DateTime(2026, 9, 8, 18);
    expect(await repo.nounDeHoy(ninoId), isNull);
    await terminarElDia(repo, ninoId);
    expect(await repo.premioDelDia(ninoId, catalogo), isNotNull);

    final coleccion = await repo.coleccion(ninoId);
    expect(coleccion, hasLength(2));
    // La más nueva primero: es como se lee un álbum.
    expect(coleccion.first.dia, DateTime(2026, 9, 8));
  });

  test('el premio no depende del niño ni del día', () async {
    // Dos niños que terminan el mismo día con el mismo azar del repositorio
    // no tienen por qué sacar lo mismo, y sobre todo: nada en el sorteo mira
    // quién es, qué día es ni cómo le ha ido.
    final salidas = <String>{};
    for (var i = 0; i < 40; i++) {
      final db = await BaseDatos.abrir(rutaCompleta: inMemoryDatabasePath);
      final repo = Repositorio(
        db,
        azar: Random(i),
        reloj: () => DateTime(2026, 9, 7, 18),
      );
      final ninoId = await repo.crearNino(
        nombre: 'Niño $i',
        curso: 5,
        minutosDiarios: 30,
      );
      await terminarElDia(repo, ninoId);
      salidas.add((await repo.premioDelDia(ninoId, catalogo))!.codigo);
    }
    expect(salidas.length, greaterThan(30));
  });

  test('borrar un niño se lleva su colección', () async {
    final (repo, ninoId) = await conNinoQueTerminaHoy(DateTime(2026, 9, 7, 18));
    await terminarElDia(repo, ninoId);
    await repo.premioDelDia(ninoId, catalogo);
    expect(await repo.coleccion(ninoId), hasLength(1));

    await repo.borrarNino(ninoId);
    expect(await repo.coleccion(ninoId), isEmpty);
  });

  test('una base de datos de la versión 1 se migra sin perder nada', () async {
    final ruta = '${Directory.systemTemp.createTempSync().path}/vieja.db';

    // Se abre a la v1 y se estudia un día entero, como una familia que ya
    // lleva meses con la app instalada.
    final vieja = await databaseFactory.openDatabase(
      ruta,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          // El esquema de la v1: todo menos la tabla de nouns.
          final actual = await BaseDatos.abrir(
            rutaCompleta: inMemoryDatabasePath,
          );
          for (final t in await actual.query(
            'sqlite_master',
            where:
                "type in ('table','index') and name not like 'sqlite_%' "
                "and name not like 'nouns%'",
          )) {
            if (t['sql'] != null) await db.execute(t['sql']! as String);
          }
          await actual.close();
        },
      ),
    );
    final repoViejo = Repositorio(vieja, reloj: () => DateTime(2026, 9, 6, 18));
    final ninoId = await repoViejo.crearNino(
      nombre: 'Pedro',
      curso: 5,
      minutosDiarios: 30,
    );
    await terminarElDia(repoViejo, ninoId);
    await vieja.close();

    // Y ahora se actualiza la app.
    final nueva = await BaseDatos.abrir(rutaCompleta: ruta);
    final repo = Repositorio(nueva, reloj: () => DateTime(2026, 9, 7, 18));

    expect((await repo.nino(ninoId))!.nombre, 'Pedro');
    expect((await repo.estadisticas(ninoId)).racha, 1);
    expect(await repo.coleccion(ninoId), isEmpty);

    await terminarElDia(repo, ninoId);
    expect(await repo.premioDelDia(ninoId, catalogo), isNotNull);
  });
}
