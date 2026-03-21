# ESP-IDF HydroPilot Firmware Simulator

This directory now contains the ESP-IDF firmware skeleton for HydroPilot. It is intentionally shaped like the real product architecture, but it uses LEDs and deterministic mock telemetry instead of physical relays, pumps, lights, pH probes, EC probes, or water-level sensors.

The goal is to give teammates a clean integration base:
- keep WiFi, HTTP, MQTT, config persistence, and device state flow in place
- keep the simulated hardware isolated in a small layer
- let future hardware integration replace only the simulator modules

## What It Does Today

- boots into AP mode when WiFi credentials are missing
- accepts WiFi provisioning at `POST /wifi`
- saves config in NVS
- switches to station mode when provisioned
- starts a local maintenance HTTP server
- connects to MQTT and publishes simulated telemetry/state
- uses two LEDs to simulate:
  - pump state
  - grow light state
- simulates nutrient dosing as short LED pulse patterns

## Module Architecture

Main runtime modules:

- [`main/src/main.c`](/Users/yoyojun/Documents/GitHub/HydroPilot/firmware/esp32/main/src/main.c)
  Orchestrates boot, mode transitions, and long-running state checks.
- [`main/src/config_store.c`](/Users/yoyojun/Documents/GitHub/HydroPilot/firmware/esp32/main/src/config_store.c)
  Loads and saves persisted config in NVS, with Kconfig defaults for first flash.
- [`main/src/app_state.c`](/Users/yoyojun/Documents/GitHub/HydroPilot/firmware/esp32/main/src/app_state.c)
  Holds the authoritative in-memory snapshot used by REST and MQTT.
- [`main/src/http_server_local.c`](/Users/yoyojun/Documents/GitHub/HydroPilot/firmware/esp32/main/src/http_server_local.c)
  Exposes local maintenance endpoints on AP or LAN.
- [`main/src/mqtt_runtime.c`](/Users/yoyojun/Documents/GitHub/HydroPilot/firmware/esp32/main/src/mqtt_runtime.c)
  Manages MQTT connection, subscriptions, and publishing.
- [`main/src/actuator_sim.c`](/Users/yoyojun/Documents/GitHub/HydroPilot/firmware/esp32/main/src/actuator_sim.c)
  Simulates pump/light/nutrient behavior using LEDs.
- [`main/src/telemetry_sim.c`](/Users/yoyojun/Documents/GitHub/HydroPilot/firmware/esp32/main/src/telemetry_sim.c)
  Generates deterministic mock telemetry values.

## Boot Modes

### 1. Unprovisioned Boot

- NVS loads with no WiFi SSID
- device enters SoftAP mode
- local maintenance HTTP server starts
- app or tester can hit `http://192.168.4.1/wifi`

### 2. Provisioned Boot

- NVS contains WiFi credentials
- device starts STA mode
- after getting an IP, local maintenance HTTP server is reachable on LAN
- MQTT runtime starts and publishes availability, state, and telemetry

### 3. WiFi Failure Fallback

- if STA retries are exhausted
- MQTT runtime is stopped
- device falls back to AP maintenance mode
- local provisioning/debug can continue without broker access

## LED Mapping

This firmware assumes two simulated actuator outputs:

- pump LED = persistent pump state
- light LED = persistent grow-light state
- nutrient A = short pulse sequence on the pump LED, then restore pump state
- nutrient B = short pulse sequence on the light LED, then restore light state

If your board only has one onboard LED, attach a second external LED for the light simulation.

## Local REST Endpoints

These endpoints are for setup and maintenance only.

### `POST /wifi`

Saves WiFi credentials and requests a transition out of AP mode.

```json
{
  "ssid": "OfficeWiFi",
  "password": "secret123"
}
```

### `GET /health`

Returns basic runtime state.

Example response:

```json
{
  "mode": "runtime",
  "deviceId": "device-1",
  "wifiConnected": true,
  "mqttConnected": true,
  "uptimeMs": 123456
}
```

### `GET /config`

Returns sanitized config. Password values are not echoed back directly.

### `PUT /config`

Updates editable config such as:
- `deviceId`
- `mqttHost`
- `mqttPort`
- `mqttUsername`
- `mqttPassword`
- `topicPrefix`

### `GET /status`

App-friendly local snapshot:

```json
{
  "ph": 6.25,
  "ec": 1.82,
  "waterTemperature": 24.4,
  "waterLevel": 81.4,
  "pumpOn": true,
  "lightOn": false
}
```

### `GET /debug/status`

Verbose local inspection including mode, connectivity, telemetry, and simulated actuator state.

### Local Control Endpoints

- `POST /control/pump`
- `POST /control/light`
- `POST /control/nutrient/a`
- `POST /control/nutrient/b`

Pump/light example:

```json
{
  "on": true
}
```

Nutrient example:

```json
{
  "dose": true
}
```

## MQTT Topics

Base namespace:

```text
hydro/device/<deviceId>/...
```

Subscribed command topics:

- `hydro/device/<deviceId>/cmd/pump`
- `hydro/device/<deviceId>/cmd/light`
- `hydro/device/<deviceId>/cmd/nutrient/a`
- `hydro/device/<deviceId>/cmd/nutrient/b`

Published topics:

- `hydro/device/<deviceId>/availability`
- `hydro/device/<deviceId>/state/pump`
- `hydro/device/<deviceId>/state/light`
- `hydro/device/<deviceId>/state/nutrient/a`
- `hydro/device/<deviceId>/state/nutrient/b`
- `hydro/device/<deviceId>/telemetry/ph`
- `hydro/device/<deviceId>/telemetry/ec`
- `hydro/device/<deviceId>/telemetry/temp`
- `hydro/device/<deviceId>/telemetry/waterlevel`

Pump/light confirmation payload shape:

```json
{
  "requestId": "abc-123",
  "on": true,
  "actual": true,
  "ok": true,
  "ts": 123456789,
  "source": "device"
}
```

Telemetry payload shape:

```json
{
  "value": 6.25,
  "ts": 123456789
}
```

## MQTT Security

The firmware now uses TLS for MQTT broker connections.

- broker URI scheme: `mqtts://`
- broker verification: ESP-IDF certificate bundle via `esp_crt_bundle_attach`
- intended target: secure brokers such as HiveMQ Cloud on port `8883`

If your broker is TLS-only, keep the port at `8883` and ensure the configured hostname matches the broker certificate.

## Build, Flash, Monitor

Run these in a correctly configured ESP-IDF shell:

```bash
idf.py set-target esp32s3
idf.py menuconfig
idf.py build
idf.py -p /dev/tty.usbmodemXXXX flash monitor
```

Important menuconfig values:
- `PUMP_LED_GPIO`
- `LIGHT_LED_GPIO`
- `WIFI_AP_SSID`
- `WIFI_AP_PASS`
- `MQTT_BROKER_HOST`
- `MQTT_BROKER_PORT`
- `MQTT_USERNAME`
- `MQTT_PASSWORD`
- `HYDRO_DEVICE_ID`
- `HYDRO_TOPIC_PREFIX`

NVS overrides Kconfig after local config has been saved.

## Test Without Real Hardware

Recommended order:

1. Flash the board with empty NVS.
2. Confirm the AP comes up.
3. Send WiFi credentials:

```bash
curl -X POST http://192.168.4.1/wifi \
  -H 'Content-Type: application/json' \
  -d '{"ssid":"YourWifi","password":"YourPassword"}'
```

4. After the device joins WiFi, check health:

```bash
curl http://<device-lan-ip>/health
curl http://<device-lan-ip>/status
curl http://<device-lan-ip>/debug/status
```

5. Toggle simulated actuators:

```bash
curl -X POST http://<device-lan-ip>/control/pump \
  -H 'Content-Type: application/json' \
  -d '{"on":true}'
```

6. Trigger nutrient pulse simulation:

```bash
curl -X POST http://<device-lan-ip>/control/nutrient/a \
  -H 'Content-Type: application/json' \
  -d '{"dose":true}'
```

7. Watch serial logs and MQTT topics to verify runtime flow.

## Integration Notes for Teammates

When real hardware arrives, replace these first:

- [`main/src/actuator_sim.c`](/Users/yoyojun/Documents/GitHub/HydroPilot/firmware/esp32/main/src/actuator_sim.c)
  Replace LED-backed actuator behavior with relay, transistor, or driver control.
- [`main/src/telemetry_sim.c`](/Users/yoyojun/Documents/GitHub/HydroPilot/firmware/esp32/main/src/telemetry_sim.c)
  Replace generated values with real ADC, I2C, UART, or sensor-driver reads.

Keep these layers intact unless architecture changes are intentional:

- config persistence
- local maintenance REST server
- WiFi mode transitions
- MQTT topic handling
- shared app/device state model

That separation is the main point of this firmware skeleton.
