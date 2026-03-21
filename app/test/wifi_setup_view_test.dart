import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:home_fi/app/models/app_settings.dart';
import 'package:home_fi/app/models/device_state.dart';
import 'package:home_fi/app/models/runtime_status.dart';
import 'package:home_fi/app/models/sensor_data.dart';
import 'package:home_fi/app/modules/home/controllers/home_controller.dart';
import 'package:home_fi/app/modules/home/views/wifi_setup_view.dart';
import 'package:home_fi/app/services/device_provisioning_service.dart';
import 'package:home_fi/app/services/hydro_api_service.dart';
import 'package:home_fi/app/services/settings_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'test_helpers/fake_path_provider_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    Get.testMode = true;
    PathProviderPlatform.instance = FakePathProviderPlatform();
    await GetStorage.init('wifi_setup_view_test');
    await GetStorage('wifi_setup_view_test').erase();
  });

  tearDown(Get.reset);

  testWidgets('shows automatic setup copy on supported Android',
      (tester) async {
    final controller = createController(isSupported: true);
    Get.put<HomeController>(controller);

    await tester.pumpWidget(
      GetMaterialApp(
        home: const WifiSetupView(),
      ),
    );
    await tester.pump();

    expect(
      find.textContaining('The app will ask Android to connect'),
      findsOneWidget,
    );
    expect(find.text('Connect Automatically'), findsOneWidget);
  });

  testWidgets('shows manual setup copy when automatic provisioning is unsupported',
      (tester) async {
    final controller = createController(isSupported: false);
    Get.put<HomeController>(controller);

    await tester.pumpWidget(
      GetMaterialApp(
        home: const WifiSetupView(),
      ),
    );
    await tester.pump();

    expect(
      find.textContaining('Join the controller access point first'),
      findsOneWidget,
    );
    expect(find.text('Connect Manually'), findsOneWidget);
  });
}

HomeController createController({
  required bool isSupported,
}) {
  final controller = HomeController(
    settingsService: FakeSettingsService(),
    apiService: FakeHydroApiService(),
    provisioningService: FakeDeviceProvisioningService(isSupported: isSupported),
    enableAutoRefresh: false,
  );
  controller.isAutoProvisioningSupported = isSupported;
  return controller;
}

class FakeHydroApiService extends HydroApiService {
  @override
  Future<HydroStatusSnapshot> fetchStatus(String backendBaseUrl) async {
    return const HydroStatusSnapshot(
      sensorData: SensorData(),
      deviceState: DeviceState(),
      runtimeStatus: RuntimeStatus(
        isBackendReachable: true,
        isDeviceOnline: true,
      ),
    );
  }

  @override
  Stream<HydroSseEvent> openEventStream(String backendBaseUrl) {
    return const Stream<HydroSseEvent>.empty();
  }
}

class FakeDeviceProvisioningService extends DeviceProvisioningService {
  FakeDeviceProvisioningService({
    required this.isSupported,
  }) : super(platformInvoker: _unusedPlatformInvoker);

  static Future<Map<Object?, Object?>> _unusedPlatformInvoker({
    required String method,
    required Map<String, Object?> arguments,
  }) {
    throw UnimplementedError();
  }

  final bool isSupported;

  @override
  Future<bool> isAutoProvisioningSupported() async => isSupported;
}

class FakeSettingsService extends SettingsService {
  FakeSettingsService() : super(GetStorage('wifi_setup_view_test'));

  @override
  AppSettings loadSettings() => AppSettings.defaults();
}
