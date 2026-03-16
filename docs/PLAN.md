# HydroPilot Remote-Capable Transport Plan

## Summary
Build HydroPilot as a hybrid system:
- Local REST on the ESP32 for onboarding, local service/config, and local debug
- Managed MQTT broker for remote commands, state sync, alarms, and telemetry
- Flutter app supports both paths, using REST only when it is on the same local network or in AP setup mode, and MQTT for normal remote operation

Defaults chosen:
- Scope: full system
- Remote transport: managed MQTT broker first
- Local transport: direct REST to ESP32 local IP
- No internet-facing direct REST to the ESP32
- Device remains the source of truth; commands are only considered successful after device state confirmation

## Key Changes

### 1. Define the transport contract
- Keep the current REST contract for local provisioning/service:
  - `POST /wifi`
  - `GET /status`
  - local config/debug endpoints such as `GET /config`, `PUT /config`, `GET /health`, `GET /debug/status`
- Add MQTT topic families with clear separation:
  - command topics: `hydro/cmd/...`
  - state topics: `hydro/state/...`
  - alarm topics: `hydro/alarm/...`
  - telemetry topics: `hydro/telemetry/...`
  - availability topic: `hydro/device/<deviceId>/availability`
- Standardize command payloads to include at minimum:
  - `requestId`
  - target value or action
  - timestamp
  - optional source/client identifier
- Standardize state/ack payloads to include at minimum:
  - `requestId` when responding to a command
  - actual resulting state
  - success flag / error code
  - timestamp

### 2. ESP32 firmware responsibilities
- Implement local HTTP server for AP onboarding and local maintenance mode
- Connect outbound to the managed MQTT broker after WiFi is configured
- Subscribe to remote command topics for:
  - pump
  - grow light
  - nutrient A
  - nutrient B
- Publish:
  - actual device state after every command
  - immediate alarms
  - telemetry on interval
  - online/offline availability
- Persist locally:
  - WiFi credentials
  - MQTT broker host/port
  - device ID
  - topic prefix / namespace
  - calibration and threshold settings
- Enforce command handling rules:
  - device executes command
  - device publishes confirmed resulting state
  - device does not rely on app-side optimistic state as truth

### 3. Flutter app responsibilities
- Keep existing REST services for local setup and local diagnostics
- Add MQTT client service and connection manager alongside the current REST service
- Expand settings to store:
  - managed broker host/port
  - username/password or token
  - device ID
  - topic prefix
  - local device IP
  - refresh/publish fallback intervals
- Runtime behavior:
  - use MQTT as primary live transport for remote mode
  - use local REST for AP setup and local service/config screens
  - treat MQTT state/alarm messages as authoritative live updates
  - optionally allow manual local REST refresh for diagnostics
- Update controller/state flow so:
  - commands publish to MQTT
  - pending commands wait for matching state/ack by `requestId`
  - UI shows timeout/failure if ack does not arrive
  - telemetry screens update from MQTT messages instead of REST polling in remote mode

### 4. Telemetry and timing policy
- Publish on change immediately for:
  - pump state
  - grow light state
  - alarms
- Publish on interval for analog telemetry:
  - water level: `1-2s` if operationally critical, otherwise `2-5s`
  - pH: `10-30s`
  - EC: `10-30s`
  - water temperature: `10-30s`
- Keep REST polling only as a local diagnostic fallback, not the primary remote runtime path

### 5. Security and deployment
- Use a managed broker with authenticated client connections
- Plan for per-device credentials or token-based auth instead of shared anonymous access
- Do not expose the ESP32 REST server directly to the public internet
- Keep local REST reachable only on LAN/AP mode
- Define device identity strategy early:
  - unique `deviceId`
  - topic namespace per device
  - app settings and firmware provisioning must agree on this value

## Important Interfaces / Public Contracts
- REST local API on ESP32:
  - `POST /wifi`
  - `GET /status`
  - `GET /config`
  - `PUT /config`
  - `GET /health`
  - `GET /debug/status`
- MQTT topic structure:
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
- App settings additions:
  - broker host/port
  - broker auth
  - device ID
  - topic prefix / namespace mode
  - local IP for service mode

## Test Plan
- Local provisioning:
  - app can send WiFi credentials to `192.168.4.1`
  - ESP32 saves config and transitions to normal WiFi mode
- MQTT connection:
  - app connects to managed broker
  - ESP32 connects to managed broker
  - both use the same device/topic namespace
- Command flow:
  - app publishes pump/light/nutrient command
  - ESP32 receives it
  - ESP32 publishes confirmed resulting state/ack
  - app updates UI only after confirmation or timeout
- Telemetry flow:
  - ESP32 publishes sensor values at the configured intervals
  - app dashboard updates without REST polling in remote mode
- Alarm flow:
  - low water / fault event publishes immediately
  - app displays alarm promptly
- Local service mode:
  - app can still read local debug/config endpoints on LAN
  - MQTT outage does not block local service access
- Failure scenarios:
  - broker unavailable
  - device offline
  - command ack timeout
  - malformed payload
  - stale retained state
  - app remote mode with no local IP reachability

## Assumptions
- Managed MQTT broker is the first remote deployment target; backend server work is out of scope for this phase
- The ESP32 firmware can support both a lightweight HTTP server and an MQTT client
- Flutter remains Android-first and keeps the current simple architecture
- MQTT is the primary runtime transport for remote operation; REST remains local-only
- Device commands require explicit state confirmation to count as successful
