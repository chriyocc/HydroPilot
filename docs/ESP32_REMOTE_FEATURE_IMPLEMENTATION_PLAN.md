# ESP32 Remote Feature Implementation Plan

This plan targets the ESP32 firmware in:

```text
/Users/yoyojun/Documents/GitHub/hydroponic_system
```

The firmware already exposes the new local API used by the Flutter app:

```text
GET  /api/status
GET  /api/ec_history
POST /api/toggle?device=...
```

It also publishes sensor/state MQTT topics, but it does not yet subscribe to
remote command topics. The next firmware task is to make MQTT commands execute
the same routines as `/api/toggle`.

## Current Local Controls

The local toggle dispatcher supports:

```text
light
prime_a
prime_b
target_dose_a
target_dose_b
target_dose_ab
shot_dose_a
shot_dose_b
```

Target-dose commands optionally include:

```text
concentration=<mS/cm>
```

## Required MQTT Work

1. Subscribe when MQTT connects:

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

2. Parse JSON payloads from the backend:

```json
{
  "requestId": "uuid",
  "source": "hydropilot-backend",
  "action": "toggle",
  "concentration": 1.4
}
```

3. Dispatch MQTT commands through the same code path as `hydro_web_toggle`.

4. Publish updated state/status after command execution so the backend SSE
   stream can confirm the command.

5. Include `requestId` in state/result publishes when available. This lets the
   backend clear pending command spinners immediately instead of waiting for a
   timeout.

## Suggested Firmware Refactor

Create a shared command entry point:

```c
void hydro_execute_device_command(const char *device,
                                  float concentration,
                                  const char *request_id);
```

Then call it from:

- `hydro_web_toggle(...)`
- MQTT message handler

This prevents local and remote behavior from drifting.

## Suggested State Topics

Short-term compatibility topics:

```text
hydro/status
hydro/state/light
hydro/state/prime_a
hydro/state/prime_b
hydro/state/target_dose_a
hydro/state/target_dose_b
hydro/state/target_dose_ab
hydro/state/shot_dose_a
hydro/state/shot_dose_b
```

Long-term preferred topics:

```text
hydro/device/device-1/state/light
hydro/device/device-1/state/prime/a
hydro/device/device-1/state/prime/b
hydro/device/device-1/state/target-dose/a
hydro/device/device-1/state/target-dose/b
hydro/device/device-1/state/target-dose/ab
hydro/device/device-1/state/shot-dose/a
hydro/device/device-1/state/shot-dose/b
```

## Manual Verification

After flashing firmware:

```bash
mosquitto_pub -h <broker> -t hydro/cmd/shot_dose_a \
  -m '{"requestId":"manual-1","action":"toggle"}'

mosquitto_sub -h <broker> -t 'hydro/#' -v
```

Expected:

- ESP32 runs the requested routine.
- `hydro/status` updates.
- A matching state/result topic is published.
- Backend `/api/device/status` updates.
- Flutter app receives an SSE update in Real Server mode.

