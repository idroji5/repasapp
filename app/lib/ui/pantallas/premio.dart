import 'package:flutter/material.dart';

import '../../datos/modelos.dart';
import '../../dominio/coleccion.dart';
import '../widgets/botones.dart';
import '../widgets/noun.dart';
import '../widgets/sorpresa.dart';
import 'coleccion.dart';

/// El premio del día.
///
/// Sale una sola vez, cuando el niño acaba de corregir la última de las tres
/// actividades. No depende de cómo le haya ido: si dependiera, sería otra nota
/// más y no un premio, y el día que peor lo pasa es justo el que más falta le
/// hace terminar.
///
/// El dibujo llega dentro de una caja cerrada y hay que tocarla para abrirla.
/// Ni el nombre ni la rareza aparecen antes: enseñarlos de entrada convierte
/// el premio en un aviso.
class PantallaPremio extends StatefulWidget {
  const PantallaPremio({
    super.key,
    required this.nino,
    required this.noun,
    required this.catalogo,
    this.prueba = false,
  });

  final Nino nino;
  final Noun noun;
  final CatalogoNouns catalogo;

  /// Modo prueba: se puede abrir una y otra vez y no se guarda nada. Lo usa el
  /// botón de la zona de padres.
  final bool prueba;

  @override
  State<PantallaPremio> createState() => _PantallaPremioState();
}

class _PantallaPremioState extends State<PantallaPremio> {
  late Noun _noun = widget.noun;

  /// Cambia al volver a tirar, y con ella la caja vuelve a estar cerrada.
  int _tirada = 0;

  bool _abierta = false;
  bool _revelado = false;

  @override
  void didUpdateWidget(PantallaPremio anterior) {
    super.didUpdateWidget(anterior);
    // Si desde fuera llega otro Noun, la caja se vuelve a cerrar. Sin esto, el
    // estado se reaprovecha y la pantalla se queda enseñando el premio de
    // antes con el nombre del nuevo debajo.
    if (anterior.noun.codigo != widget.noun.codigo) {
      _noun = widget.noun;
      _tirada++;
      _abierta = false;
      _revelado = false;
    }
  }

  void _alAbrir() {
    setState(() => _abierta = true);
    // El nombre y la rareza esperan a que la caja termine de abrirse. Saliendo
    // a la vez que el toque se leerían antes de ver el dibujo, y la sorpresa
    // se contaría sola.
    Future<void>.delayed(const Duration(milliseconds: 620), () {
      if (mounted) setState(() => _revelado = true);
    });
  }

  void _otraVez() {
    setState(() {
      _noun = widget.catalogo.tirar();
      _tirada++;
      _abierta = false;
      _revelado = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rareza = _noun.rareza;
    final color = colorDeRareza(rareza);

    // El dibujo se mide contra el ancho y no a lo fijo: en un móvil pequeño,
    // 240 puntos de Noun más el título y los dos botones no caben.
    final lado = (MediaQuery.sizeOf(context).width * 0.62).clamp(150.0, 250.0);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1420),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 8),
                child: Column(
                  children: [
                    Text(
                      widget.prueba
                          ? 'Así se ve el premio'
                          : '¡Has terminado el día!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      // Entre un texto y el otro pasa por vacío a propósito:
                      // cruzándose se leen los dos encima a la vez.
                      child: Text(
                        switch ((_abierta, _revelado)) {
                          (false, _) => 'Toca el regalo para abrirlo',
                          (true, false) => '',
                          (true, true) => 'Este es tu dibujo de hoy',
                        },
                        key: ValueKey((_abierta, _revelado)),
                        style: TextStyle(
                          color: _abierta ? Colors.white60 : Colors.white,
                          fontSize: 17,
                          fontWeight: _abierta
                              ? FontWeight.w400
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Sorpresa(
                      key: ValueKey(_tirada),
                      noun: _noun,
                      rareza: rareza,
                      catalogo: widget.catalogo,
                      lado: lado + 18,
                      onAbierta: _alAbrir,
                    ),
                    const SizedBox(height: 20),
                    AnimatedOpacity(
                      opacity: _revelado ? 1 : 0,
                      duration: const Duration(milliseconds: 320),
                      child: Column(
                        children: [
                          Text(
                            _noun.nombre,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SelloRareza(rareza, grande: true),
                          // Del normal no se dice cada cuánto sale: es el de
                          // todos los días, y "1 de cada 1" no es un dato.
                          if (rareza != Rareza.normal) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Sale 1 de cada ${widget.catalogo.unoDeCada(rareza)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 17,
                              ),
                            ),
                          ],
                          if (_noun.rasgoRaroQueExplicar case final raro?) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Lo raro: ${raro.nombre}',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: color, fontSize: 16),
                            ),
                          ],
                          if (widget.prueba) ...[
                            const SizedBox(height: 14),
                            const Text(
                              'Es una prueba: este no se guarda en la colección.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Los botones no existen hasta que la caja está abierta: si no, se
            // puede salir de aquí sin haber visto lo que había dentro.
            AnimatedOpacity(
              opacity: _revelado ? 1 : 0,
              duration: const Duration(milliseconds: 320),
              child: IgnorePointer(
                ignoring: !_revelado,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 20),
                  child: Column(
                    children: [
                      BotonGrande(
                        texto: widget.prueba ? 'Otro' : 'Ver mi colección',
                        icono: widget.prueba
                            ? Icons.refresh_rounded
                            : Icons.grid_view_rounded,
                        color: color,
                        onPressed: widget.prueba
                            ? _otraVez
                            : () => Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PantallaColeccion(nino: widget.nino),
                                ),
                              ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white70,
                          minimumSize: const Size(0, 48),
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('Listo'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
