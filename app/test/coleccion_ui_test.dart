import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repasapp/datos/bd.dart';
import 'package:repasapp/datos/modelos.dart';
import 'package:repasapp/datos/repositorio.dart';
import 'package:repasapp/dominio/coleccion.dart';
import 'package:repasapp/estado.dart';
import 'package:repasapp/ui/pantallas/coleccion.dart';
import 'package:repasapp/ui/pantallas/hoy.dart';
import 'package:repasapp/ui/pantallas/padres.dart';
import 'package:repasapp/ui/pantallas/premio.dart';
import 'package:repasapp/ui/tema.dart';
import 'package:repasapp/ui/widgets/noun.dart';
import 'package:repasapp/ui/widgets/sorpresa.dart';
import 'package:repasapp/voz/locutora.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Las dos pantallas del premio.
///
/// Se prueban en un móvil pequeño a propósito: el dibujo, el nombre, la rareza
/// y los dos botones son mucho contenido para 568 puntos de alto, y la primera
/// versión se salía por abajo sin que nadie se enterara.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  late CatalogoNouns catalogo;
  late Repositorio repo;
  late AppEstado estado;
  late Nino nino;

  setUp(() async {
    catalogo = CatalogoNouns.desdeJson(
      File('assets/nouns/image-data.json').readAsStringSync(),
      File('assets/nouns/catalogo.json').readAsStringSync(),
    );
    final db = await BaseDatos.abrir(rutaCompleta: inMemoryDatabasePath);
    var hoy = DateTime(2026, 6, 1, 18);
    repo = Repositorio(db, azar: Random(4), reloj: () => hoy);
    final ninoId = await repo.crearNino(
      nombre: 'Pedro',
      curso: 5,
      minutosDiarios: 30,
    );

    for (var d = 0; d < 12; d++) {
      hoy = DateTime(2026, 6, 1 + d, 18);
      final sesion = await repo.sesionDeHoy(ninoId);
      for (final a in sesion.actividades) {
        await repo.guardarCorreccion(
          actividadId: a.id,
          ninoId: ninoId,
          asignatura: a.asignatura,
          aciertos: 5,
          total: 5,
          faltas: const [],
        );
      }
      await repo.premioDelDia(ninoId, catalogo);
    }

    nino = (await repo.nino(ninoId))!;
    estado = AppEstado(
      repo: repo,
      voz: Locutora.silenciosa(),
      catalogo: catalogo,
    )..elegir(nino);
  });

  Future<void> abrir(WidgetTester tester, Widget pantalla) async {
    // Un móvil pequeño: 320x568 puntos.
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppEstado>.value(
        value: estado,
        child: MaterialApp(theme: Tema.construir(), home: pantalla),
      ),
    );
    // A mano y no con pumpAndSettle: la caja cerrada respira en bucle y esta
    // pantalla no se queda quieta nunca.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Lo que se ve de verdad.
  ///
  /// El nombre está en el árbol desde el principio —hay que reservarle el
  /// sitio para que al abrirse no salte todo hacia arriba—, así que preguntar
  /// si existe no dice nada: hay que mirar si es visible.
  double visibilidadDe(WidgetTester tester, String texto) => tester
      .widget<AnimatedOpacity>(
        find
            .ancestor(
              of: find.text(texto),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      )
      .opacity;

  Future<void> abrirLaCaja(WidgetTester tester) async {
    await tester.tap(find.byType(Sorpresa));
    await tester.pump();
    // La apertura dura 1150 ms y el nombre sale 620 ms después del toque.
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('el premio llega cerrado: nada se cuenta antes de abrirlo', (
    tester,
  ) async {
    final guardado = (await repo.nounDeHoy(nino.id))!;
    final noun = catalogo.desdeCodigo(guardado.codigo)!;

    await abrir(
      tester,
      PantallaPremio(nino: nino, noun: noun, catalogo: catalogo),
    );

    expect(find.text('¡Has terminado el día!'), findsOneWidget);
    expect(find.text('Toca el regalo para abrirlo'), findsOneWidget);
    expect(visibilidadDe(tester, noun.nombre), 0);
    expect(visibilidadDe(tester, noun.rareza.etiqueta), 0);

    // Y no se puede salir sin haber visto lo que había dentro.
    await tester.tap(find.text('Listo'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Toca el regalo para abrirlo'), findsOneWidget);

    await abrirLaCaja(tester);

    expect(find.text('Este es tu dibujo de hoy'), findsOneWidget);
    expect(visibilidadDe(tester, noun.nombre), 1);
    expect(visibilidadDe(tester, noun.rareza.etiqueta), 1);
    expect(find.text('Ver mi colección'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('del normal no se dice cada cuánto sale', (tester) async {
    // "1 de cada 1" no es un dato. Se busca uno de cada clase en la colección
    // para comprobar las dos ramas con Nouns de verdad.
    final coleccion = await repo.coleccion(nino.id);
    Noun deRareza(bool Function(Rareza) cumple) => catalogo.desdeCodigo(
      coleccion.firstWhere((n) => cumple(n.rareza)).codigo,
    )!;

    await abrir(
      tester,
      PantallaPremio(
        nino: nino,
        noun: deRareza((r) => r == Rareza.normal),
        catalogo: catalogo,
      ),
    );
    await abrirLaCaja(tester);
    expect(find.textContaining('Sale 1 de cada'), findsNothing);

    final raro = deRareza((r) => r != Rareza.normal);
    await abrir(
      tester,
      PantallaPremio(nino: nino, noun: raro, catalogo: catalogo),
    );
    await abrirLaCaja(tester);
    expect(
      find.text('Sale 1 de cada ${catalogo.unoDeCada(raro.rareza)}'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('en modo prueba se abre otra vez y no se guarda nada', (
    tester,
  ) async {
    final antes = (await repo.coleccion(nino.id)).length;
    await abrir(
      tester,
      PantallaPremio(
        nino: nino,
        noun: catalogo.tirar(Random(1)),
        catalogo: catalogo,
        prueba: true,
      ),
    );
    expect(find.text('Así se ve el premio'), findsOneWidget);

    await abrirLaCaja(tester);
    expect(find.textContaining('no se guarda'), findsOneWidget);

    // "Otro" cierra la caja y vuelve a empezar.
    await tester.tap(find.text('Otro'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Toca el regalo para abrirlo'), findsOneWidget);

    await abrirLaCaja(tester);
    expect(await repo.coleccion(nino.id), hasLength(antes));
    expect(tester.takeException(), isNull);
  });

  testWidgets('la colección los enseña todos y cuenta por rareza', (
    tester,
  ) async {
    await abrir(tester, PantallaColeccion(nino: nino));

    expect(find.text('12 dibujos'), findsOneWidget);
    // Doce fichas, aunque en una pantalla pequeña no quepan todas a la vez.
    expect(find.byType(VistaNoun), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.dragUntilVisible(
      find.byType(VistaNoun).last,
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('el álbum se abre por rareza, con página para las que faltan', (
    tester,
  ) async {
    await abrir(tester, PantallaColeccion(nino: nino));

    // Las cuatro páginas están siempre, tenga o no el niño alguna de esa clase.
    // Se recorren en el orden en el que están, de la más rara a la más común,
    // para que la pantalla solo tenga que bajar.
    final coleccion = await repo.coleccion(nino.id);
    for (final rareza in Rareza.values.reversed) {
      await tester.dragUntilVisible(
        find.text(rareza.etiqueta),
        find.byType(CustomScrollView),
        const Offset(0, -120),
      );
      final cuantos = coleccion.where((n) => n.rareza == rareza).length;
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text(rareza.etiqueta),
            matching: find.byType(Row),
          ),
          matching: find.text('$cuantos'),
        ),
        findsWidgets,
        reason: 'la página de ${rareza.etiqueta} dice cuántos lleva',
      );
      if (cuantos == 0) {
        expect(find.text('Todavía ninguno'), findsWidgets);
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('y se puede pasar a verla por fecha', (tester) async {
    await abrir(tester, PantallaColeccion(nino: nino));

    // 'Especial' es la primera página, la única que se ve sin bajar.
    expect(find.text('Especial'), findsOneWidget);
    await tester.tap(find.text('Por fecha'));
    await tester.pump();

    // Sin páginas: una sola rejilla, del más nuevo al más viejo.
    expect(find.text('Especial'), findsNothing);
    expect(find.text('12 dibujos'), findsOneWidget);
    final primero = tester.widget<VistaNoun>(find.byType(VistaNoun).first);
    expect(primero.noun.codigo, (await repo.nounDeHoy(nino.id))!.codigo);
    expect(tester.takeException(), isNull);
  });

  /// Un niño recién dado de alta, sin un solo día hecho.
  Future<(Nino, AppEstado)> reciente() async {
    final db = await BaseDatos.abrir(rutaCompleta: inMemoryDatabasePath);
    final vacio = Repositorio(db);
    final id = await vacio.crearNino(nombre: 'Ana', curso: 3);
    final soloElla = AppEstado(
      repo: vacio,
      voz: Locutora.silenciosa(),
      catalogo: catalogo,
    );
    final ana = (await vacio.nino(id))!;
    soloElla.elegir(ana);
    await soloElla.cargar();
    return (ana, soloElla);
  }

  Future<void> abrirCon(
    WidgetTester tester,
    AppEstado estado,
    Widget pantalla, {
    Size tamano = const Size(640, 1136),
  }) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppEstado>.value(
        value: estado,
        child: MaterialApp(theme: Tema.construir(), home: pantalla),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('una colección vacía lo dice y enseña lo que hay por ganar', (
    tester,
  ) async {
    final (ana, soloElla) = await reciente();
    await abrirCon(tester, soloElla, PantallaColeccion(nino: ana));

    expect(find.textContaining('Todavía no tienes ninguno'), findsOneWidget);
    // Y no se queda ahí: las cuatro páginas están, por estrenar.
    for (final rareza in Rareza.values.reversed) {
      await tester.dragUntilVisible(
        find.text(rareza.etiqueta),
        find.byType(CustomScrollView),
        const Offset(0, -120),
      );
      expect(find.text(rareza.etiqueta), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a la colección se entra desde el primer día, sin haber ganado '
      'ninguno', (tester) async {
    final (ana, soloElla) = await reciente();
    await abrirCon(
      tester,
      soloElla,
      PantallaHoy(nino: ana),
      // Alto, para que la tarjeta del final del plan quepa sin arrastrar.
      tamano: const Size(720, 2400),
    );

    expect(find.text('Mi colección'), findsOneWidget);
    expect(find.text('Mira lo que puedes ganar'), findsOneWidget);

    await tester.tap(find.text('Mi colección'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Todavía no tienes ninguno'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desde la zona de padres se puede probar el premio', (
    tester,
  ) async {
    await estado.cargar();
    tester.view.physicalSize = const Size(720, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppEstado>.value(
        value: estado,
        child: MaterialApp(
          theme: Tema.construir(),
          home: const PantallaPadres(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Todavía no hay PIN, así que lo primero es crearlo.
    expect(find.text('Crea un PIN de 4 dígitos'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.dragUntilVisible(
      find.text('Probar el premio'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Probar el premio').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Así se ve el premio'), findsOneWidget);
    expect(find.text('Toca el regalo para abrirlo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
