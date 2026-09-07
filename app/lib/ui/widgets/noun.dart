import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../dominio/coleccion.dart';

/// Dibuja un Noun.
///
/// El dibujo no existe hasta que se pide: en la base de datos solo hay un
/// código con los cinco rasgos. Aquí se reconstruyen los 32x32 píxeles, se
/// convierten una vez en imagen y se guardan en memoria, porque la rejilla de
/// la colección enseña cien a la vez y rehacerlos en cada fotograma la dejaría
/// a tirones.
class VistaNoun extends StatefulWidget {
  const VistaNoun({
    super.key,
    required this.noun,
    required this.catalogo,
    this.lado,
    this.radio = 12,
  });

  final Noun noun;
  final CatalogoNouns catalogo;

  /// Cuánto mide de lado. Si es null ocupa todo el hueco que le den, que es lo
  /// que necesita la rejilla de la colección: sus casillas miden lo que quepa.
  final double? lado;

  final double radio;

  @override
  State<VistaNoun> createState() => _VistaNounState();
}

/// Las imágenes ya montadas, por código.
///
/// Un Noun ocupa 32x32 en RGBA: cuatro kilobytes. Un niño que estudie todos
/// los días durante un año tendrá 365, que es poco más de un megabyte, así que
/// no hace falta desalojar nada.
final Map<String, ui.Image> _hechas = {};

Future<ui.Image> _imagenDe(CatalogoNouns catalogo, Noun noun) async {
  final ya = _hechas[noun.codigo];
  if (ya != null) return ya;

  final espera = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    catalogo.pixeles(noun),
    CatalogoNouns.lado,
    CatalogoNouns.lado,
    ui.PixelFormat.rgba8888,
    espera.complete,
  );
  return _hechas[noun.codigo] = await espera.future;
}

class _VistaNounState extends State<VistaNoun> {
  ui.Image? _imagen;

  @override
  void initState() {
    super.initState();
    _preparar();
  }

  @override
  void didUpdateWidget(VistaNoun anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.noun.codigo != widget.noun.codigo) _preparar();
  }

  void _preparar() {
    // Si ya estaba montada se coge en el mismo fotograma: sin esto, al
    // desplazar la colección cada ficha parpadearía al volver a entrar.
    final ya = _hechas[widget.noun.codigo];
    if (ya != null) {
      _imagen = ya;
      return;
    }
    _imagen = null;
    _imagenDe(widget.catalogo, widget.noun).then((img) {
      if (mounted) setState(() => _imagen = img);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dibujo = _imagen == null
        ? const ColoredBox(color: Color(0xFF2A2334))
        : CustomPaint(painter: _Pintor(_imagen!));

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radio),
      child: widget.lado == null
          ? AspectRatio(aspectRatio: 1, child: dibujo)
          : SizedBox(width: widget.lado, height: widget.lado, child: dibujo),
    );
  }
}

class _Pintor extends CustomPainter {
  const _Pintor(this.imagen);

  final ui.Image imagen;

  @override
  void paint(Canvas lienzo, Size tamano) {
    // `none` es obligatorio: cualquier suavizado convierte 32 píxeles
    // estirados a 300 en una mancha borrosa.
    lienzo.drawImageRect(
      imagen,
      Rect.fromLTWH(0, 0, imagen.width.toDouble(), imagen.height.toDouble()),
      Offset.zero & tamano,
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(_Pintor anterior) => anterior.imagen != imagen;
}

/// El color de cada rareza. Es lo que hace que la colección se lea de un
/// vistazo, sin abrir ficha por ficha.
Color colorDeRareza(Rareza rareza) => switch (rareza) {
  Rareza.normal => const Color(0xFF9E97A8),
  Rareza.raro => const Color(0xFF0F766E),
  Rareza.extraRaro => const Color(0xFF6B2FBF),
  Rareza.especial => const Color(0xFFC79021),
};

/// La etiqueta de rareza: "Extra raro", en su color.
class SelloRareza extends StatelessWidget {
  const SelloRareza(this.rareza, {super.key, this.grande = false});

  final Rareza rareza;
  final bool grande;

  @override
  Widget build(BuildContext context) {
    final color = colorDeRareza(rareza);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: grande ? 16 : 10,
        vertical: grande ? 8 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color, width: grande ? 2 : 1),
      ),
      child: Text(
        rareza.etiqueta,
        style: TextStyle(
          color: color,
          fontSize: grande ? 17 : 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
