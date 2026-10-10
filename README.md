# BQL Manager

Addon independiente para World of Warcraft 3.3.5a que organiza el encuentro de Reina de Sangre Lana'thel (BQL) en ICC 25.

## Funciones

- Plantilla editable de 25 puestos: 2 tanques, 8 melee, 10 ranged y 5 healers.
- Selector buscable de miembros de hermandad y del grupo/banda actual, incluidos los miembros offline de la hermandad, con icono de clase, icono de rol para datos aún desconocidos y perfiles persistentes de clase/spec.
- Selector con iconos para las 30 especializaciones de WotLK, filtradas según el puesto TANK, MDPS, RDPS o HEALER.
- Composición flexible con controles para quitar y añadir funciones, máximo dos tanques y mínimo un healer.
- Árbol de mordidas de cinco rondas con nombres resueltos desde la plantilla.
- Destinos seleccionables sin repeticiones y orígenes autocompletados según el orden de infección; BOSS permanece fijo al inicio.
- Detección de la primera mordida real del boss para adaptar el árbol y los calls si eligió a un jugador distinto del planeado.
- Seguimiento de mordidas mediante el registro de combate.
- Avisos por banda y susurros al jugador que debe morder.
- Selectores validados para Aura Mastery, vuelos, MD y Tricks según clase, especialización y destino.
- Mapa visual reconstruido desde el Excel, con posiciones seleccionables por rol, intercambio automático y nombres dinámicos.
- Notas tácticas de posiciones, rango y Sombras enjambradoras.
- Importación de la banda actual sin destruir asignaciones válidas.
- Sincronización manual o automática desde el líder de grupo o el líder/asistentes de banda hacia los demás jugadores.
- Bloqueo de toda la configuración mientras el encuentro está activo, hasta que Lana'thel muera o se pulse `Detener`.
- Validador de puestos vacíos, jugadores duplicados y conflictos en el árbol.

La plantilla inicial procede de `Reina.xlsx`. En el Excel, la última ronda asignaba `MDPS4` dos veces y dejaba `MDPS6` sin mordida. El valor inicial del addon corrige ese último destino a `MDPS6`; el validador detectará si se vuelve a crear un conflicto parecido.

## Instalación

1. Copia la subcarpeta `BQLManager` dentro de `World of Warcraft\Interface\AddOns\`.
2. Comprueba que el archivo quede en `Interface\AddOns\BQLManager\BQLManager.toc`.
3. Reinicia el juego o ejecuta `/reload`.
4. Abre la ventana con `/bql`.

## Comandos

- `/bql` o `/bql show`: abre/cierra la ventana.
- `/bql start`: inicia el seguimiento si no hay un intento activo.
- `/bql stop`: detiene el seguimiento.
- `/bql reset`: limpia el progreso de mordidas.
- `/bql wave 1-5`: salta a una ronda concreta.
- `/bql announce`: anuncia el plan completo.
- `/bql sync`: envía la configuración a la banda.
- `/bql validate`: valida la plantilla y el árbol de mordidas.
- `/bql defaults`: restaura la configuración inicial después de pedir confirmación.

## Uso recomendado

Antes del pull, completa los nombres genéricos que queden en la pestaña `Plantilla` y pulsa `Validar`. El líder o un asistente puede usar `Sincronizar` manualmente o activar `Auto-sincronización`; en ese modo, los cambios sucesivos se agrupan y se envía siempre la configuración más reciente a quienes tengan activada la opción de aceptar sincronizaciones. El permiso se comprueba al iniciar el envío; todos los receptores normales del canal de grupo o banda pueden aplicar el plan. La sincronización utiliza mensajes compatibles con WotLK enviados a ritmo de un paquete por frame: la detección manual tarda un segundo y cada receptor confirma en el momento en que termina de aplicar el plan. Al completar la recepción, la pestaña visible se actualiza de inmediato, incluso si había un selector o campo enfocado. También se informa si un cliente tiene la recepción desactivada o el encuentro activo. Al iniciar el intento, usa `Iniciar`. Desde ese momento la plantilla, las mordidas, los cooldowns, las zonas y las opciones quedan en modo de solo lectura; tampoco se aceptan cambios de configuración por comandos ni por sincronización. El botón `Detener` vuelve a habilitar la edición, y la muerte de Lana'thel la habilita automáticamente. El addon anuncia la ronda actual y susurra a cada mordedor su objetivo. El seguimiento automático usa los hechizos de WotLK 3.3.5a: Mordedura vampírica (71726), Esencia de la Reina de Sangre (70867 y variantes) y Sed de sangre frenética (70877).

La cabecera de `Plantilla` permite quitar (`-`) y añadir (`+`) puestos por función. Con la plantilla en 25/25, quita primero el puesto que sobra y luego añade el nuevo rol. No se puede retirar un puesto que todavía esté usado en mordidas o cooldowns; hay que reasignarlo antes. La composición admite como máximo dos tanques y siempre conserva al menos un healer.

Los nombres de `Plantilla` se eligen manualmente desde la hermandad o desde el grupo/banda actual. Haz clic y escribe parte del nombre para filtrar; el icono identifica la clase y los miembros offline de la hermandad siguen disponibles. `Completar desde banda` es la alternativa automática: solo rellena puestos vacíos con miembros de la banda y no sobrescribe los ya asignados. La opción `Dejar puesto vacío` limpia el jugador y la spec sin eliminar el puesto ni sus asignaciones, muestra el nombre del puesto como marcador y permite buscar un reemplazo. La API de WotLK no publica la spec de un personaje offline: el addon la aprende al inspeccionarlo cuando entra al grupo y está a distancia, o cuando se selecciona manualmente su spec, y la conserva en `BQLManagerDB`. Hasta conocerla, el jugador aparece en los roles que su clase puede desempeñar; si la clase tiene varias specs compatibles, hay que elegir el icono de spec una vez. Si seleccionas a alguien que ya ocupa otro puesto, ambos jugadores se intercambian.

En `Mordidas` solo se editan los destinos. Cuando cambias un destino, los orígenes de las rondas siguientes se recalculan automáticamente. Un puesto mordido en una ronda anterior deja de aparecer como destino; si eliges uno que estaba asignado en la misma ronda o en una posterior, el addon intercambia ambos destinos para conservar el árbol sin duplicados.

Durante el encuentro, el addon compara la primera mordida real de Lana'thel con el plan. Si reconoce al jugador en la plantilla, mueve su puesto al primer destino, intercambia la asignación anterior y reconstruye el árbol antes del siguiente call. Si no encuentra el nombre, muestra una alerta local y conserva la configuración para evitar cambios ambiguos.

En `Zonas`, haz clic sobre una posición del mapa para elegir un puesto compatible. Las zonas de tanque solo muestran tanques, las melee solo MDPS, las ranged solo RDPS y las de sanación solo healers. El menú muestra `puesto · jugador`; si el puesto ya estaba colocado en otra posición, ambos se intercambian. El mapa guarda y sincroniza esta distribución.

En `Cooldowns`, cada selector muestra todos los personajes capaces de usar la habilidad, aunque ya ocupen otra fila del grupo: Aura Mastery admite paladines Holy o Retribution; DSAC, Protection o Holy; Marea de maná, chamanes Restoration; los himnos, sacerdotes; Tranquilidad, druidas; MD, cazadores; y Tricks, pícaros. Si eliges un lanzador ya asignado en ese grupo, ambos puestos se intercambian para evitar duplicados. En MD/Tricks este intercambio solo aplica al origen, por lo que varios lanzadores pueden compartir destino. Los destinos de MD/Tricks pueden ser tanques o la primera mordida. Al seleccionar otro DPS como destino, ese puesto pasa automáticamente a ser la primera mordida y se reconstruye el árbol.

Los anuncios a `RAID_WARNING` requieren ser líder o asistente. Si no lo eres, el addon usa el canal de banda normal.
