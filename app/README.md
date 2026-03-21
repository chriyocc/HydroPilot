# HydroPilot App

HydroPilot is a Flutter Android-first MVP for monitoring and controlling a hydroponic system powered by an ESP32.

This directory contains only the Flutter mobile app.

Related projects in this repo:

- Backend: [`/Users/yoyojun/Documents/GitHub/HydroPilot/backend`](/Users/yoyojun/Documents/GitHub/HydroPilot/backend)
- Firmware: [`/Users/yoyojun/Documents/GitHub/HydroPilot/firmware/esp32`](/Users/yoyojun/Documents/GitHub/HydroPilot/firmware/esp32)

## MVP Features

- Dashboard with pH, EC, water temperature, water level, pump status, and grow light status
- Manual controls for pump, grow light, nutrient A, and nutrient B
- Live runtime updates from the backend via Server-Sent Events (SSE)
- WiFi setup flow for ESP32 AP mode via `POST http://192.168.4.1/wifi`
- Local settings for backend base URL

## Transport Model

HydroPilot uses a hybrid transport design:

- **Local REST**
  For AP onboarding, local service/config, and local debug while the phone is on the same network as the ESP32.
- **Remote MQTT**
  For remote commands, state synchronization, alarms, and telemetry without exposing the ESP32 directly to the public internet.

### Current Flutter Implementation

The Flutter app now uses the backend as the runtime transport:

- `GET /api/device/status`
- `POST /api/device/commands/pump`
- `POST /api/device/commands/light`
- `POST /api/device/commands/nutrient/a`
- `POST /api/device/commands/nutrient/b`
- `GET /api/device/events`

The only direct ESP32 call that remains in the mobile app is:

- `POST /wifi` at `192.168.4.1`

### Backend Runtime Notes

The app expects a backend base URL such as:

- `http://192.168.1.44:3000` on a LAN
- `https://your-backend.example.com` when deployed

The app does **not** use `localhost` to reach the backend unless the device/emulator is configured to map it explicitly.

## Documentation

The main API and transport contract lives in:

- [`/Users/yoyojun/Documents/GitHub/HydroPilot/docs/API_DOCUMENTATION.md`](/Users/yoyojun/Documents/GitHub/HydroPilot/docs/API_DOCUMENTATION.md)

## Run

```bash
flutter pub get
flutter run
```
