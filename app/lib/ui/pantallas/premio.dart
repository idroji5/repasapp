import 'package:flutter/material.dart';

import '../../datos/modelos.dart';
import '../../dominio/coleccion.dart';
import '../widgets/cromo.dart';
import '../widgets/noun.dart';
import '../widgets/sala.dart';
import '../widgets/sorpresa.dart';
import 'coleccion.dart';

/// El cromo del día.
///
/// Sale una sola vez, cuando el niño acaba de corregir la última de las tres
/// actividades. No depende de cómo le haya ido: si dependiera, sería otra nota
/// más y no un premio, y el día que peor lo pasa es justo el que más falta le
/// hace terminar.
///
/// Llega dentro de una caja cerrada y hay que tocarla. Nada del cromo se ve
/// antes: ni el nombre, ni la rareza, ni el color. Enseñarlo de entrada
/// convierte el premio en un aviso.
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
    // Si desde fuera llega otro cromo, la caja se vuelve a cerrar. Sin esto, el
    // estado se reaprovecha y la pantalla se queda enseñando el premio de
    // antes.
    if (anterior.noun.codigo != widget.noun.codigo) {
      _noun = widget.noun;
      _tirada++;
      _abierta = false;
      _revelado = false;
    }
  }

  void _alAbrir() {
    setState(() => _abierta = true);
    // Los botones esperan a que la caja termine de abrirse. Saliendo a la vez
    // que el toque, se puede salir de aquí sin haber visto lo que había dentro.
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
    final ancho = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: Sala.fondo,
      body: Stack(
        children: [
          // La luz de la sala toma el color de la rareza al abrirse. Es la
          // única manera de que el color salga del marco del cromo y llegue a
          // la pantalla entera.
          Sala(color: _abierta ? color : null, altoDelFoco: -0.28),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 34, 28, 0),
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
                          letterSpacing: -0.4,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 22,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          // Entre un texto y el otro pasa por vacío a
                          // propósito: cruzándose se leen los dos a la vez.
                          child: Text(
                            switch ((_abierta, _revelado)) {
                              (false, _) => 'Toca el regalo para abrirlo',
                              (true, false) => '',
                              (true, true) => 'Este es tu cromo de hoy',
                            },
                            key: ValueKey((_abierta, _revelado)),
                            style: TextStyle(
                              color: _abierta
                                  ? Colors.white.withValues(alpha: 0.6)
                                  : Colors.white,
                              fontSize: 17,
                              height: 22 / 17,
                              fontWeight: _abierta
                                  ? FontWeight.w400
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Sorpresa(
                        key: ValueKey(_tirada),
                        rareza: rareza,
                        lado: (ancho * 0.667).clamp(190.0, 280.0),
                        onAbierta: _alAbrir,
                        dentro: SizedBox(
                          width: (ancho * 0.605).clamp(196.0, 260.0),
                          child: Cromo(
                            noun: _noun,
                            catalogo: widget.catalogo,
                            pie: _noun.codigo,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Los botones no existen hasta que la caja está abierta.
                AnimatedOpacity(
                  opacity: _revelado ? 1 : 0,
                  duration: const Duration(milliseconds: 320),
                  child: IgnorePointer(
                    ignoring: !_revelado,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 22, 28, 24),
                      child: Column(
                        children: [
                          if (widget.prueba) ...[
                            Text(
                              'Es una prueba: este no se guarda en el álbum.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.38),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          _BotonSala(
                            texto: widget.prueba ? 'Otro' : 'Ver mi álbum',
                            icono: widget.prueba
                                ? Icons.refresh_rounded
                                : Icons.grid_view_rounded,
                            // El gris del normal es un botón apagado, así que
                            // esa rareza se queda con el verde de la app.
                            color: rareza == Rareza.normal
                                ? Sala.accion
                                : color,
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
                              foregroundColor: Colors.white.withValues(
                                alpha: 0.7,
                              ),
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
        ],
      ),
    );
  }
}

/// El botón grande del álbum: alto, redondo y con la luz de su propio color
/// por debajo.
class _BotonSala extends StatelessWidget {
  const _BotonSala({
    required this.texto,
    required this.icono,
    required this.color,
    required this.onPressed,
  });

  final String texto;
  final IconData icono;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.35),
          blurRadius: 30,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: SizedBox(
      width: double.infinity,
      height: 68,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icono, size: 26),
        label: Text(texto),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
    ),
  );
}
