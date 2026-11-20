# NightScript

Proyecto independiente para experimentar con automatizaciones de conducción en Night Rider [TESTING] de Roblox.

## Lane Change Companion

Archivo: `LaneChangeAddon.lua`

Complemento independiente para PC:
- Se ejecuta junto al sistema de farmeo existente.
- Se activa y desactiva desde su propia interfaz.
- Comprueba que el personaje esté sentado y que la moto se mueva.
- Alterna las teclas A y D cada 2 segundos para mantenerse entre dos carriles.
- Después del cambio, usa pulsaciones cortas para intentar centrar la moto en el carril nuevo.
- RightShift muestra u oculta el panel.

El complemento no detecta si el otro sistema está farmeando; actívalo manualmente mientras conduces/farmeas. Tampoco incluye funciones para ocultar automatización ni evadir anti-cheat.

## Ajustes

Edita la tabla `CONFIG` en `LaneChangeAddon.lua`:
- `IntervalSeconds`: tiempo entre cambios (2 segundos por defecto).
- `LaneOffset`: desplazamiento lateral estimado entre carriles.
- `CenterTolerance` y `CenterTimeout`: tolerancia y tiempo máximo del centrado.
- `SteerHoldSeconds`: duración de cada pulsación A/D.
- `MinSpeed`: velocidad mínima para enviar el cambio.

Es un prototipo de PC y necesita probarse en el juego. Las teclas y el tiempo de pulsación pueden requerir ajuste según el comportamiento de la moto. No se ha probado en un servidor real.
