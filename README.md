# BQL Manager

Addon independiente para World of Warcraft 3.3.5a que organiza el encuentro de Reina de Sangre Lana'thel (BQL) en ICC 25.

## Funciones

- Plantilla editable de 25 puestos: 2 tanques, 8 melee, 10 ranged y 5 healers.
- Selector con iconos para las 30 especializaciones de WotLK, filtradas según el puesto TANK, MDPS, RDPS o HEALER.
- Composición flexible con controles para quitar y añadir funciones, máximo dos tanques y mínimo un healer.
- Árbol de mordidas de cinco rondas con nombres resueltos desde la plantilla.
- Selectores de origen y objetivo para las mordidas, con el primer origen BOSS fijo y protegido.
- Seguimiento de mordidas mediante el registro de combate.
- Avisos por banda y susurros al jugador que debe morder.
- Asignaciones de Aura Mastery, primer y segundo vuelo, MD y Tricks.
- Mapa visual de posiciones reconstruido desde el Excel, con nombres dinámicos y zonas por color.
- Notas tácticas de posiciones, rango y Sombras enjambradoras.
- Importación de la banda actual sin destruir asignaciones válidas.
- Sincronización de configuración entre líder/asistentes que tengan el addon.
- Validador de puestos vacíos, jugadores duplicados y conflictos en el árbol.

La plantilla inicial procede de `Reina.xlsx`. En el Excel, la última ronda asignaba `MDPS4` dos veces y dejaba `MDPS6` sin mordida. El valor inicial del addon corrige ese último destino a `MDPS6`; el validador detectará si se vuelve a crear un conflicto parecido.

## Instalación

1. Copia la subcarpeta `BQLManager` dentro de `World of Warcraft\Interface\AddOns\`.
2. Comprueba que el archivo quede en `Interface\AddOns\BQLManager\BQLManager.toc`.
3. Reinicia el juego o ejecuta `/reload`.
4. Abre la ventana con `/bql`.

## Comandos

- `/bql` o `/bql show`: abre/cierra la ventana.
- `/bql start`: inicia y reinicia el seguimiento del intento.
- `/bql stop`: detiene el seguimiento.
- `/bql reset`: limpia el progreso de mordidas.
- `/bql wave 1-5`: salta a una ronda concreta.
- `/bql announce`: anuncia el plan completo.
- `/bql sync`: envía la configuración a la banda.
- `/bql validate`: valida la plantilla y el árbol de mordidas.
- `/bql defaults`: restaura la configuración inicial después de pedir confirmación.

## Uso recomendado

Antes del pull, completa los nombres genéricos que queden en la pestaña `Plantilla`, pulsa `Validar` y luego `Sincronizar`. Al iniciar el intento, usa `Iniciar`. El addon anuncia la ronda actual y susurra a cada mordedor su objetivo. El seguimiento automático usa los hechizos de WotLK 3.3.5a: Mordedura vampírica (71726), Esencia de la Reina de Sangre (70867 y variantes) y Sed de sangre frenética (70877).

La cabecera de `Plantilla` permite quitar (`-`) y añadir (`+`) puestos por función. Con la plantilla en 25/25, quita primero el puesto que sobra y luego añade el nuevo rol. No se puede retirar un puesto que todavía esté usado en mordidas o cooldowns; hay que reasignarlo antes. La composición admite como máximo dos tanques y siempre conserva al menos un healer.

Los anuncios a `RAID_WARNING` requieren ser líder o asistente. Si no lo eres, el addon usa el canal de banda normal.
