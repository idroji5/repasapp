# De dónde sale el arte

Los dibujos de la colección son **Nouns** (<https://nouns.wtf>).

El arte de Nouns está en **dominio público (CC0)**: la propia Nouns DAO lo
publica así, y por eso se puede usar, modificar y redistribuir sin permiso ni
atribución, también dentro de una app que se descarga la gente. Esta página
existe de todas formas, porque atribuir lo que uno no ha dibujado está bien
aunque la licencia no lo exija.

Lo que hay en `nouns/image-data.json` es el fichero del repositorio oficial
[`nounsDAO/nouns-monorepo`](https://github.com/nounsDAO/nouns-monorepo), en
`packages/nouns-assets/src/image-data.json`, **sin modificar**. Contiene los
442 rasgos tal y como están escritos en la cadena de bloques.

Ojo con la distinción, que importa: el *paquete npm* `@nouns/assets` es código
y va bajo GPL-3.0; el *arte* que ese paquete transporta es CC0. Lo que entra en
RepasApp es el arte.

## Lo que RepasApp pone de su parte

Nouns no tiene rarezas: los diez mil Nouns se sortearon con todos los rasgos
igual de probables. Las cuatro categorías que ve el niño —Normal, Raro, Extra
raro y Especial—, los nombres en español y los rasgos que se han dejado fuera
son decisiones de esta app y están en `catalogo.json`.

## Lo que se ha dejado fuera

Nouns se dibujó para una comunidad de adultos. RepasApp es una app de deberes
para niños de 6 a 12 años, así que no entran ocho rasgos:

| Rasgo | Qué es |
|---|---|
| `head-beer` | Una jarra de cerveza |
| `head-wine` | Una copa de vino |
| `head-wine-barrel` | Un barril de vino |
| `head-weed` | Una hoja de marihuana |
| `head-peyote` | Un peyote |
| `head-pipe` | Una pipa de fumar |
| `head-pill` | Una pastilla |
| `accessory-stains-blood` | Una camiseta manchada de sangre |

Quedan 442 rasgos y 48.402.120 combinaciones.
