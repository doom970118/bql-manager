# Historial de cambios

Este archivo reúne los cambios visibles para los usuarios de BQL Manager. El formato está inspirado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y las versiones siguen [Semantic Versioning](https://semver.org/lang/es/).

Para preparar un release en GitHub, copia la sección de la versión correspondiente en la descripción del release.

## [Sin publicar]

### Añadido

- Ningún cambio todavía.

## [1.15.6] - 2026-10-13

### Añadido

- El orden de mordidas planeado se guarda al comenzar cada intento.
- Si Lana'thel elige una primera mordida inesperada, el árbol adaptado solo se utiliza durante ese combate.
- Al salir de combate, matar al boss o pulsar `Detener`, todos los clientes restauran su orden de mordidas anterior al pull.

## [1.15.5] - 2026-10-12

### Cambiado

- La cabecera de la plantilla usa controles compactos `- icono +`, con la cantidad debajo del icono.
- La composición exige exactamente dos tanques.

### Corregido

- Eliminados los solapamientos entre los controles de roles y los botones de la plantilla.
- El contador total de puestos tiene separación y alineación estables.

## [1.15.2] - 2026-10-12

### Añadido

- Botón para limpiar todos los jugadores y specs sin eliminar puestos, mordidas ni zonas.
- Verificación manual de specs para jugadores cercanos, con reubicación automática en un puesto compatible o liberación del puesto si no hay espacio.
- Submenús `General` y `Mordidas` dentro de la pestaña `Opciones`.

### Cambiado

- La selección manual y `Completar desde banda` validan la clase sin inspeccionar talentos automáticamente.
- Los miembros normales permanecen en modo lectura y reciben el plan del líder o asistente.
- La ventana puede moverse durante el encuentro cuando no está bloqueada.

### Corregido

- Los cooldowns inválidos o asignados a puestos vacíos pasan a `Sin asignar`.
- Las zonas, recordatorios y clases conocidas se incluyen correctamente en la sincronización.
- El encuentro se detiene después de que todo el grupo permanezca fuera de combate.
- Evitadas inspecciones continuas que afectaban los selectores y el rendimiento del juego.

## [1.14.9] - 2026-10-11

### Añadido

- Iconos locales y bordes pulsantes para identificar al mordedor y a su objetivo.
- Activación temporal de las barras amistosas únicamente mientras el jugador tiene Sed de sangre frenética.
- Herramienta de prueba de mordidas en la pestaña `Opciones`.

## [1.14.8] - 2026-10-10

### Cambiado

- Los cooldowns permiten seleccionar `Sin asignar` para reorganizar el plan.
- Un mismo lanzador no puede ocupar la misma habilidad en ambos vuelos.

## [1.14.7] - 2026-10-10

### Corregido

- Los selectores ya no se cierran por actualizaciones de inspección ajenas a la selección actual.

## [1.14.6] - 2026-10-10

### Corregido

- Compatibilidad de la inspección de talentos con los eventos disponibles en WotLK 3.3.5a.

## [1.14.5] - 2026-10-10

### Añadido

- Validación de clase y spec para jugadores cercanos de la plantilla.

## [1.14.4] - 2026-10-10

### Corregido

- Los personajes de clases híbridas pueden cambiar a otro puesto compatible aunque tuvieran una spec distinta guardada.

## [1.14.3] - 2026-10-10

### Corregido

- Las barras amistosas solo se activan para los jugadores implicados en una mordida personal.

## [1.14.2] - 2026-10-10

### Corregido

- El addon conserva la configuración previa de las barras amistosas al finalizar una señal de mordida.

## [1.14.1] - 2026-10-10

### Corregido

- La sincronización aplica inmediatamente la plantilla, mordidas y zonas sin tener que cambiar de pestaña.

## [1.14.0] - 2026-10-10

### Añadido

- Traducción inglesa como idioma de respaldo para clientes que no usan español.
- Licencia MIT con atribución del autor.

## [1.13.3] - 2026-10-10

### Cambiado

- Aumentado el tamaño de los iconos y textos de las señales de mordida.

## [1.13.2] - 2026-10-10

### Rendimiento

- Limitada la frecuencia de búsqueda de barras de nombre durante las señales de mordida.

## [1.13.1] - 2026-10-10

### Corregido

- El aviso de modo lectura ya no se superpone con las pestañas.

## [1.13.0] - 2026-10-09

### Añadido

- Resaltado local del jugador que debe morder y del jugador que será mordido.

## [1.12.11] - 2026-10-09

### Corregido

- `Completar desde banda` no reutiliza specs heredadas que puedan colocar un híbrido en el rol incorrecto.

## [1.12.10] - 2026-10-09

### Corregido

- Los miembros de la banda se asignan únicamente a puestos compatibles con su rol.

## [1.12.9] - 2026-10-09

### Añadido

- Modo de solo lectura para miembros normales de un grupo o banda.

## [1.12.8] - 2026-10-09

### Corregido

- Los cambios rápidos ya no reemplazan una sincronización en curso; el estado más reciente se envía al terminar.

## [1.12.7] - 2026-10-09

### Corregido

- La pestaña visible se refresca inmediatamente después de recibir una sincronización.

## [1.12.6] - 2026-10-09

### Corregido

- Los mensajes de sincronización se envían sin esperas largas y respetando los límites de WotLK.

## [1.12.5] - 2026-10-09

### Corregido

- La sincronización del líder llega a todos los clientes de la banda, incluidos los miembros normales.

## [1.12.4] - 2026-10-09

### Corregido

- Transporte de sincronización compatible con la API de mensajes de addon de WotLK 3.3.5a.

## [1.12.3] - 2026-10-09

### Corregido

- Alineación de las columnas `Puesto`, `Personaje` y `Spec`.

## [1.12.2] - 2026-10-09

### Rendimiento

- Creación diferida de la interfaz y reutilización del menú de búsqueda de jugadores.

## [1.12.1] - 2026-10-09

### Corregido

- Los iconos de rol ya no se solapan con los selectores de personaje.

## [1.12.0] - 2026-10-09

### Añadido

- Iconos generales de tanque, daño y sanador para puestos sin clase conocida.

## [1.11.1] - 2026-10-09

### Corregido

- Sincronización disponible tanto en bandas como en grupos.

## [1.11.0] - 2026-10-09

### Añadido

- Bloqueo de la configuración mientras el encuentro está activo.

## [1.10.0] - 2026-10-09

### Añadido

- Auto-sincronización opcional de los cambios realizados por el líder o un asistente.

## [1.9.5] - 2026-10-09

### Eliminado

- Retirado el frame auxiliar de mordidas que no podía proporcionar selección segura de objetivos durante el combate.

## [1.9.4] - 2026-10-09

### Añadido

- Los selectores de plantilla incluyen jugadores del grupo o banda aunque no pertenezcan a la hermandad.

## [1.9.3] - 2026-10-09

### Corregido

- El checkbox `Bloquear ventana` permanece dentro de los límites de la ventana.

## [1.9.2] - 2026-10-09

### Cambiado

- Los puestos vacíos muestran su identificador, como `TANK1` o `RDPS4`.

## [1.9.1] - 2026-10-09

### Añadido

- Opción para dejar vacío un puesto sin eliminarlo de la composición.

## [1.9.0] - 2026-10-09

### Añadido

- Selectores persistentes de jugadores de la hermandad con búsqueda por texto.
- Memoria local de clase y spec aprendidas al coincidir con un jugador en el grupo.

## [1.8.2] - 2026-10-09

### Cambiado

- Seleccionar un jugador ya utilizado en un grupo de cooldowns intercambia ambas asignaciones.

## [1.8.1] - 2026-10-09

### Corregido

- Un mismo lanzador no puede aparecer más de una vez dentro del mismo grupo de cooldowns.

## [1.8.0] - 2026-10-09

### Añadido

- Selectores de cooldowns filtrados por clase, spec y objetivo permitido.

## [1.7.2] - 2026-10-09

### Corregido

- La ventana se integra con las demás ventanas del juego y puede pasar al segundo plano.

## [1.7.1] - 2026-10-09

### Corregido

- Los menús reutilizados restablecen correctamente la posición y recorte de sus iconos.

## [1.7.0] - 2026-10-09

### Añadido

- Asignación de puestos en el mapa de zonas con filtros por rol e intercambio de posiciones.

## [1.6.0] - 2026-10-09

### Añadido

- Detección de la primera mordida real de Lana'thel y adaptación automática del árbol.

## [1.5.0] - 2026-10-09

### Añadido

- Cálculo automático de los orígenes de mordida y prevención de destinos repetidos.

## [1.4.0] - 2026-10-09

### Añadido

- Selectores de puestos para editar los destinos del árbol de mordidas.

## [1.3.0] - 2026-10-09

### Añadido

- Composición flexible de puestos `TANK`, `MDPS`, `RDPS` y `HEALER`.

## [1.2.0] - 2026-10-08

### Añadido

- Selectores visuales de clase y spec filtrados por el rol del puesto.

## [1.1.0] - 2026-10-08

### Añadido

- Primera versión de BQL Manager.
- Plantilla de banda, árbol de mordidas, planificación de cooldowns y mapa de zonas para Reina de Sangre Lana'thel.
