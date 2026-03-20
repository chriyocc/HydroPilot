# HydroPilot Backend

This directory contains the HydroPilot app-facing backend gateway. It exposes a small HTTP + SSE API for the mobile app and bridges those requests to the device over MQTT.

## Structure

```text
backend/
  src/
    config/
    routes/
    controllers/
    services/
    middleware/
    lib/
  test/
```

## Runtime Model

Remote operation is:

```text
App -> Backend -> MQTT broker <- Device
```

The backend keeps:

- an in-memory device snapshot for `GET /api/device/status`
- a live SSE stream for delta events
- pending command tracking with `accepted` over HTTP and completion over SSE

## Required Environment

Copy `.env.example` and set:

- `MQTT_BROKER_URL`
- `MQTT_USERNAME`
- `MQTT_PASSWORD`
- `HYDRO_DEVICE_ID`

Optional:

- `PORT`
- `NODE_ENV`
- `HYDRO_TOPIC_PREFIX`
- `COMMAND_TIMEOUT_MS`
- `TELEMETRY_STALE_MS`
- `STATE_STALE_MS`

## Run

```bash
npm install
npm run dev
```

## App-Facing API

- `GET /api/health`
- `GET /api/device`
- `GET /api/device/status`
- `GET /api/device/events`
- `POST /api/device/commands/pump`
- `POST /api/device/commands/light`
- `POST /api/device/commands/nutrient/a`
- `POST /api/device/commands/nutrient/b`

## SSE Events

The SSE stream sends:

- `snapshot` immediately on connect
- `availability`
- `telemetry`
- `state`
- `alarm`
- `broker-status`
- `command-result`
