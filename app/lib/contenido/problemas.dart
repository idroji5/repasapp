/// Problemas con enunciado, generados con plantillas paramétricas.
///
/// Una cuenta suelta ejercita el algoritmo; un problema ejercita lo que de
/// verdad cuesta en Primaria, que es decidir QUÉ cuenta hay que hacer. Por eso
/// las pistas de aquí no hablan de llevadas ni de columnas: preguntan qué te
/// están pidiendo.
///
/// Mismo criterio que en las operaciones: plantillas y no un modelo de
/// lenguaje. Con plantillas la respuesta es exacta por construcción, el
/// enunciado nunca dice un disparate, y la misma semilla devuelve el mismo
/// problema al corregir.
library;

import 'generador.dart';
import 'numeros.dart';


const List<String> _nombres = [
  'Ana', 'Pablo', 'Marta', 'Lucas', 'Nerea', 'Hugo',
  'Elena', 'Diego', 'Julia', 'Mateo', 'Sara', 'Bruno',
];

/// Una cosa contable. El género hace falta para no preguntar "¿Cuántos
/// galletas?": un enunciado mal escrito le enseña al niño algo que no queremos.
class _Nombrable {
  const _Nombrable(this.uno, this.varios, {this.femenino = false});

  final String uno;
  final String varios;
  final bool femenino;

  String get cuantos => femenino ? 'Cuántas' : 'Cuántos';
  String get cadaUno => femenino ? 'cada una' : 'cada uno';
  String get todos => femenino ? 'todas' : 'todos';
}

const List<_Nombrable> _cosas = [
  _Nombrable('cromo', 'cromos'),
  _Nombrable('lápiz', 'lápices'),
  _Nombrable('caramelo', 'caramelos'),
  _Nombrable('libro', 'libros'),
  _Nombrable('globo', 'globos'),
  _Nombrable('sello', 'sellos'),
  _Nombrable('galleta', 'galletas', femenino: true),
  _Nombrable('canica', 'canicas', femenino: true),
  _Nombrable('flor', 'flores', femenino: true),
  _Nombrable('pegatina', 'pegatinas', femenino: true),
  _Nombrable('manzana', 'manzanas', femenino: true),
  _Nombrable('ficha', 'fichas', femenino: true),
];

const List<String> _lugares = [
  'la biblioteca', 'la clase', 'el patio', 'el almacén', 'la estantería',
];

/// Envases que agrupan cosas.
const List<_Nombrable> _envases = [
  _Nombrable('paquete', 'paquetes'),
  _Nombrable('estuche', 'estuches'),
  _Nombrable('caja', 'cajas', femenino: true),
  _Nombrable('bolsa', 'bolsas', femenino: true),
  _Nombrable('bandeja', 'bandejas', femenino: true),
  _Nombrable('cesta', 'cestas', femenino: true),
];

/// Entre quiénes se reparte.
const List<_Nombrable> _grupos = [
  _Nombrable('niño', 'niños'),
  _Nombrable('equipo', 'equipos'),
  _Nombrable('amiga', 'amigas', femenino: true),
  _Nombrable('mesa', 'mesas', femenino: true),
  _Nombrable('caja', 'cajas', femenino: true),
  _Nombrable('bolsa', 'bolsas', femenino: true),
];

const List<String> _articulos = [
  'El cuaderno', 'La goma', 'El rotulador', 'La libreta', 'El bocadillo',
];

/// "3,32 €", y "8 €" cuando no hay céntimos: un precio redondo no se escribe
/// con dos ceros detrás en ninguna tienda.
String _euros(num n) => n == n.round()
    ? '${n.round()} €'
    : '${n.toStringAsFixed(2).replaceAll('.', ',')} €';

/// "2,40" se lee "dos euros con cuarenta céntimos", no "dos coma cuatro euros".
String _dictarEuros(num n) {
  final centimos = (n * 100).round();
  return importeALetras(centimos ~/ 100, centimos % 100);
}

// ------------------------------------------------------------- plantillas ---

Cuerpo _sumaResta(Azar azar, int nivel) {
  final cosa = azar.elegir(_cosas);
  final nombre = azar.elegir(_nombres);
  final tope = techo(nivel, 40, 400);

  switch (azar.entre(0, 3)) {
    case 0:
      final a = azar.entre(11, tope);
      final b = azar.entre(11, tope);
      return Cuerpo.problema(
        texto: 'En ${azar.elegir(_lugares)} hay $a ${cosa.varios} de un color '
            'y $b de otro. ¿${cosa.cuantos} ${cosa.varios} hay en total?',
        operacion: '$a + $b',
        respuesta: '${a + b} ${cosa.varios}',
        pistas: const [
          'Te preguntan cuántos hay en total: eso es juntar los dos montones.',
          'Juntar es sumar. Coloca un número debajo del otro y suma.',
        ],
        explicacion:
            '${enteroALetras(a)} más ${enteroALetras(b)} son ${enteroALetras(a + b)}.',
        femenino: cosa.femenino,
      );

    case 1:
      final a = azar.entre(25, tope);
      final b = azar.entre(10, a - 5);
      return Cuerpo.problema(
        texto: '$nombre tenía $a ${cosa.varios} y ha regalado $b. '
            '¿${cosa.cuantos} le quedan?',
        operacion: '$a - $b',
        respuesta: '${a - b} ${cosa.varios}',
        pistas: const [
          'Te preguntan cuántos le quedan: tenía unos cuantos y ha dado algunos.',
          'Si da, se queda con menos: hay que restar.',
        ],
        explicacion:
            '${enteroALetras(a)} menos ${enteroALetras(b)} son ${enteroALetras(a - b)}.',
        femenino: cosa.femenino,
      );

    case 2:
      final a = azar.entre(25, tope);
      final b = azar.entre(10, a - 5);
      final otro = azar.elegir(_nombres.where((n) => n != nombre).toList());
      return Cuerpo.problema(
        texto: '$nombre tiene $a ${cosa.varios} y $otro tiene $b. '
            '¿${cosa.cuantos} ${cosa.varios} tiene $nombre más que $otro?',
        operacion: '$a - $b',
        respuesta: '${a - b} ${cosa.varios}',
        pistas: const [
          'Te preguntan cuántos tiene uno MÁS que el otro: es una comparación.',
          'Para comparar dos cantidades se resta la pequeña de la grande.',
        ],
        explicacion:
            '${enteroALetras(a)} menos ${enteroALetras(b)} son ${enteroALetras(a - b)}.',
        femenino: cosa.femenino,
      );

    default:
      final a = azar.entre(11, tope);
      final b = azar.entre(11, tope);
      return Cuerpo.problema(
        texto: 'En ${azar.elegir(_lugares)} había $a ${cosa.varios} y han '
            'traído $b más. ¿${cosa.cuantos} hay ahora?',
        operacion: '$a + $b',
        respuesta: '${a + b} ${cosa.varios}',
        pistas: const [
          'Te preguntan cuántos hay AHORA: había unos y han llegado más.',
          'Si llegan más, hay que sumar.',
        ],
        explicacion:
            '${enteroALetras(a)} más ${enteroALetras(b)} son ${enteroALetras(a + b)}.',
        femenino: cosa.femenino,
      );
  }
}

Cuerpo _multiplicacion(Azar azar, int nivel) {
  final cosa = azar.elegir(_cosas);
  final nombre = azar.elegir(_nombres);
  final envase = azar.elegir(_envases);

  if (azar.entre(0, 1) == 0) {
    final porEnvase = azar.entre(techo(nivel, 4, 11), techo(nivel, 9, 25));
    final cuantos = azar.entre(3, techo(nivel, 5, 9));
    return Cuerpo.problema(
      texto: 'Cada ${envase.uno} trae $porEnvase ${cosa.varios}. '
          '$nombre compra $cuantos ${envase.varios}. '
          '¿${cosa.cuantos} ${cosa.varios} tiene?',
      operacion: '$cuantos × $porEnvase',
      respuesta: '${cuantos * porEnvase} ${cosa.varios}',
      pistas: const [
        'Son varios grupos y todos tienen lo mismo dentro.',
        'Los grupos iguales se cuentan multiplicando: cuántos grupos, por '
            'cuántos hay en cada uno.',
      ],
      explicacion: '${enteroALetras(cuantos)} por ${enteroALetras(porEnvase)} '
          'son ${enteroALetras(cuantos * porEnvase)}.',
      femenino: cosa.femenino,
    );
  }

  final precio = azar.entre(techo(nivel, 3, 9), techo(nivel, 8, 24));
  final cuantas = azar.entre(3, techo(nivel, 6, 12));
  return Cuerpo.problema(
    texto: 'Una entrada del cine cuesta $precio euros. '
        '¿Cuánto cuestan $cuantas entradas?',
    operacion: '$cuantas × $precio',
    respuesta: '${cuantas * precio} euros',
    pistas: const [
      'Todas las entradas cuestan lo mismo.',
      'Repetir el mismo precio varias veces es multiplicar.',
    ],
    explicacion: '${enteroALetras(cuantas)} por ${enteroALetras(precio)} '
        'son ${enteroALetras(cuantas * precio)} euros.',
  );
}

Cuerpo _division(Azar azar, int nivel) {
  final cosa = azar.elegir(_cosas);

  // Se construye desde el cociente para que el reparto salga exacto: repartir
  // con resto obliga a explicar qué se hace con lo que sobra, y eso es otra
  // destreza distinta de la que este problema dice ejercitar.
  final porGrupo = azar.entre(techo(nivel, 3, 8), techo(nivel, 9, 24));
  final cuantosGrupos = azar.entre(3, techo(nivel, 6, 12));
  final total = porGrupo * cuantosGrupos;

  if (azar.entre(0, 1) == 0) {
    final grupo = azar.elegir(_grupos);
    return Cuerpo.problema(
      texto: 'Hay $total ${cosa.varios} para repartir entre $cuantosGrupos '
          '${grupo.varios}, y a ${grupo.todos} les toca lo mismo. ¿${cosa.cuantos} le tocan a cada ${grupo.uno}?',
      operacion: '$total : $cuantosGrupos',
      respuesta: '$porGrupo ${cosa.varios}',
      pistas: const [
        'Te piden repartir en partes iguales.',
        'Repartir en partes iguales es dividir: el total, entre el número de partes.',
      ],
      explicacion: '${enteroALetras(total)} entre ${enteroALetras(cuantosGrupos)} '
          'son ${enteroALetras(porGrupo)}.',
      femenino: cosa.femenino,
    );
  }

  final envase = azar.elegir(_envases);
  return Cuerpo.problema(
    texto: 'Con $total ${cosa.varios} se llenan ${envase.varios} de $porGrupo '
        '${cosa.varios} ${envase.cadaUno}. ¿${envase.cuantos} ${envase.varios} '
        'se llenan?',
    operacion: '$total : $porGrupo',
    respuesta: '$cuantosGrupos ${envase.varios}',
    pistas: const [
      'Todos los grupos tienen lo mismo; lo que no sabes es cuántos grupos hay.',
      'Divide el total entre lo que cabe en cada uno.',
    ],
    explicacion: '${enteroALetras(total)} entre ${enteroALetras(porGrupo)} '
        'son ${enteroALetras(cuantosGrupos)}.',
    femenino: cosa.femenino,
  );
}

Cuerpo _dosPasos(Azar azar, int nivel) {
  final cosa = azar.elegir(_cosas);
  final nombre = azar.elegir(_nombres);

  if (azar.entre(0, 1) == 0) {
    final envase = azar.elegir(_envases);
    final porEnvase = azar.entre(techo(nivel, 6, 12), techo(nivel, 12, 25));
    final cuantos = azar.entre(3, techo(nivel, 5, 9));
    final total = porEnvase * cuantos;
    final regala = azar.entre(5, total - 5);
    return Cuerpo.problema(
      texto: '$nombre compra $cuantos ${envase.varios} de $porEnvase '
          '${cosa.varios} ${envase.cadaUno} y regala $regala ${cosa.varios}. '
          '¿${cosa.cuantos} le quedan?',
      operacion: '$cuantos × $porEnvase - $regala',
      respuesta: '${total - regala} ${cosa.varios}',
      pistas: const [
        'Aquí hay dos preguntas escondidas: primero cuántos tenía, y después '
            'cuántos le quedan.',
        'Empieza por lo que compra: grupos iguales, o sea multiplicar. A ese '
            'resultado le quitas lo que regala.',
      ],
      explicacion: 'Primero, ${enteroALetras(cuantos)} por '
          '${enteroALetras(porEnvase)} son ${enteroALetras(total)}. Después, '
          '${enteroALetras(total)} menos ${enteroALetras(regala)} '
          'son ${enteroALetras(total - regala)}.',
      femenino: cosa.femenino,
    );
  }

  final grupo = azar.elegir(_grupos);
  final porGrupo = azar.entre(techo(nivel, 4, 9), techo(nivel, 10, 20));
  final cuantosGrupos = azar.entre(3, techo(nivel, 5, 9));
  final habia = porGrupo * cuantosGrupos;
  final llegan = azar.entre(5, techo(nivel, 30, 90));

  return Cuerpo.problema(
    texto: 'En el aula hay $cuantosGrupos ${grupo.varios} con $porGrupo '
        '${cosa.varios} en ${grupo.cadaUno}. '
        'Luego traen $llegan ${cosa.varios} más. '
        '¿${cosa.cuantos} ${cosa.varios} hay en total?',
    operacion: '$cuantosGrupos × $porGrupo + $llegan',
    respuesta: '${habia + llegan} ${cosa.varios}',
    pistas: const [
      'Primero averigua cuántos había antes de que trajeran más.',
      'Grupos iguales: multiplica. Y a ese resultado le sumas los que traen.',
    ],
    explicacion: 'Primero, ${enteroALetras(cuantosGrupos)} por '
        '${enteroALetras(porGrupo)} son ${enteroALetras(habia)}. Después, '
        '${enteroALetras(habia)} más ${enteroALetras(llegan)} '
        'son ${enteroALetras(habia + llegan)}.',
    femenino: cosa.femenino,
  );
}

Cuerpo _dinero(Azar azar, int nivel) {
  final nombre = azar.elegir(_nombres);
  final articulo = azar.elegir(_articulos);

  final precio = azar.entre(techo(nivel, 120, 320), techo(nivel, 480, 1400)) / 100;
  final paga = precio.ceil() + azar.entre(1, techo(nivel, 2, 6));
  final vuelta = (paga * 100 - precio * 100).round() / 100;

  return Cuerpo.problema(
    texto: '$articulo cuesta ${_euros(precio)}. $nombre paga con ${_euros(paga)}. '
        '¿Cuánto dinero le devuelven?',
    operacion: '${_euros(paga)} - ${_euros(precio)}',
    respuesta: _euros(vuelta),
    pistas: const [
      'Lo que te devuelven es lo que sobra de lo que has pagado.',
      'Es una resta con decimales: coloca las comas una debajo de la otra.',
    ],
    explicacion: '${_dictarEuros(paga)} menos ${_dictarEuros(precio)} '
        'son ${_dictarEuros(vuelta)}.',
  );
}

/// Plantillas de problemas, por microdestreza.
const Map<String, Plantilla> plantillasDeProblemas = {
  'problema_suma_resta': _sumaResta,
  'problema_multiplicacion': _multiplicacion,
  'problema_division': _division,
  'problema_dos_pasos': _dosPasos,
  'problema_dinero': _dinero,
};
