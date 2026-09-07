import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'datos/modelos.dart';
import 'datos/repositorio.dart';
import 'dominio/asignaturas.dart';
import 'dominio/coleccion.dart';
import 'voz/locutora.dart';

/// Estado compartido de la aplicación: quién está usándola y qué hay guardado.
///
/// No guarda el progreso de una actividad en curso: eso vive en el reproductor
/// de guiones, que muere con su pantalla. Aquí solo está lo que sobrevive.
class AppEstado extends ChangeNotifier {
  AppEstado({required this.repo, required this.voz, this.catalogo});

  final Repositorio repo;
  final Locutora voz;

  List<Nino> ninos = const [];
  bool cargando = true;

  /// El niño que está usando la app ahora mismo.
  Nino? activo;

  /// El arte de los Nouns y sus rarezas.
  ///
  /// Se carga una vez al arrancar y ya no cambia, así que entra por el
  /// constructor y no por `cargar()`: leer un asset dentro del ciclo de
  /// recarga metía una espera de verdad en medio de cada corrección.
  ///
  /// Puede ser null. Si el asset no carga, la colección desaparece de la app
  /// pero los deberes siguen funcionando: es un premio, no una asignatura.
  final CatalogoNouns? catalogo;

  static const _claveVoz = 'voz_preferida';

  Future<void> cargar() async {
    voz.vozPreferida = await repo.ajuste(_claveVoz);
    // Se arranca el motor de voz al abrir la app para que la zona de padres
    // pueda ofrecer la lista de voces sin esperar a la primera actividad. Con
    // tope: si el motor del teléfono se atasca, la app abre igual.
    try {
      await voz.preparar().timeout(const Duration(seconds: 6));
    } catch (_) {}
    ninos = await repo.ninos();
    if (activo != null) {
      activo = ninos.where((n) => n.id == activo!.id).firstOrNull;
    }
    cargando = false;
    notifyListeners();
  }

  /// El arte de la colección, o null si no se puede leer.
  static Future<CatalogoNouns?> cargarCatalogo() async {
    try {
      return CatalogoNouns.desdeJson(
        await rootBundle.loadString('assets/nouns/image-data.json'),
        await rootBundle.loadString('assets/nouns/catalogo.json'),
      );
    } catch (_) {
      return null;
    }
  }

  void elegir(Nino nino) {
    activo = nino;
    notifyListeners();
  }

  void salir() {
    activo = null;
    notifyListeners();
  }

  /// ¿Produce sonido la voz elegida?
  ///
  /// Existe porque desde fuera no se distingue "esta voz está muda" de "el
  /// teléfono no está reproduciendo": las dos suenan a silencio. Sintetizando a
  /// un fichero se separa una cosa de la otra, y el padre sabe si tiene que
  /// cambiar de voz o subir el volumen.
  Future<bool> comprobarQueLaVozSuena() => voz.generaSonido();

  /// El padre elige la voz y la oye al momento. Se guarda para siempre.
  Future<void> elegirVoz(String nombre) async {
    await voz.probarVoz(nombre);
    await repo.fijarAjuste(_claveVoz, nombre);
    notifyListeners();
  }

  Future<void> crearNino({
    required String nombre,
    required int curso,
    int? anoNacimiento,
    required int minutosDiarios,
    required Map<Asignatura, int> niveles,
  }) async {
    await repo.crearNino(
      nombre: nombre,
      curso: curso,
      anoNacimiento: anoNacimiento,
      minutosDiarios: minutosDiarios,
      niveles: niveles,
    );
    await cargar();
  }

  Future<void> actualizarNino(
    int id, {
    int? minutosDiarios,
    bool? modoPistas,
    int? curso,
  }) async {
    await repo.actualizarNino(
      id,
      minutosDiarios: minutosDiarios,
      modoPistas: modoPistas,
      curso: curso,
    );
    await cargar();
  }

  Future<void> fijarNivel(int ninoId, Asignatura asignatura, int nivel) async {
    await repo.fijarNivel(ninoId, asignatura, nivel);
    await cargar();
  }

  Future<void> borrarNino(int id) async {
    await repo.borrarNino(id);
    if (activo?.id == id) activo = null;
    await cargar();
  }
}
