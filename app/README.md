# HydroPilot App

HydroPilot is a Flutter Android-first MVP for monitoring and controlling a hydroponic system powered by an ESP32.

This directory contains only the Flutter mobile app.

Related projects in this repo:

- Backend: [`/Users/yoyojun/Documents/GitHub/HydroPilot/backend`](/Users/yoyojun/Documents/GitHub/HydroPilot/backend)
- Firmware: [`/Users/yoyojun/Documents/GitHub/HydroPilot/firmware/esp32`](/Users/yoyojun/Documents/GitHub/HydroPilot/firmware/esp32)

## MVP Features

- Dashboard with pH, EC, water temperature, water level, humidity, TDS, liquid sensors, pump status, and grow light status
- Manual controls for pump, grow light, nutrient A/B, prime A/B, target-dose A/B/A+B, and shot-dose A/B
- Live runtime updates from the backend via Server-Sent Events (SSE)
- WiFi setup flow for ESP32 AP mode via `POST http://192.168.4.1/wifi`
- Settings for Local Network mode or Real Server mode

## Transport Model

HydroPilot uses a hybrid transport design:

- **Local REST**
  For AP onboarding, local service/config, and local debug while the phone is on the same network as the ESP32.
- **Remote MQTT**
  For remote commands, state synchronization, alarms, and telemetry without exposing the ESP32 directly to the public internet.

### Current Flutter Implementation

The Flutter app has two runtime modes.

In **Real Server** mode, use your deployed backend:

```text
https://api2.yoyojun.site
```

Remote backend endpoints used by the app:

- `GET /api/device/status`
- `GET /api/device/ec-history`
- `GET /api/device/events`
- `POST /api/device/commands/pump`
- `POST /api/device/commands/light`
- `POST /api/device/commands/nutrient/a`
- `POST /api/device/commands/nutrient/b`
- `POST /api/device/commands/prime/a`
- `POST /api/device/commands/prime/b`
- `POST /api/device/commands/target-dose/a`
- `POST /api/device/commands/target-dose/b`
- `POST /api/device/commands/target-dose/ab`
- `POST /api/device/commands/shot-dose/a`
- `POST /api/device/commands/shot-dose/b`

In **Local Network** mode, the app talks directly to the ESP32:

- `GET /api/status`
- `GET /api/ec_history`
- `POST /api/toggle?device=...`
- `GET /health`
- `GET /config`
- `GET /debug/status`

For onboarding/recovery while connected to the ESP32 setup AP, the app posts:

- `POST /wifi` at `192.168.4.1`

### Backend Runtime Notes

The app expects a backend base URL such as:

- `http://192.168.1.44:3000` on a backend LAN test server
- `https://api2.yoyojun.site` for the current Cloudflare Tunnel deployment

The app does **not** use `localhost` to reach the backend unless the device/emulator is configured to map it explicitly.

## Documentation

The main API and transport contract lives in:

- [`/Users/yoyojun/Documents/GitHub/HydroPilot/docs/API_DOCUMENTATION.md`](/Users/yoyojun/Documents/GitHub/HydroPilot/docs/API_DOCUMENTATION.md)
- [`/Users/yoyojun/Documents/GitHub/HydroPilot/docs/MQTT_CONTRACT.md`](/Users/yoyojun/Documents/GitHub/HydroPilot/docs/MQTT_CONTRACT.md)
- [`/Users/yoyojun/Documents/GitHub/HydroPilot/docs/ESP32_REMOTE_FEATURE_IMPLEMENTATION_PLAN.md`](/Users/yoyojun/Documents/GitHub/HydroPilot/docs/ESP32_REMOTE_FEATURE_IMPLEMENTATION_PLAN.md)

## Run

```bash
flutter pub get
flutter run
```
