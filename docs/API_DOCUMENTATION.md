# HydroPilot API Documentation

This document describes HydroPilot's intended hybrid transport design and the local REST endpoints already expected by the Flutter app in [`/Users/yoyojun/Documents/GitHub/HydroPilot/app`](/Users/yoyojun/Documents/GitHub/HydroPilot/app).

## Transport Overview

HydroPilot uses two communication paths for different jobs:

- **Local REST**
  Used for AP onboarding, local service/config, and local debug while the phone is on the same LAN or connected to the ESP32 access point.
- **Remote MQTT**
  Used for remote commands, state synchronization, alarms, and telemetry without exposing the ESP32 directly to the public internet.

This means:

- the app does **not** use `localhost` to talk to the ESP32
- the app talks to the ESP32's **local IP** for REST
- the app and ESP32 both connect outward to an MQTT broker for remote runtime

## Network Paths

### 1. Local AP Onboarding

Used when the ESP32 starts in access-point mode for first setup.

```text
Phone App -> ESP32 AP WiFi -> ESP32 HTTP server
```

Typical address:

```text
http://192.168.4.1
```

### 2. Local Service / Maintenance Mode

Used when the phone and ESP32 are on the same LAN.

```text
Phone App -> Local WiFi Router -> ESP32 HTTP server
```

Typical address:

```text
http://192.168.1.50
```

### 3. Remote Runtime Mode

Used for remote control and live updates.

```text
Phone App -> MQTT Broker <- ESP32
```

The ESP32 is **not** exposed to the public internet with direct REST in this design.

## Local REST API

The REST API is the **local admin/service interface**.

Recommended responsibilities:

- WiFi onboarding
- local configuration
- calibration
- local health/debug inspection
- optional local status fetch for diagnostics

### Base URLs

#### ESP32 AP Mode

```text
http://192.168.4.1
```

#### ESP32 Local LAN Mode

```text
http://<device-ip>
```

Example:

```text
http://192.168.1.50
```

## Local REST Endpoints

### 1. Configure WiFi

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

### 2. Get Local Status

Reads hydroponic sensor values and device states from the local device.

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

**Accepted field name variants in the current Flutter app**

- `waterTemperature`, `water_temperature`, `temp`, `temperature`
- `waterLevel`, `water_level`, `level`
- `pumpOn`, `pump_on`, `pump`
- `lightOn`, `light_on`, `light`

**Accepted boolean formats in the current Flutter app**

- `true` / `false`
- `1` / `0`
- `"true"` / `"false"`
- `"on"` / `"off"`
- `"1"` / `"0"`

### 3. Control Pump

Local maintenance command for pump state.

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

### 4. Control Grow Light

Local maintenance command for grow light state.

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

### 5. Dose Nutrient A

Local maintenance command for nutrient A dosing.

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

### 6. Dose Nutrient B

Local maintenance command for nutrient B dosing.

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

### 7. Recommended Local Service Endpoints

These are not fully implemented in the Flutter app yet, but they fit the agreed architecture and should be added on the ESP32 side for service workflows:

- `GET /config`
- `PUT /config`
- `GET /health`
- `GET /debug/status`

Recommended use:

- `GET /config`: read saved network/device settings
- `PUT /config`: update non-runtime config
- `GET /health`: basic health and uptime
- `GET /debug/status`: sensor/debug view for troubleshooting

## Remote MQTT Contract

MQTT is the **operational runtime interface**.

Recommended responsibilities:

- remote commands
- device state sync
- alarms
- live telemetry
- availability / online-offline state

### Topic Structure

Use a per-device namespace:

```text
hydro/device/<deviceId>/...
```

Recommended topics:

- `hydro/device/<deviceId>/cmd/pump`
- `hydro/device/<deviceId>/cmd/light`
- `hydro/device/<deviceId>/cmd/nutrient/a`
- `hydro/device/<deviceId>/cmd/nutrient/b`
- `hydro/device/<deviceId>/state/pump`
- `hydro/device/<deviceId>/state/light`
- `hydro/device/<deviceId>/telemetry/ph`
- `hydro/device/<deviceId>/telemetry/ec`
- `hydro/device/<deviceId>/telemetry/temp`
- `hydro/device/<deviceId>/telemetry/waterlevel`
- `hydro/device/<deviceId>/alarm`
- `hydro/device/<deviceId>/availability`

### Command Payload

Recommended command payload shape:

```json
{
  "requestId": "abc-123",
  "target": true,
  "ts": 1710000000,
  "source": "mobile-app"
}
```

For nutrient dosing:

```json
{
  "requestId": "dose-123",
  "action": "dose",
  "ts": 1710000000,
  "source": "mobile-app"
}
```

### State / Ack Payload

Recommended device confirmation payload:

```json
{
  "requestId": "abc-123",
  "actual": true,
  "ok": true,
  "ts": 1710000001,
  "source": "device"
}
```

### Alarm Payload

Recommended alarm payload:

```json
{
  "type": "low_water",
  "severity": "critical",
  "message": "Water level below threshold",
  "ts": 1710000002
}
```

### Availability Payload

Recommended availability values:

- `online`
- `offline`

### Publish Timing

Recommended policy:

- publish immediately on change for:
  - pump state
  - grow light state
  - alarms
- publish on interval for analog telemetry:
  - water level: `1-2s` if critical, otherwise `2-5s`
  - pH: `10-30s`
  - EC: `10-30s`
  - water temperature: `10-30s`

## Command Confirmation Rule

HydroPilot should follow this rule:

1. app sends command
2. device executes command
3. device publishes actual resulting state
4. app treats device-confirmed state as truth

The app should not treat a command as fully successful just because it sent it.

## Status Codes for Local REST

The current Flutter app treats any `2xx` response as success.

Recommended behavior for the ESP32:

- `200 OK` for successful reads
- `200 OK` or `204 No Content` for successful control/config commands
- `400 Bad Request` for invalid JSON or missing fields
- `500 Internal Server Error` for unexpected device errors

## App Settings Stored Locally

The Flutter app currently stores:

- `deviceIp`
- `mqttBrokerIp`
- `topicPrefix`
- `refreshInterval`

Default values in the current Flutter app:

```json
{
  "deviceIp": "192.168.4.1",
  "mqttBrokerIp": "",
  "topicPrefix": "hydro",
  "refreshInterval": 5
}
```

For the target hybrid design, additional settings should eventually include:

- `deviceId`
- broker port
- broker username/token
- local-vs-remote mode behavior

## Current Flutter Implementation Status

Current app code already implements local REST calls in:

- [`/Users/yoyojun/Documents/GitHub/HydroPilot/app/lib/app/services/hydro_api_service.dart`](/Users/yoyojun/Documents/GitHub/HydroPilot/app/lib/app/services/hydro_api_service.dart)
- [`/Users/yoyojun/Documents/GitHub/HydroPilot/app/lib/app/models/app_settings.dart`](/Users/yoyojun/Documents/GitHub/HydroPilot/app/lib/app/models/app_settings.dart)
- [`/Users/yoyojun/Documents/GitHub/HydroPilot/app/lib/app/modules/home/controllers/home_controller.dart`](/Users/yoyojun/Documents/GitHub/HydroPilot/app/lib/app/modules/home/controllers/home_controller.dart)

MQTT runtime support is currently a planned architecture direction, not a completed app implementation.

## Important Notes

- Local REST means the phone talks directly to the ESP32 local IP.
- `localhost` is not used to talk to the ESP32.
- Remote runtime should use MQTT, not direct public REST to the ESP32.
- If the firmware and app differ, either the firmware must match this document or the app transport layer must be updated to match the firmware.
