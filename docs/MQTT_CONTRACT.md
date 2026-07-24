# HydroPilot MQTT Contract

This contract describes the remote runtime path:

```text
Flutter app -> HydroPilot backend -> MQTT broker <- ESP32 firmware
```

The backend exposes HTTPS/JSON/SSE to the app. MQTT stays between the backend,
broker, and ESP32.

## Environment

Backend environment:

```env
MQTT_BROKER_URL=mqtts://your-broker-host:8883
MQTT_USERNAME=your-user
MQTT_PASSWORD=your-password
HYDRO_TOPIC_PREFIX=hydro
HYDRO_DEVICE_ID=device-1
```

The current ESP32 firmware in `/Users/yoyojun/Documents/GitHub/hydroponic_system`
publishes legacy topics rooted at `hydro/...`. The backend should accept both
the device-scoped topic family and those legacy topics during migration.

## Device-Scoped Topics

Preferred long-term topic root:

```text
<prefix>/device/<deviceId>
```

Telemetry/status topics:

```text
<prefix>/device/<deviceId>/availability
<prefix>/device/<deviceId>/alarm
<prefix>/device/<deviceId>/telemetry/ph
<prefix>/device/<deviceId>/telemetry/ec
<prefix>/device/<deviceId>/telemetry/temp
<prefix>/device/<deviceId>/telemetry/humidity
<prefix>/device/<deviceId>/telemetry/waterlevel
<prefix>/device/<deviceId>/telemetry/distance
<prefix>/device/<deviceId>/telemetry/tds
<prefix>/device/<deviceId>/state/pump
<prefix>/device/<deviceId>/state/light
<prefix>/device/<deviceId>/state/nutrient/a
<prefix>/device/<deviceId>/state/nutrient/b
<prefix>/device/<deviceId>/state/prime/a
<prefix>/device/<deviceId>/state/prime/b
<prefix>/device/<deviceId>/state/target-dose/a
<prefix>/device/<deviceId>/state/target-dose/b
<prefix>/device/<deviceId>/state/target-dose/ab
<prefix>/device/<deviceId>/state/shot-dose/a
<prefix>/device/<deviceId>/state/shot-dose/b
<prefix>/device/<deviceId>/state/liquid/a
<prefix>/device/<deviceId>/state/liquid/b
<prefix>/device/<deviceId>/ec-history
```

Command topics:

```text
<prefix>/device/<deviceId>/cmd/pump
<prefix>/device/<deviceId>/cmd/light
<prefix>/device/<deviceId>/cmd/nutrient/a
<prefix>/device/<deviceId>/cmd/nutrient/b
<prefix>/device/<deviceId>/cmd/prime/a
<prefix>/device/<deviceId>/cmd/prime/b
<prefix>/device/<deviceId>/cmd/target-dose/a
<prefix>/device/<deviceId>/cmd/target-dose/b
<prefix>/device/<deviceId>/cmd/target-dose/ab
<prefix>/device/<deviceId>/cmd/shot-dose/a
<prefix>/device/<deviceId>/cmd/shot-dose/b
```

Command payloads include a backend-generated `requestId`:

```json
{
  "requestId": "uuid",
  "ts": "2026-07-24T14:00:00.000Z",
  "source": "hydropilot-backend",
  "target": true
}
```

Target-dose commands use:

```json
{
  "requestId": "uuid",
  "ts": "2026-07-24T14:00:00.000Z",
  "source": "hydropilot-backend",
  "action": "toggle",
  "concentration": 1.4
}
```

## Legacy ESP32 Topics

The external ESP32 firmware currently publishes:

```text
hydro/sensor/temperature
hydro/sensor/humidity
hydro/sensor/water_level
hydro/sensor/distance
hydro/sensor/ec
hydro/sensor/tds
hydro/sensor/liquid1
hydro/sensor/liquid2
hydro/status
hydro/state/pump
hydro/state/light
hydro/state/fert_a
hydro/state/fert_b
```

During migration, the backend should subscribe to these and map them into the
same snapshot returned by `GET /api/device/status`.

Recommended legacy command topics for the firmware plan:

```text
hydro/cmd/light
hydro/cmd/prime_a
hydro/cmd/prime_b
hydro/cmd/target_dose_a
hydro/cmd/target_dose_b
hydro/cmd/target_dose_ab
hydro/cmd/shot_dose_a
hydro/cmd/shot_dose_b
```

The command payload should accept the backend command JSON above. The firmware
should run the same behavior used by its local `/api/toggle` handler.

## Backend HTTP Surface

App-facing remote endpoints:

```text
GET  /api/health
GET  /api/device
GET  /api/device/status
GET  /api/device/events
GET  /api/device/ec-history
POST /api/device/commands/pump
POST /api/device/commands/light
POST /api/device/commands/nutrient/a
POST /api/device/commands/nutrient/b
POST /api/device/commands/prime/a
POST /api/device/commands/prime/b
POST /api/device/commands/target-dose/a
POST /api/device/commands/target-dose/b
POST /api/device/commands/target-dose/ab
POST /api/device/commands/shot-dose/a
POST /api/device/commands/shot-dose/b
```

SSE events:

```text
snapshot
availability
telemetry
state
alarm
broker-status
command-result
ec-history
```

