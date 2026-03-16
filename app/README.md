# HydroPilot App

HydroPilot is a Flutter Android-first MVP for monitoring and controlling a hydroponic system powered by an ESP32.

## MVP Features

- Dashboard with pH, EC, water temperature, water level, pump status, and grow light status
- Manual controls for pump, grow light, nutrient A, and nutrient B
- WiFi setup flow for ESP32 AP mode via `POST http://192.168.4.1/wifi`
- Local settings for device IP, optional MQTT broker IP, topic prefix, and refresh interval

## Runtime Assumptions

HydroPilot currently uses local REST as the primary device transport.

Expected REST endpoints:

- `GET /status`
- `POST /control/pump`
- `POST /control/light`
- `POST /control/nutrient/a`
- `POST /control/nutrient/b`
- `POST /wifi` at `192.168.4.1`

Expected `GET /status` payload fields:

- `ph`
- `ec`
- `waterTemperature` or `water_temperature`
- `waterLevel` or `water_level`
- `pumpOn` or `pump_on`
- `lightOn` or `light_on`

## Run

```bash
flutter pub get
flutter run
```
