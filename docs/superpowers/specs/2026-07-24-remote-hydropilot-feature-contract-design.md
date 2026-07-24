# Remote HydroPilot Feature Contract Design

## Goal

Make the Flutter app's newest controls work in Real Server mode by expanding
the backend MQTT bridge while preserving the existing local ESP32 API.

## Architecture

The app continues to talk only HTTP/SSE to the backend in Real Server mode. The
backend translates app commands into MQTT and normalizes MQTT telemetry/state
into one snapshot shape. The external ESP32 firmware keeps its local `/api/*`
surface and adds MQTT command subscriptions that execute the same routines.

## Compatibility Strategy

The backend accepts both topic families:

- current backend topics: `hydro/device/device-1/...`
- current external ESP32 topics: `hydro/sensor/...`, `hydro/state/...`,
  `hydro/status`

This gives us a working migration path without requiring a firmware flash before
the backend can understand the ESP32's current publishes.

## App Surface

The Real Server mode should support the same high-level controls as Local
Network mode:

- grow light
- pump where available
- nutrient A/B one-shot commands
- prime A/B
- target-dose A/B/A+B with concentration
- shot-dose A/B

The dashboard should show the expanded sensor/state fields whenever the backend
snapshot contains them.

## Backend Surface

The backend adds HTTP endpoints for prime, target-dose, shot-dose, and EC
history. The existing SSE stream remains the realtime update channel.

## Firmware Surface

The external ESP32 firmware should add MQTT command subscriptions and a shared
command dispatcher so web and MQTT commands cannot drift.

