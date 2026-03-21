# Android ESP32 Provisioning Design

## Summary

HydroPilot currently requires the user to manually join the ESP32 SoftAP before the app can send home Wi-Fi credentials to `http://192.168.4.1/wifi`.

This design replaces the manual AP join step on Android 10 and newer with an in-app provisioning flow that asks Android to connect to the fixed, password-protected ESP32 setup SSID. After Android reports the network is available, the Flutter app reuses the existing `/wifi` endpoint to send the user's home Wi-Fi credentials to the device.

Android 9 and older remain on the current manual fallback flow.

## Goals

- Remove the manual "open Settings and join the controller AP" step for Android 10+ users.
- Preserve the existing ESP32 provisioning contract at `POST /wifi`.
- Keep the initial implementation Android-only.
- Provide clear fallback behavior for unsupported Android versions and connection failures.

## Non-Goals

- iOS provisioning.
- BLE-based provisioning.
- General-purpose Wi-Fi browsing inside the app.
- Changing the ESP32 provisioning API shape in this phase.

## Existing State

- The setup screen in [`/Users/yoyojun/Documents/GitHub/HydroPilot/app/lib/app/modules/home/views/wifi_setup_view.dart`](/Users/yoyojun/Documents/GitHub/HydroPilot/app/lib/app/modules/home/views/wifi_setup_view.dart) instructs the user to manually join the controller AP.
- [`/Users/yoyojun/Documents/GitHub/HydroPilot/app/lib/app/services/hydro_api_service.dart`](/Users/yoyojun/Documents/GitHub/HydroPilot/app/lib/app/services/hydro_api_service.dart) sends credentials directly to `http://192.168.4.1/wifi`.
- [`/Users/yoyojun/Documents/GitHub/HydroPilot/app/android/app/src/main/AndroidManifest.xml`](/Users/yoyojun/Documents/GitHub/HydroPilot/app/android/app/src/main/AndroidManifest.xml) currently only declares `INTERNET`.

## Chosen Approach

Use Android's official Wi-Fi provisioning APIs for local accessory setup:

- Flutter calls a new provisioning service.
- The service uses a method channel to invoke Android-native code.
- On Android 10+ the native side uses `WifiNetworkSpecifier` and `ConnectivityManager.requestNetwork(...)` to request connection to the fixed ESP32 setup SSID.
- After `onAvailable(...)` fires, Flutter calls the existing `configureWifi(ssid, password)` HTTP method.
- On Android 9 and lower, the app shows the current manual AP instructions instead of attempting auto-connect.

## Alternatives Considered

### 1. Flutter Wi-Fi plugin

Rejected for the first implementation.

Pros:
- Less native code upfront.

Cons:
- Provisioning plugins often become brittle across Android releases.
- Debugging platform-specific connection failures is harder when hidden behind a third-party abstraction.

### 2. BLE provisioning

Rejected for this phase.

Pros:
- Better onboarding UX long-term.

Cons:
- Requires substantial firmware and app changes.
- Not necessary when the existing SoftAP and `/wifi` endpoint already work.

## UX Flow

### Android 10+

1. User opens Device Setup.
2. User enters their home Wi-Fi SSID and password.
3. User taps the primary setup button.
4. App asks Android to connect to the fixed ESP32 setup AP.
5. Android shows the system connection confirmation UI for that AP.
6. If the user approves and the AP becomes available, the app posts the home Wi-Fi credentials to `http://192.168.4.1/wifi`.
7. App shows a success message such as "Credentials sent. Device is joining your Wi-Fi."

### Android 9 and below

1. User opens Device Setup.
2. App shows the current manual AP join instructions.
3. User joins the ESP32 AP in system settings.
4. User returns to the app and submits the home Wi-Fi credentials.

## Architecture

### Flutter layer

Add a `DeviceProvisioningService` that is responsible for:

- checking Android version support
- calling the Android method channel to join the ESP32 AP
- mapping native errors into app-level provisioning states
- triggering the existing `HydroApiService.configureWifi(...)` call once the AP is connected

`HomeController` should orchestrate the flow so the setup screen stays thin.

### Android native layer

Add Android-native provisioning code in Kotlin, preferably in a dedicated helper class invoked by `MainActivity`.

Responsibilities:

- build a `WifiNetworkSpecifier` using the fixed setup SSID and password
- create a `NetworkRequest` with `TRANSPORT_WIFI`
- call `ConnectivityManager.requestNetwork(...)`
- report success only after `NetworkCallback.onAvailable(...)`
- enforce a timeout and unregister the callback when done
- translate Android failures into stable result codes for Flutter

## Data and Configuration

- The ESP32 setup SSID is fixed.
- The ESP32 setup AP password is fixed and should be stored in app configuration for now rather than entered by the user.
- The user only enters the home Wi-Fi SSID and password.

If the project later needs different setup SSIDs per device, the abstraction should accept the setup SSID/password as parameters without redesigning the flow.

## Error Handling

Return structured failures from Android to Flutter:

- `unsupported_android_version`
- `user_denied`
- `connection_timeout`
- `connection_failed`

Flutter should distinguish:

- AP connection failed before HTTP provisioning
- AP connected but `POST /wifi` failed
- unsupported version using manual fallback

## Permissions

Update Android permissions for the provisioning path:

- `android.permission.NEARBY_WIFI_DEVICES` for newer Android releases
- `android.permission.ACCESS_FINE_LOCATION` where required for compatibility

Runtime permission prompts must be handled before or during the setup flow as required by the Android API level in use.

## Testing Strategy

### Flutter

- unit test provisioning controller/service behavior for:
  - supported Android path
  - unsupported-version fallback
  - AP connect success followed by HTTP success
  - AP connect success followed by HTTP failure
  - timeout and denial mapping

### Android manual verification

Validate on at least one Android 10+ device:

- system prompt appears for the fixed ESP32 AP
- app transitions only after `onAvailable(...)`
- `POST /wifi` succeeds after connection
- timeout behavior is correct when the AP is unavailable
- cancellation/denial messaging is correct

## Rollout Notes

- Keep the manual flow accessible until Android auto-connect is proven stable.
- Do not claim silent background provisioning; Android keeps the user approval dialog in the loop.
- iOS can be added later behind the same Flutter provisioning service interface.
