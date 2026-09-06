import '../contenido/dictados.dart';
import '../contenido/matematicas.dart';
import '../correccion/dictado.dart';
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
      veces: vecesPorFrase,
    ));
  }

  pasos.add(const Revisar(Frases.dictadoFin));

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

/// Repaso de un dictado que el niño acaba de corregirse él mismo.
///
/// Si ha marcado en qué palabras ha fallado, se le explica la regla de cada
/// una: es la parte que enseña. Si solo ha dicho cuántas, no se inventa nada
/// —explicar la palabra equivocada es peor que no explicar ninguna— y se le
/// dice qué hacer con ellas.
Guion guionRepasoDictado(CorreccionDictado correccion) {
  final pasos = <Paso>[];

  if (correccion.perfecto) {
    pasos.add(const Habla(Frases.todoBien));
  } else if (correccion.explicadas.isEmpty) {
    pasos.add(Habla(Frases.cuantasFaltas(correccion.faltas)));
    pasos.add(const Habla(Frases.apuntaLasFaltas));
  } else {
    final faltas = correccion.explicadas.take(maxFaltasARepasar).toList();
    pasos.add(Habla(Frases.resumenFallos(
      correccion.faltas,
      faltas.map((f) => f.esperado).toList(),
    )));
    for (final falta in faltas) {
      pasos.add(Habla(explicarPalabra(falta)));
    }
    if (correccion.faltas > maxFaltasARepasar) {
      pasos.add(const Habla(Frases.animo));
    }
  }

  if (!correccion.perfecto) pasos.add(const Habla(Frases.puedesRepetir));

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
int pausaParaCopiar(Operacion op) => (6 + op.dictado.length * 0.6).round();

Guion guionMatematicas(List<Operacion> operaciones) {
  final conProblemas = operaciones.any((op) => op.esProblema);

  final pasos = <Paso>[
    Habla(Frases.matematicasIntro(operaciones.length, conProblemas: conProblemas)),
    const Espera(Frases.prepararPapel, [Comando.listo]),
    const Habla(Frases.empezamosMates),
  ];

  for (final op in operaciones) {
    pasos.add(Fragmento(
      indice: op.numero - 1,
      texto: Frases.operacion(op.numero, op.dictado),
      pausaSegundos: pausaParaCopiar(op),
      // La tanda espera al niño: se pasa a la siguiente cuando él lo dice.
      avanzaSolo: false,
      // Un problema con enunciado tampoco se retiene a la primera: se lee dos
      // veces, igual que una frase de dictado.
      veces: op.esProblema ? 2 : 1,
      escrito: '${op.numero}.  ${op.problema ?? op.enunciado}',
    ));
  }

  pasos.add(Revisar(Frases.matematicasFin(operaciones.length)));

  return Guion(
    asignatura: Asignatura.matematicas,
    titulo: conProblemas ? 'Ejercicios' : 'Operaciones',
    pasos: pasos,
    comandosGlobales: const [Comando.repite, Comando.masDespacio, Comando.continua],
  );
}

/// Repaso de una tanda de matemáticas.
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

      if (!modoPistas) {
        pasos.add(Habla(
            '${Frases.solucion(op.respuestaEnVozAlta)} ${op.explicacion}'));
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
              Habla('${Frases.solucion(op.respuestaEnVozAlta)} ${op.explicacion}'),
            ]),
          ]),
        ]),
      ]));
    }
    pasos.add(const Habla(Frases.puedesRepetir));
  }

  return Guion(
    asignatura: Asignatura.matematicas,
    titulo: 'Repaso',
    pasos: pasos,
    comandosGlobales: const [Comando.repite, Comando.continua],
  );
}
