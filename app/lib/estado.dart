import 'dart:async';

import 'package:flutter/foundation.dart';

import 'datos/modelos.dart';
import 'datos/repositorio.dart';
import 'dominio/asignaturas.dart';
import 'voz/escucha.dart';
import 'voz/locutora.dart';

/// Estado compartido de la aplicación: quién está usándola y qué hay guardado.
///
/// No guarda el progreso de una actividad en curso: eso vive en el reproductor
/// de guiones, que muere con su pantalla. Aquí solo está lo que sobrevive.
class AppEstado extends ChangeNotifier {
  AppEstado({required this.repo, required this.voz, required this.oido});

  final Repositorio repo;
  final Locutora voz;
  final Escucha oido;

  List<Nino> ninos = const [];
  bool cargando = true;

  /// El niño que está usando la app ahora mismo.
  Nino? activo;

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
