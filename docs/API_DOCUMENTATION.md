# HydroPilot API Documentation

This document describes the API contract currently expected by the Flutter app in [`/Users/yoyojun/Documents/GitHub/HydroPilot/app`](/Users/yoyojun/Documents/GitHub/HydroPilot/app).

The current app is **REST-first** for the MVP.

## Base URLs

### Device Runtime API

Used for dashboard polling and manual controls.

```text
http://<device-ip>
```

Example:

```text
http://192.168.1.50
```

### ESP32 WiFi Setup API

Used only when the ESP32 is running in AP mode.

```text
http://192.168.4.1
```

## Endpoints

### 1. Get System Status

Reads hydroponic sensor values and device states.

**Request**

```http
GET /status
```

**Full URL Example**

```http
GET http://192.168.1.50/status
```

**Expected Response**

```json
{
  "ph": 6.2,
  "ec": 1.8,
  "waterTemperature": 24.5,
  "waterLevel": 82,
  "pumpOn": true,
  "lightOn": false
}
```

**Accepted field name variants**

The Flutter app currently accepts these alternative names:

- `waterTemperature`, `water_temperature`, `temp`, `temperature`
- `waterLevel`, `water_level`, `level`
- `pumpOn`, `pump_on`, `pump`
- `lightOn`, `light_on`, `light`

**Accepted boolean formats**

The app currently accepts:

- `true` / `false`
- `1` / `0`
- `"true"` / `"false"`
- `"on"` / `"off"`
- `"1"` / `"0"`

### 2. Control Pump

Turns the pump on or off.

**Request**

```http
POST /control/pump
Content-Type: application/json
```

**Request Body**

```json
{
  "on": true
}
```

### 3. Control Grow Light

Turns the grow light on or off.

**Request**

```http
POST /control/light
Content-Type: application/json
```

**Request Body**

```json
{
  "on": true
}
```

### 4. Dose Nutrient A

Triggers a nutrient A dosing action.

**Request**

```http
POST /control/nutrient/a
Content-Type: application/json
```

**Request Body**

```json
{
  "dose": true
}
```

### 5. Dose Nutrient B

Triggers a nutrient B dosing action.

**Request**

```http
POST /control/nutrient/b
Content-Type: application/json
```

**Request Body**

```json
{
  "dose": true
}
```

### 6. Configure WiFi

Sends WiFi credentials to the ESP32 while it is in AP mode.

**Request**

```http
POST /wifi
Content-Type: application/json
```

**Full URL**

```http
POST http://192.168.4.1/wifi
```

**Request Body**

```json
{
  "ssid": "YourWiFiName",
  "password": "YourPassword"
}
```

## Status Codes

The current Flutter app treats any `2xx` response as success.

Recommended behavior for the ESP32:

- `200 OK` for successful reads
- `200 OK` or `204 No Content` for successful control commands
- `400 Bad Request` for invalid JSON or missing fields
- `500 Internal Server Error` for unexpected device errors

## App Settings Stored Locally

The app stores these values locally:

- `deviceIp`
- `mqttBrokerIp`
- `topicPrefix`
- `refreshInterval`

Default values currently used by the app:

```json
{
  "deviceIp": "192.168.4.1",
  "mqttBrokerIp": "",
  "topicPrefix": "hydro",
  "refreshInterval": 5
}
```

## MQTT Notes

MQTT is not the active runtime transport yet.

The app currently stores MQTT-related settings for future use:

- `mqttBrokerIp`
- `topicPrefix`

Suggested future topic names:

- `hydro/ph`
- `hydro/ec`
- `hydro/temp`
- `hydro/waterlevel`
- `hydro/pump`
- `hydro/light`
- `hydro/nutrient/a`
- `hydro/nutrient/b`

## Current Implementation References

The Flutter code that uses this contract is here:

- [`/Users/yoyojun/Documents/GitHub/HydroPilot/app/lib/app/services/hydro_api_service.dart`](/Users/yoyojun/Documents/GitHub/HydroPilot/app/lib/app/services/hydro_api_service.dart)
- [`/Users/yoyojun/Documents/GitHub/HydroPilot/app/lib/app/models/app_settings.dart`](/Users/yoyojun/Documents/GitHub/HydroPilot/app/lib/app/models/app_settings.dart)
- [`/Users/yoyojun/Documents/GitHub/HydroPilot/app/lib/app/modules/home/controllers/home_controller.dart`](/Users/yoyojun/Documents/GitHub/HydroPilot/app/lib/app/modules/home/controllers/home_controller.dart)

## Important Note

This document reflects the API shape the app currently expects.

If your ESP32 firmware uses a different route structure or different JSON fields, either:

1. update the firmware to match this document, or
2. update the Flutter API service to match the firmware

For beginner-friendly progress, matching the firmware to this document is the simpler next step.
