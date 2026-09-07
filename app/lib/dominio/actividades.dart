import '../contenido/dictados.dart';
import '../contenido/matematicas.dart';
import '../correccion/dictado.dart';
import '../correccion/tanda.dart';
import '../voz/frases.dart';
import '../voz/locutora.dart';
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

  final frases = dictado.frasesDictadas;
  for (var i = 0; i < frases.length; i++) {
    pasos.add(Fragmento(
      indice: i,
      texto: frases[i],
      veces: vecesPorFrase,
    ));
  }

  pasos.add(const Revisar(Frases.dictadoFin));

  return Guion(
    asignatura: Asignatura.dictado,
    titulo: dictado.titulo,
    pasos: pasos,
    // Durante un dictado el niño manda: repite la frase las veces que quiera,
    // ajusta el ritmo y pasa a la siguiente cuando la tiene escrita.
    comandosGlobales: const [
      Comando.repite,
      Comando.masDespacio,
      Comando.masRapido,
      Comando.continua,
    ],
    velocidadInicial: velocidadDeDictado(dictado.nivel),
  );
}

/// Repaso de un dictado que el niño acaba de corregirse él mismo.
///
/// Se le explica la regla de cada palabra que ha tachado: esa es la parte que
/// enseña. Como las ha marcado sobre el texto, no hay nada que adivinar.
Guion guionRepasoDictado(CorreccionDictado correccion) {
  final pasos = <Paso>[];

  if (correccion.perfecto) {
    pasos.add(const Habla(Frases.todoBien));
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

/// Una tanda de ejercicios: matemáticas o inglés.
///
/// Las dos funcionan igual —se plantea uno, el niño lo escribe y lo resuelve, y
/// se pasa al siguiente cuando él lo dice—, así que comparten guion. Lo único
/// que cambia es cómo se presenta y que un enunciado de inglés lleva dentro
/// trozos que hay que decir en inglés.
Guion guionTanda(Asignatura asignatura, List<Ejercicio> ejercicios) {
  final conProblemas = ejercicios.any((op) => op.tienePlanteamiento);
  final esIngles = asignatura == Asignatura.ingles;

  final pasos = <Paso>[
    Habla(esIngles
        ? Frases.inglesIntro(ejercicios.length)
        : Frases.matematicasIntro(ejercicios.length, conProblemas: conProblemas)),
    const Espera(Frases.prepararPapel, [Comando.listo]),
    const Habla(Frases.empezamosMates),
  ];

  for (final op in ejercicios) {
    pasos.add(Fragmento(
      indice: op.numero - 1,
      texto: Frases.ejercicioNumero(op.numero, op.dictado),
      // Un planteamiento con enunciado tampoco se retiene a la primera: se lee dos
      // veces, igual que una frase de dictado.
      veces: op.tienePlanteamiento ? 2 : 1,
      // Pero no palabra a palabra: esto no se copia, se entiende.
      palabraAPalabra: false,
      escrito: '${op.numero}.  ${op.planteamiento ?? op.enunciado}',
    ));
  }

  pasos.add(Revisar(esIngles
      ? Frases.inglesFin(ejercicios.length)
      : Frases.matematicasFin(ejercicios.length)));

  return Guion(
    asignatura: asignatura,
    titulo: switch (asignatura) {
      Asignatura.ingles => 'Inglés',
      _ => conProblemas ? 'Ejercicios' : 'Operaciones',
    },
    pasos: pasos,
    comandosGlobales: const [Comando.repite, Comando.masDespacio, Comando.continua],
  );
}

/// Repaso de una tanda ya corregida, sea de matemáticas o de inglés.
///
/// Con `modoPistas` la voz no da la solución de entrada: suelta una pista y
/// pregunta si ya lo ve. Solo si el niño pide una segunda pista y sigue sin
/// verlo se le da la respuesta. Es más lento y es el objetivo: quien corrige el
/// ejercicio tiene que ser el niño.
Guion guionRepasoTanda(
  Asignatura asignatura,
  List<ResultadoEjercicio> resultados,
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
            fallos.length, fallos.map((f) => f.ejercicio.enunciado).toList())));

    for (final fallo in fallos.take(maxFaltasARepasar)) {
      final op = fallo.ejercicio;
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
    asignatura: asignatura,
    titulo: 'Repaso',
    pasos: pasos,
    comandosGlobales: const [Comando.repite, Comando.continua],
  );
}
