import 'package:flutter/material.dart';

/// Quién está encima de quién en la pila de pantallas.
///
/// Lo usa el plan de hoy para recargarse cuando se vuelve a él: al terminar una
/// actividad se guarda la nota, y si la lista no se entera, la asignatura recién
/// hecha sigue apareciendo como pendiente.
final RouteObserver<PageRoute<dynamic>> observadorDeRutas =
    RouteObserver<PageRoute<dynamic>>();
