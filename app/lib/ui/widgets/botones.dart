import 'package:flutter/material.dart';

import '../../dominio/guion.dart';
import '../tema.dart';

/// Botón principal. Es deliberadamente enorme: el niño lo pulsa con el lápiz
/// en la mano y sin mirar mucho.
class BotonGrande extends StatelessWidget {
  const BotonGrande({
    super.key,
    required this.texto,
    required this.onPressed,
    this.icono,
    this.color,
    this.expandido = true,
  });

  final String texto;
  final VoidCallback? onPressed;
  final IconData? icono;
  final Color? color;
  final bool expandido;

  @override
  Widget build(BuildContext context) {
    final boton = FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color ?? Tema.accion,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Tema.borde,
        minimumSize: const Size(0, 68),
        padding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      child: Row(
        mainAxisSize: expandido ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icono != null) ...[Icon(icono, size: 26), const SizedBox(width: 12)],
          Flexible(child: Text(texto, textAlign: TextAlign.center)),
        ],
      ),
    );
    return expandido ? SizedBox(width: double.infinity, child: boton) : boton;
  }
}

/// Botón secundario, para los comandos que también se pueden decir en voz alta.
class BotonComando extends StatelessWidget {
  const BotonComando({
    super.key,
    required this.texto,
    required this.onPressed,
    this.icono,
  });

  final String texto;
  final VoidCallback onPressed;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Tema.tinta,
        backgroundColor: Tema.tarjeta,
        minimumSize: const Size(0, 56),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        side: const BorderSide(color: Tema.borde, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[Icon(icono, size: 22), const SizedBox(width: 8)],
          Text(texto),
        ],
      ),
    );
  }
}

/// Etiqueta pequeña de estado: el nivel de una asignatura, la racha, etc.
class Pastilla extends StatelessWidget {
  const Pastilla(this.texto, {super.key, this.color, this.fondo, this.icono});

  final String texto;
  final Color? color;
  final Color? fondo;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: fondo ?? Tema.accionSuave,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 15, color: color ?? Tema.accion),
            const SizedBox(width: 5),
          ],
          Text(
            texto,
            style: TextStyle(
              color: color ?? Tema.accion,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// El recordatorio de que no hace falta tocar nada.
///
/// Nombra lo que se puede decir y no tiene botón —cambiar la velocidad, sobre
/// todo—, porque si no se dice en alguna parte nadie va a adivinar que existe.
/// Cuando todo lo que se puede decir está ya en un botón, basta con recordar
/// que se puede decir.
class SePuedeDecir extends StatelessWidget {
  const SePuedeDecir({super.key, required this.comandos, required this.seEscucha});

  final List<Comando> comandos;

  /// false si el micrófono no está disponible: entonces no se promete nada.
  final bool seEscucha;

  @override
  Widget build(BuildContext context) {
    if (!seEscucha || comandos.isEmpty) return const SizedBox(height: 4);

    final sinBoton = comandos.where((c) => !c.tieneBoton).toList();
    final texto = sinBoton.isEmpty
        ? 'Puedes decirlo en voz alta'
        : 'También puedes decir: '
            '${sinBoton.map((c) => '«${c.dicho}»').join(', ')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.mic_none_rounded, size: 17, color: Tema.tintaSuave),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Tema.tintaSuave, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}
