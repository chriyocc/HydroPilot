# HydroPilot App

HydroPilot is a Flutter Android-first MVP for monitoring and controlling a hydroponic system powered by an ESP32.

This directory contains only the Flutter mobile app.

Related projects in this repo:

- Backend: [`/Users/yoyojun/Documents/GitHub/HydroPilot/backend`](/Users/yoyojun/Documents/GitHub/HydroPilot/backend)
- Firmware: [`/Users/yoyojun/Documents/GitHub/HydroPilot/firmware/esp32`](/Users/yoyojun/Documents/GitHub/HydroPilot/firmware/esp32)

## MVP Features

- Dashboard with pH, EC, water temperature, water level, pump status, and grow light status
- Manual controls for pump, grow light, nutrient A, and nutrient B
- WiFi setup flow for ESP32 AP mode via `POST http://192.168.4.1/wifi`
- Local settings for device IP, optional MQTT broker IP, topic prefix, and refresh interval

## Transport Model

HydroPilot uses a hybrid transport design:

- **Local REST**
  For AP onboarding, local service/config, and local debug while the phone is on the same network as the ESP32.
- **Remote MQTT**
  For remote commands, state synchronization, alarms, and telemetry without exposing the ESP32 directly to the public internet.

### Current Flutter Implementation

The current Flutter app already implements local REST calls for:

- `GET /status`
- `POST /control/pump`
- `POST /control/light`
- `POST /control/nutrient/a`
- `POST /control/nutrient/b`
- `POST /wifi` at `192.168.4.1`

The current Flutter app also stores MQTT-related settings, but MQTT runtime transport is still planned rather than fully implemented.

### Local REST Notes

Local REST means the app talks directly to the ESP32 local IP such as:

- `http://192.168.4.1` in AP mode
- `http://192.168.1.50` on a LAN

It does **not** mean `localhost`.

### Local Status Payload

The current Flutter app accepts these `GET /status` fields:

- `ph`
- `ec`
- `waterTemperature` or `water_temperature`
- `waterLevel` or `water_level`
- `pumpOn` or `pump_on`
- `lightOn` or `light_on`

## Documentation

The main API and transport contract lives in:

- [`/Users/yoyojun/Documents/GitHub/HydroPilot/docs/API_DOCUMENTATION.md`](/Users/yoyojun/Documents/GitHub/HydroPilot/docs/API_DOCUMENTATION.md)

## Run

```bash
flutter pub get
flutter run
```
