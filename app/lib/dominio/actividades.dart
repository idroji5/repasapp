import '../contenido/dictados.dart';
import '../contenido/matematicas.dart';
import '../correccion/alinear.dart';
import '../correccion/matematicas.dart';
import '../voz/frases.dart';
import 'asignaturas.dart';
import 'guion.dart';

/// Cuántas faltas se repasan de viva voz antes de que el repaso canse más de lo
/// que enseña.
const int maxFaltasARepasar = 5;

// ---------------------------------------------------------------- dictado ---

Guion guionDictado(Dictado dictado) {
  final pasos = <Paso>[
    Habla(Frases.dictadoIntro(dictado.titulo)),
    const Espera(Frases.prepararPapel, [Comando.listo]),
    const Habla(Frases.empezamos),
  ];

  for (var i = 0; i < dictado.fragmentos.length; i++) {
    final texto = dictado.fragmentos[i];
    pasos.add(Fragmento(
      indice: i,
      texto: texto,
      pausaSegundos: pausaSegundos(texto, dictado.nivel),
    ));
  }

  pasos.add(const PedirFoto(Frases.dictadoFin));

  return Guion(
    asignatura: Asignatura.dictado,
    titulo: dictado.titulo,
    pasos: pasos,
    // Durante un dictado el niño tiene que poder interrumpir sin tocar nada.
    comandosGlobales: const [
      Comando.repite,
      Comando.masDespacio,
      Comando.masRapido,
      Comando.continua,
    ],
  );
}

Guion guionRepasoDictado(Correccion correccion) {
  final pasos = <Paso>[];
  final faltas = correccion.faltas.take(maxFaltasARepasar).toList();

  if (correccion.faltas.isEmpty) {
    pasos.add(const Habla(Frases.todoBien));
  } else {
    final palabras =
        faltas.map((f) => f.esperado).where((p) => p.isNotEmpty).toList();
    pasos.add(Habla(Frases.resumenFallos(correccion.faltas.length, palabras)));
    for (final falta in faltas) {
      pasos.add(Habla(explicarFalta(falta)));
    }
    if (correccion.faltas.length > maxFaltasARepasar) {
      pasos.add(const Habla(Frases.animo));
    }
  }

  return Guion(
    asignatura: Asignatura.dictado,
    titulo: 'Repaso',
    pasos: pasos,
    comandosGlobales: const [Comando.repite, Comando.continua],
  );
}

// ------------------------------------------------------------ matemáticas ---

/// Cuánto se sugiere callar tras dictar una operación. No es un límite: la
/// tanda no avanza sola, solo indica cuánto se espera antes de ofrecer ayuda.
int pausaParaCopiar(Operacion op) => (6 + op.enunciado.length * 0.6).round();

Guion guionMatematicas(List<Operacion> operaciones) {
  final pasos = <Paso>[
    Habla(Frases.matematicasIntro(operaciones.length)),
    const Espera(Frases.prepararPapel, [Comando.listo]),
    const Habla(Frases.empezamos),
  ];

  for (final op in operaciones) {
    pasos.add(Fragmento(
      indice: op.numero - 1,
      texto: Frases.operacion(op.numero, op.dictado),
      pausaSegundos: pausaParaCopiar(op),
      // La tanda espera al niño: se pasa a la siguiente cuando él lo dice.
      avanzaSolo: false,
    ));
  }

  pasos.add(PedirFoto(Frases.matematicasFin(operaciones.length)));

  return Guion(
    asignatura: Asignatura.matematicas,
    titulo: 'Operaciones',
    pasos: pasos,
    comandosGlobales: const [Comando.repite, Comando.masDespacio, Comando.continua],
  );
}

/// Repaso de una tanda de operaciones.
///
/// Con `modoPistas` la voz no da la solución de entrada: suelta una pista y
/// pregunta si ya lo ve. Solo si el niño pide una segunda pista y sigue sin
/// verlo se le da la respuesta. Es más lento y es el objetivo: quien corrige el
/// ejercicio tiene que ser el niño.
Guion guionRepasoMatematicas(
  List<ResultadoOperacion> resultados,
  bool modoPistas,
) {
  final fallos = resultados.where((r) => !r.correcta).toList();
  final pasos = <Paso>[];

  if (fallos.isEmpty) {
    pasos.add(const Habla(Frases.todoBien));
  } else {
    pasos.add(Habla(fallos.length == 1
        ? Frases.casiTodoBien(1)
        : Frases.resumenFallos(
            fallos.length, fallos.map((f) => f.operacion.enunciado).toList())));

    for (final fallo in fallos.take(maxFaltasARepasar)) {
      final op = fallo.operacion;
      pasos.add(Habla(Frases.fallasteEn(op.numero)));

      if (fallo.motivo == MotivoFallo.copia) {
        pasos.add(Habla('Ojo, que la has copiado mal. Era ${op.dictado}.'));
        continue;
      }
      if (!modoPistas) {
        pasos.add(Habla('${Frases.solucion(op.respuesta)} ${op.explicacion}'));
        continue;
      }

      pasos.add(Habla(op.pistas[0]));
      pasos.add(Pregunta(Frases.loTienes, [
        const RamaPregunta(
          Comando.loTengo,
          [Habla('Muy bien. Corrígela en el cuaderno.')],
        ),
        RamaPregunta(Comando.otraPista, [
          Habla(op.pistas[1]),
          Pregunta(Frases.loTienes, [
            const RamaPregunta(
              Comando.loTengo,
              [Habla('Eso es. Corrígela en el cuaderno.')],
            ),
            RamaPregunta(Comando.otraPista, [
              Habla('${Frases.solucion(op.respuesta)} ${op.explicacion}'),
            ]),
          ]),
        ]),
      ]));
    }
  }

  return Guion(
    asignatura: Asignatura.matematicas,
    titulo: 'Repaso',
    pasos: pasos,
    comandosGlobales: const [Comando.repite, Comando.continua],
  );
}
