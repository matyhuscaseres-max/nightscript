# NightScript

Proyecto independiente para experimentar con automatizaciones de conducción en **Night Rider 🏍️ [TESTING]** de Roblox.

## Estado actual

**v0.1.0 — Auto Lane (prototipo para PC)**

- Activa/desactiva el cambio automático de carril desde una pequeña interfaz.
- Espera a que el personaje alcance velocidad de autopista.
- Alterna entre izquierda y derecha con intervalos aleatorios.
- Comprueba con raycasts si el carril contiguo parece libre.
- Reintenta más pronto si ambos lados están ocupados.
- RightShift muestra u oculta el panel.

## Ajustes

En la tabla `CONFIG` de `NightScript.lua` puedes cambiar:

- `MinInterval` / `MaxInterval`: intervalo entre cambios (segundos).
- `MinSpeed`: velocidad horizontal mínima (studs/s).
- `LaneOffset`: distancia lateral estimada al carril contiguo.
- `LookAhead`: distancia de comprobación de tráfico.
- `SteerDuration`: cuánto tiempo mantiene A o D.

## Limitaciones de esta primera versión

- Está pensada para teclado de PC; no implementa controles táctiles ni mando.
- No se ha probado dentro de un servidor real todavía.
- Los controles A/D y las distancias deben verificarse con la moto elegida.
- La comprobación por raycast es básica: puede no detectar todos los vehículos o puede marcar obstáculos del mapa como carril ocupado.
- No modifica ni reutiliza el código ofuscado de terceros.

Usa el script únicamente donde esté permitido por las reglas del juego y de la plataforma.
