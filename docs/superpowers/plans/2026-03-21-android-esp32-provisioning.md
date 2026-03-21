# Android ESP32 Provisioning Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Android 10+ in-app connection to the fixed ESP32 setup AP, then reuse the existing `POST /wifi` flow to provision the device without requiring a manual AP join on supported devices.

**Architecture:** Flutter gains a provisioning service that talks to Android native code over a method channel. Android-native code uses `WifiNetworkSpecifier` and `ConnectivityManager.requestNetwork(...)` to join the fixed ESP32 AP, then Flutter posts the user's home Wi-Fi credentials to `http://192.168.4.1/wifi`; older Android versions fall back to the existing manual instructions.

**Tech Stack:** Flutter, GetX, Dart, Kotlin, Android ConnectivityManager, MethodChannel, Flutter test

---

## File Structure

- Create: `app/lib/app/services/device_provisioning_service.dart`
- Create: `app/test/app/services/device_provisioning_service_test.dart`
- Modify: `app/lib/app/modules/home/controllers/home_controller.dart`
- Modify: `app/lib/app/modules/home/views/wifi_setup_view.dart`
- Modify: `app/lib/app/services/hydro_api_service.dart`
- Modify: `app/android/app/src/main/AndroidManifest.xml`
- Modify: `app/android/app/src/main/kotlin/com/geekflow/home_fi/MainActivity.kt`
- Create if needed: `app/android/app/src/main/kotlin/com/geekflow/home_fi/DeviceProvisioningChannel.kt`

## Chunk 1: Flutter Provisioning Abstraction

### Task 1: Add the provisioning service contract

**Files:**
- Create: `app/lib/app/services/device_provisioning_service.dart`
- Test: `app/test/app/services/device_provisioning_service_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
test('returns unsupported on non-Android or unsupported Android versions', () async {
  final service = DeviceProvisioningService(platformInvoker: fakeInvoker);

  final result = await service.connectToDeviceAp(
    ssid: 'HydroPilot-Setup',
    password: 'setup-password',
  );

  expect(result.code, ProvisioningResultCode.unsupportedAndroidVersion);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/app/services/device_provisioning_service_test.dart`
Expected: FAIL because `DeviceProvisioningService` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```dart
class DeviceProvisioningService {
  DeviceProvisioningService({required this.platformInvoker});

  final Future<Map<String, dynamic>> Function(String method, Map<String, dynamic> args)
      platformInvoker;

  Future<ProvisioningResult> connectToDeviceAp({
    required String ssid,
    required String password,
  }) async {
    final payload = await platformInvoker('connectToDeviceAp', {
      'ssid': ssid,
      'password': password,
    });
    return ProvisioningResult.fromPayload(payload);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/app/services/device_provisioning_service_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/lib/app/services/device_provisioning_service.dart app/test/app/services/device_provisioning_service_test.dart
git commit -m "feat: add device provisioning service"
```

### Task 2: Cover result mapping and timeout/error codes

**Files:**
- Modify: `app/lib/app/services/device_provisioning_service.dart`
- Test: `app/test/app/services/device_provisioning_service_test.dart`

- [ ] **Step 1: Write failing tests for result mapping**

```dart
test('maps user_denied and connection_timeout errors', () async {
  final service = DeviceProvisioningService(platformInvoker: fakeInvoker);

  fakeInvokerResult = {'code': 'user_denied'};
  expect((await service.connectToDeviceAp(ssid: 's', password: 'p')).code,
      ProvisioningResultCode.userDenied);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/app/services/device_provisioning_service_test.dart`
Expected: FAIL because the enum/result mapping is incomplete.

- [ ] **Step 3: Implement the missing mapping**

```dart
enum ProvisioningResultCode {
  connected,
  unsupportedAndroidVersion,
  userDenied,
  connectionTimeout,
  connectionFailed,
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/app/services/device_provisioning_service_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/lib/app/services/device_provisioning_service.dart app/test/app/services/device_provisioning_service_test.dart
git commit -m "test: cover provisioning result mapping"
```

## Chunk 2: Controller and UI Flow

### Task 3: Move setup orchestration into `HomeController`

**Files:**
- Modify: `app/lib/app/modules/home/controllers/home_controller.dart`
- Modify: `app/lib/app/services/hydro_api_service.dart`
- Test: `app/test/app/modules/home/controllers/home_controller_test.dart`

- [ ] **Step 1: Write the failing controller test**

```dart
test('connects to device AP before posting wifi credentials', () async {
  await controller.startWifiProvisioning(
    homeSsid: 'MyHome',
    homePassword: 'secret123',
  );

  expect(fakeProvisioningService.calls.single, 'connectToDeviceAp');
  expect(fakeApiService.configureWifiCallCount, 1);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/app/modules/home/controllers/home_controller_test.dart`
Expected: FAIL because the controller does not expose the new provisioning flow.

- [ ] **Step 3: Implement the minimal orchestration**

```dart
final provisioning = await _deviceProvisioningService.connectToDeviceAp(
  ssid: _setupSsid,
  password: _setupPassword,
);
if (!provisioning.isConnected) return;
await _apiService.configureWifi(ssid: homeSsid, password: homePassword);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/app/modules/home/controllers/home_controller_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/lib app/test/app/modules/home/controllers/home_controller_test.dart
git commit -m "feat: orchestrate android wifi provisioning"
```

### Task 4: Update the setup screen to show guided provisioning states

**Files:**
- Modify: `app/lib/app/modules/home/views/wifi_setup_view.dart`
- Test: `app/test/app/modules/home/views/wifi_setup_view_test.dart`

- [ ] **Step 1: Write the failing widget test**

```dart
testWidgets('shows automatic setup copy on supported Android', (tester) async {
  await tester.pumpWidget(buildSetupView());

  expect(find.textContaining('connect to the controller'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/app/modules/home/views/wifi_setup_view_test.dart`
Expected: FAIL because the setup view still only describes the manual flow.

- [ ] **Step 3: Implement the UI copy and state handling**

```dart
Text(
  controller.isAutoProvisioningSupported
      ? 'The app will ask Android to connect to the controller setup Wi-Fi.'
      : 'Join the controller access point first, then return here.',
)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/app/modules/home/views/wifi_setup_view_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/lib/app/modules/home/views/wifi_setup_view.dart app/test/app/modules/home/views/wifi_setup_view_test.dart
git commit -m "feat: update setup view for guided provisioning"
```

## Chunk 3: Android Native Channel

### Task 5: Add method-channel handling in Android

**Files:**
- Modify: `app/android/app/src/main/kotlin/com/geekflow/home_fi/MainActivity.kt`
- Create if needed: `app/android/app/src/main/kotlin/com/geekflow/home_fi/DeviceProvisioningChannel.kt`

- [ ] **Step 1: Write the failing integration boundary test or stub verification**

```text
Document a manual verification stub: Flutter invokes `connectToDeviceAp` and receives `not_implemented` until Kotlin handler exists.
```

- [ ] **Step 2: Run the app and verify the call currently fails**

Run: `cd app && flutter run`
Expected: The method channel call throws `MissingPluginException`.

- [ ] **Step 3: Implement the method channel**

```kotlin
MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hydropilot/provisioning")
    .setMethodCallHandler { call, result ->
        if (call.method == "connectToDeviceAp") {
            provisioningChannel.connect(call, result)
        } else {
            result.notImplemented()
        }
    }
```

- [ ] **Step 4: Re-run the app to verify the call reaches Kotlin**

Run: `cd app && flutter run`
Expected: No `MissingPluginException`; unsupported or placeholder result reaches Flutter.

- [ ] **Step 5: Commit**

```bash
git add app/android/app/src/main/kotlin/com/geekflow/home_fi/MainActivity.kt app/android/app/src/main/kotlin/com/geekflow/home_fi/DeviceProvisioningChannel.kt
git commit -m "feat: add android provisioning method channel"
```

### Task 6: Implement Android 10+ AP connection logic

**Files:**
- Modify: `app/android/app/src/main/kotlin/com/geekflow/home_fi/DeviceProvisioningChannel.kt`

- [ ] **Step 1: Add a failing manual verification case**

```text
On Android 10+, requesting setup should currently return a placeholder instead of connecting.
```

- [ ] **Step 2: Run the flow to verify the failure**

Run: `cd app && flutter run`
Expected: The app shows a failed provisioning state because no real network request is implemented yet.

- [ ] **Step 3: Implement the minimal network request**

```kotlin
val specifier = WifiNetworkSpecifier.Builder()
    .setSsid(ssid)
    .setWpa2Passphrase(password)
    .build()

val request = NetworkRequest.Builder()
    .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
    .setNetworkSpecifier(specifier)
    .build()
```

- [ ] **Step 4: Re-run the flow and verify Android shows the system Wi-Fi prompt**

Run: `cd app && flutter run`
Expected: Android shows the connection approval UI for the fixed ESP32 SSID.

- [ ] **Step 5: Commit**

```bash
git add app/android/app/src/main/kotlin/com/geekflow/home_fi/DeviceProvisioningChannel.kt
git commit -m "feat: request esp32 setup wifi on android"
```

### Task 7: Add timeout, cleanup, and stable error mapping

**Files:**
- Modify: `app/android/app/src/main/kotlin/com/geekflow/home_fi/DeviceProvisioningChannel.kt`

- [ ] **Step 1: Define failing manual verification cases**

```text
Verify no timeout result is emitted when the AP is absent, and no denial mapping exists when the user cancels.
```

- [ ] **Step 2: Reproduce the failure**

Run: `cd app && flutter run`
Expected: The app hangs or returns a generic failure when the AP is unavailable or denied.

- [ ] **Step 3: Implement timeout and result mapping**

```kotlin
handler.postDelayed({
    connectivityManager.unregisterNetworkCallback(callback)
    result.success(mapOf("code" to "connection_timeout"))
}, timeoutMs)
```

- [ ] **Step 4: Re-run manual checks**

Run: `cd app && flutter run`
Expected: `connection_timeout`, `user_denied`, or `connection_failed` is returned consistently.

- [ ] **Step 5: Commit**

```bash
git add app/android/app/src/main/kotlin/com/geekflow/home_fi/DeviceProvisioningChannel.kt
git commit -m "fix: stabilize android provisioning errors"
```

## Chunk 4: Permissions and Fallback

### Task 8: Add manifest permissions for Wi-Fi provisioning

**Files:**
- Modify: `app/android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Add a failing manual verification note**

```text
Without additional permissions, Android provisioning may fail before showing the system prompt on supported versions.
```

- [ ] **Step 2: Verify current manifest is insufficient**

Run: `sed -n '1,200p' app/android/app/src/main/AndroidManifest.xml`
Expected: Only `INTERNET` is declared.

- [ ] **Step 3: Add required permissions**

```xml
<uses-permission android:name="android.permission.NEARBY_WIFI_DEVICES" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

- [ ] **Step 4: Rebuild to verify manifest compiles**

Run: `cd app && flutter build apk --debug`
Expected: BUILD SUCCESSFUL

- [ ] **Step 5: Commit**

```bash
git add app/android/app/src/main/AndroidManifest.xml
git commit -m "chore: add android wifi provisioning permissions"
```

### Task 9: Preserve the manual fallback path

**Files:**
- Modify: `app/lib/app/modules/home/controllers/home_controller.dart`
- Modify: `app/lib/app/modules/home/views/wifi_setup_view.dart`
- Test: `app/test/app/modules/home/views/wifi_setup_view_test.dart`

- [ ] **Step 1: Write the failing fallback test**

```dart
testWidgets('shows manual setup instructions when auto provisioning is unsupported', (tester) async {
  await tester.pumpWidget(buildUnsupportedSetupView());

  expect(find.textContaining('Join the controller access point first'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/app/modules/home/views/wifi_setup_view_test.dart`
Expected: FAIL because the UI does not branch cleanly between auto and manual modes.

- [ ] **Step 3: Implement the fallback branch**

```dart
if (!controller.isAutoProvisioningSupported) {
  return ManualProvisioningInstructions(...);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/app/modules/home/views/wifi_setup_view_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/lib/app/modules/home/controllers/home_controller.dart app/lib/app/modules/home/views/wifi_setup_view.dart app/test/app/modules/home/views/wifi_setup_view_test.dart
git commit -m "feat: keep manual fallback for older android"
```

## Chunk 5: Verification

### Task 10: Run automated tests

**Files:**
- Test: `app/test/...`

- [ ] **Step 1: Run focused tests**

Run: `cd app && flutter test test/app/services/device_provisioning_service_test.dart test/app/modules/home/controllers/home_controller_test.dart test/app/modules/home/views/wifi_setup_view_test.dart`
Expected: PASS

- [ ] **Step 2: Run broader Flutter tests**

Run: `cd app && flutter test`
Expected: PASS or only unrelated pre-existing failures.

- [ ] **Step 3: Commit if test fixes were needed**

```bash
git add app
git commit -m "test: finalize android provisioning coverage"
```

### Task 11: Manual Android verification

**Files:**
- No file changes required unless issues are found

- [ ] **Step 1: Verify supported-device success path**

Run: `cd app && flutter run`
Expected: On Android 10+, the app shows the Android Wi-Fi approval UI for the fixed ESP32 SSID, then posts credentials to `192.168.4.1/wifi`.

- [ ] **Step 2: Verify AP unavailable timeout**

Run: `cd app && flutter run`
Expected: The app surfaces a timeout message and does not hang indefinitely.

- [ ] **Step 3: Verify user cancellation**

Run: `cd app && flutter run`
Expected: The app surfaces a denial/cancel message and does not attempt `POST /wifi`.

- [ ] **Step 4: Verify older-Android fallback if available**

Run: `cd app && flutter run`
Expected: The app shows the manual AP join instructions without attempting auto-connect.

- [ ] **Step 5: Commit any final fixes**

```bash
git add app
git commit -m "fix: polish android provisioning flow"
```
