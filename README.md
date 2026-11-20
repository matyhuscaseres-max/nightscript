# NightScript

Proyecto independiente para experimentar con automatizaciones de conducción en Night Rider [TESTING] de Roblox.

## Lane Change Companion

Archivo: `LaneChangeAddon.lua`

Complemento independiente para PC:
- Se ejecuta junto al sistema de farmeo existente.
- Se activa y desactiva desde su propia interfaz.
- Comprueba que el personaje esté sentado y que la moto se mueva.
- Alterna toques mínimos de A y D, aproximadamente cada 0.4 segundos, para hacer un zigzag suave.
- Da un toque muy corto por lado y alterna continuamente; no mantiene el giro ni hace correcciones repetidas.
- RightShift muestra u oculta el panel.

El complemento no detecta si el otro sistema está farmeando; actívalo manualmente mientras conduces/farmeas. Tampoco incluye funciones para ocultar automatización ni evadir anti-cheat.

## Ajustes

Edita la tabla `CONFIG` en `LaneChangeAddon.lua`:
- `IntervalSeconds`: tiempo entre toques (0.4 segundos por defecto).
- `SteerHoldSeconds`: duración del toque mínimo A/D (0.02 segundos por defecto).
- `MinSpeed`: velocidad mínima para enviar el cambio.

Es un prototipo de PC y necesita probarse en el juego. Las teclas y el tiempo de pulsación pueden requerir ajuste según el comportamiento de la moto. No se ha probado en un servidor real.
