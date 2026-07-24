# HydroPilot System Overview Report

## Executive Summary

HydroPilot is a three-part hydroponic monitoring and control system:

- a Flutter mobile app for setup, monitoring, and manual control
- a Node.js backend that exposes an app-friendly HTTP and SSE API
- an ESP32 firmware runtime that manages local provisioning, MQTT connectivity, device state, and simulated actuators/telemetry

The implemented architecture is backend-mediated during normal runtime:

```text
Mobile App -> Backend HTTP/SSE -> MQTT broker <- ESP32 firmware
```

The firmware also exposes a direct local HTTP interface for setup and maintenance:

```text
Mobile App -> ESP32 AP/LAN HTTP server
```

This gives the system two operating paths:

- local provisioning and maintenance through direct ESP32 REST endpoints
- normal runtime control and live updates through the backend and MQTT bridge

## 1. Backend Overview

### Purpose

The backend is the app-facing gateway. It hides MQTT details from the mobile app and converts device MQTT traffic into a simpler HTTP + SSE contract.

### Technology and Structure

- Runtime: Node.js 20+
- Framework: Express 5
- Messaging: `mqtt`
- Main entry: `backend/src/server.js`
- App assembly: `backend/src/app.js`

Key modules:

- `config/env.js`: loads required environment variables such as broker URL, credentials, device ID, topic prefix, and staleness thresholds
- `controllers/device.controller.js`: validates app requests and exposes device routes
- `services/device-service.js`: central application service for status, command publishing, and event fan-out
- `services/snapshot-store.js`: in-memory source for the latest device snapshot
- `services/event-stream.js`: SSE client subscription and broadcast
- `services/command-service.js`: request tracking so commands are accepted immediately and completed later when the device confirms state
- `lib/mqtt-gateway.js`: maps MQTT topics, subscribes to device topics, parses payloads, and forwards updates into the service layer

### External Interface

The backend exposes these app-facing endpoints:

- `GET /api/health`
- `GET /api/device`
- `GET /api/device/status`
- `GET /api/device/events`
- `POST /api/device/commands/pump`
- `POST /api/device/commands/light`
- `POST /api/device/commands/nutrient/a`
- `POST /api/device/commands/nutrient/b`

The runtime model is:

- HTTP fetch for current snapshot
- SSE stream for live updates
- HTTP command submission returning `202 accepted`
- later command completion signaled through SSE after MQTT state confirmation

### Data Handling

The backend subscribes to MQTT topics for:

- availability
- alarms
- pump/light state
- pH, EC, temperature, and water-level telemetry

It converts those messages into:

- an in-memory snapshot returned by `GET /api/device/status`
- SSE events named `snapshot`, `availability`, `telemetry`, `state`, `alarm`, `broker-status`, and `command-result`

### Strengths

- Keeps the mobile app decoupled from MQTT details
- Normalizes inconsistent device payload formats through tolerant parsing
- Tracks command lifecycle explicitly instead of assuming optimistic success
- Separates transport, state storage, and API concerns cleanly

### Current Constraints

- State is in memory only; restarting the backend loses the live snapshot and pending command state
- The backend appears designed for a single configured device ID per process
- There is no persistent database, authentication layer, or multi-tenant device registry yet

## 2. App Overview

### Purpose

The Flutter app is the user-facing control surface. It supports first-time WiFi provisioning, backend configuration, live dashboard status, and manual actuator commands.

### Technology and Structure

- Framework: Flutter
- State/navigation: GetX
- Local storage: GetStorage
- Networking: `http`
- Main entry: `app/lib/main.dart`

Key app modules:

- `app/services/hydro_api_service.dart`: backend and local-device HTTP client plus SSE stream parser
- `app/services/device_provisioning_service.dart`: Android-specific WiFi connection flow for ESP32 AP onboarding
- `app/services/settings_service.dart`: persisted app settings, including backend base URL
- `app/modules/home/controllers/home_controller.dart`: orchestration layer for status loading, SSE reconnects, command dispatch, and setup flows
- `app/modules/home/views/*`: dashboard, settings, and WiFi setup UI
- `app/models/*`: sensor, state, runtime, and settings models

### Runtime Responsibilities

The app uses the backend as the primary runtime transport:

- `GET /api/device/status` for initial snapshot
- `GET /api/device/events` for SSE updates
- `POST /api/device/commands/...` for manual controls

The app talks directly to the ESP32 only for local setup and maintenance:

- `POST http://192.168.4.1/wifi` during AP provisioning
- optional local checks such as `/health`, `/config`, and `/debug/status`

### User-Facing Behavior

The app currently supports:

- dashboard display of pH, EC, water temperature, water level, pump state, and grow-light state
- manual control for pump, light, nutrient A, and nutrient B
- backend URL configuration
- Android-first provisioning by joining the ESP32 access point and sending home WiFi credentials
- runtime health messaging for backend reachability, stream connection, and stale data

### State Model

The app tracks three major data groups:

- `SensorData`: pH, EC, water temperature, water level
- `DeviceState`: pump and light state
- `RuntimeStatus`: backend reachability, device online state, stream health, telemetry staleness, and state staleness

### Strengths

- Clear separation between onboarding flows and runtime control flows
- Backend-first runtime design reduces mobile MQTT complexity
- Controller logic explicitly handles pending commands and stream reconnection
- Tests exist for services, controllers, WiFi setup, and settings flows

### Current Constraints and Observations

- The package still declares `mqtt_client`, but the current runtime implementation is HTTP + SSE driven rather than app-side MQTT
- The app is effectively Android-first; provisioning support is intentionally platform-limited
- The backend base URL is user-configured and appears to be the key environment dependency for normal operation

## 3. Firmware Overview

### Purpose

The firmware is the device-side runtime for HydroPilot. It owns provisioning, local configuration, MQTT connectivity, authoritative device state, and simulated actuator/telemetry behavior.

### Technology and Structure

- Platform: ESP-IDF
- Target area: ESP32
- Persistence: NVS
- Local interface: ESP-IDF HTTP server
- Remote interface: MQTT over TLS

Main modules:

- `main/src/main.c`: boot flow and mode transitions
- `main/src/config_store.c`: persisted configuration in NVS
- `main/src/app_state.c`: authoritative in-memory runtime snapshot
- `main/src/http_server_local.c`: local maintenance and provisioning REST API
- `main/src/wifi_ap.c`: SoftAP mode
- `main/src/wifi_manager.c`: station-mode connection management
- `main/src/mqtt_runtime.c`: secure MQTT client, subscriptions, publishes, and command handling
- `main/src/actuator_sim.c`: LED-based simulation of pump, light, and nutrient dosing
- `main/src/telemetry_sim.c`: deterministic simulated telemetry generation

### Boot and Mode Flow

The firmware has three main modes:

1. Unprovisioned boot
   The device starts SoftAP mode and exposes `POST /wifi` at `192.168.4.1`.
2. Provisioned runtime
   The device joins the configured WiFi network, starts a local maintenance server, and connects to the MQTT broker.
3. WiFi failure fallback
   If station-mode connection fails repeatedly, the device stops MQTT and returns to AP maintenance mode.

### Local HTTP Interface

The firmware exposes local endpoints for provisioning and maintenance:

- `POST /wifi`
- `GET /health`
- `GET /config`
- `PUT /config`
- `GET /status`
- `GET /debug/status`
- `POST /control/pump`
- `POST /control/light`
- `POST /control/nutrient/a`
- `POST /control/nutrient/b`

These endpoints support setup, diagnostics, and local control without requiring the backend.

### MQTT Responsibilities

The firmware:

- connects to the broker over `mqtts://`
- subscribes to command topics for pump, light, nutrient A, and nutrient B
- publishes availability
- publishes state confirmations
- publishes telemetry samples

The device is the authoritative source of truth for actual actuator state. Commands are not considered complete until device state is published back out.

### Hardware Model

The current firmware is a simulator-oriented architecture, not final hardware integration:

- pump state is represented by one LED
- light state is represented by one LED
- nutrient A/B actions are simulated using pulse sequences
- telemetry values are generated deterministically in software

This is useful because networking, config, and control-path integration can be validated before real sensors and relays are wired in.

### Strengths

- Good separation between configuration, runtime state, transport, and simulated hardware
- Clear AP-to-STA transition design for provisioning
- TLS-enabled MQTT configuration is already in place
- Local maintenance API remains available even when the broker is not the active control path

### Current Constraints

- The firmware still simulates hardware behavior rather than reading real probes or driving real pumps/lights
- Configuration is local-device scoped; fleet management and remote config orchestration are not implemented
- Topic and payload contracts need to stay tightly aligned with backend parsing to avoid integration drift

## 4. System Integration Summary

### End-to-End Runtime Path

Normal remote-capable operation works as follows:

1. The app loads the latest snapshot from the backend.
2. The app opens an SSE stream to receive live updates.
3. The backend listens to MQTT topics for the configured device.
4. The firmware publishes telemetry, availability, and state to MQTT.
5. When the user sends a command, the app posts to the backend.
6. The backend publishes the command to MQTT and marks it pending.
7. The firmware executes the command and publishes resulting state.
8. The backend updates its snapshot and emits an SSE confirmation.
9. The app clears pending UI state once confirmation arrives.

### Provisioning Path

First-time setup works differently:

1. The ESP32 boots in AP mode when WiFi credentials are absent.
2. The app joins the controller access point.
3. The app sends SSID and password to `POST /wifi`.
4. The firmware stores credentials and switches toward station mode.
5. Once connected to the LAN and broker, the backend-mediated runtime path becomes available.

## 5. Key Architectural Notes

### What Is Already Well Aligned

- The backend and firmware agree on an MQTT topic family rooted at `hydro/device/<deviceId>/...`
- The app is already adapted to consume backend snapshots and SSE events instead of direct runtime MQTT
- The firmware local API and app onboarding flow are aligned around `POST /wifi`

### Notable Mismatches or Evolution Signals

- `docs/PLAN.md` describes an earlier architecture direction where the app would use MQTT directly and backend work was out of scope, but the current implementation has moved to a backend-mediated runtime model
- The Flutter app still includes an MQTT dependency even though the active runtime path is HTTP + SSE
- The backend focuses on a subset of firmware-published state; future additions such as nutrient result handling or richer alarms may need explicit backend support

## 6. Recommended Next Steps

- Decide whether the backend-mediated architecture is now the canonical design and update older planning docs accordingly
- Remove or justify unused app-side MQTT dependencies if they are no longer part of the runtime direction
- Add a persistent store in the backend if command history, alarms, or multi-device support matter
- Formalize a single source of truth for topic and payload contracts to reduce drift between backend and firmware
- Replace simulator modules in firmware incrementally with real sensor and actuator drivers while keeping the current interfaces stable
