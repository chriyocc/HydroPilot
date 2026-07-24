# Remote HydroPilot Feature Contract Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand HydroPilot Real Server mode so the app's newest local ESP32 controls can operate through the backend and MQTT.

**Architecture:** Keep Flutter HTTP/SSE-only in Real Server mode. Extend the backend snapshot, routes, and MQTT gateway to bridge both current backend device-scoped topics and the external ESP32 legacy topics. Document the firmware MQTT command subscription work separately because the ESP32 repo is outside this workspace.

**Tech Stack:** Flutter/Dart app, Node.js Express backend, MQTT.js, ESP-IDF C firmware.

---

## Chunk 1: Backend Contract

### Task 1: Expanded Snapshot Store

**Files:**
- Modify: `backend/src/services/snapshot-store.js`
- Test: `backend/test/device-routes.test.js`

- [ ] Add failing tests proving the backend snapshot includes humidity, TDS, distance, liquid A/B, prime, target-dose, shot-dose, nutrient state, target EC, and EC history fields.
- [ ] Run `cd backend && npm test -- test/device-routes.test.js` and verify the new tests fail.
- [ ] Extend the snapshot store's `sensors` and `deviceState` objects.
- [ ] Add `applyEcHistory`.
- [ ] Run backend tests and verify the new tests pass.

### Task 2: Expanded MQTT Gateway

**Files:**
- Modify: `backend/src/lib/mqtt-gateway.js`
- Test: `backend/test/mqtt-gateway.test.js`

- [ ] Add failing tests for subscribing to legacy ESP32 topics and parsing `hydro/status`.
- [ ] Add failing tests for device-scoped target/prime/shot topics.
- [ ] Implement topic maps and parsing.
- [ ] Run `cd backend && npm test -- test/mqtt-gateway.test.js`.

### Task 3: Expanded Backend Commands

**Files:**
- Modify: `backend/src/controllers/device.controller.js`
- Modify: `backend/src/routes/index.js`
- Modify: `backend/src/services/device-service.js`
- Test: `backend/test/device-routes.test.js`

- [ ] Add failing route tests for prime A/B, target-dose A/B/A+B, shot-dose A/B, and EC history.
- [ ] Implement validators for toggle and target-dose commands.
- [ ] Publish to MQTT topics from `createTopicMap`.
- [ ] Run backend route tests.

## Chunk 2: Flutter App Wiring

### Task 4: Remote App API Methods

**Files:**
- Modify: `app/lib/app/services/hydro_api_service.dart`
- Modify: `app/lib/app/modules/home/controllers/home_controller.dart`
- Test: `app/test/hydro_api_service_test.dart`
- Test: `app/test/home_controller_test.dart`

- [ ] Add failing Dart tests for remote prime, target-dose, shot-dose methods.
- [ ] Add API client methods for the new backend routes.
- [ ] Make controller methods choose local or remote based on `TransportMode`.
- [ ] Run `cd app && flutter test` when Flutter is available.

### Task 5: Remote Control UI Parity

**Files:**
- Modify: `app/lib/app/modules/connected_device/views/connected_device_view.dart`

- [ ] Reuse the dosing head controls in Real Server mode.
- [ ] Keep pump hidden in local mode if unsupported by local ESP32.
- [ ] Keep pending-command disabled states.
- [ ] Manually verify no text overflow on the Control tab.

## Chunk 3: Docs and Firmware Handoff

### Task 6: Documentation

**Files:**
- Modify: `docs/API_DOCUMENTATION.md`
- Modify: `docs/UBUNTU_BACKEND_DEPLOYMENT.md`
- Modify: `app/README.md`
- Create/modify: `docs/MQTT_CONTRACT.md`
- Create/modify: `docs/ESP32_REMOTE_FEATURE_IMPLEMENTATION_PLAN.md`

- [ ] Document backend URL as `https://api2.yoyojun.site`.
- [ ] Document the expanded backend API.
- [ ] Document the MQTT compatibility strategy.
- [ ] Document required ESP32 firmware command subscriptions.

## Verification

- [ ] `cd backend && npm test`
- [ ] `cd app && flutter test` when Flutter is available
- [ ] Public backend smoke tests:

```bash
curl https://api2.yoyojun.site/api/health
curl https://api2.yoyojun.site/api/device/status
curl -N https://api2.yoyojun.site/api/device/events
```

