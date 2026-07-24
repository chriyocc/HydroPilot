import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:home_fi/app/models/app_settings.dart';
import 'package:home_fi/app/models/runtime_status.dart';
import 'package:home_fi/app/models/sensor_data.dart';
import 'package:home_fi/app/models/device_state.dart';
import 'package:home_fi/app/modules/home/controllers/home_controller.dart';
import 'package:home_fi/app/modules/home/views/settings_view.dart';
import 'package:home_fi/app/services/hydro_api_service.dart';
import 'package:home_fi/app/services/settings_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'test_helpers/fake_path_provider_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    Get.testMode = true;
    PathProviderPlatform.instance = FakePathProviderPlatform();
    await GetStorage.init('settings_view_test');
    await GetStorage('settings_view_test').erase();
  });

  tearDown(Get.reset);

  testWidgets('shows local ESP32 URL field in local network mode',
      (tester) async {
    final controller = createController(
      const AppSettings(
        transportMode: TransportMode.localNetwork,
        localDeviceBaseUrl: 'http://192.168.1.50',
        backendBaseUrl: '',
        refreshInterval: 0,
      ),
    );
    Get.put<HomeController>(controller);

    await tester.pumpWidget(
      GetMaterialApp(
        home: const Scaffold(body: SettingsView()),
      ),
    );
    await tester.pump();

    expect(find.text('Local ESP32 URL'), findsOneWidget);
    expect(find.text('Backend Base URL'), findsNothing);
  });

  testWidgets('shows backend URL field in real server mode', (tester) async {
    final controller = createController(
      const AppSettings(
        transportMode: TransportMode.realServer,
        localDeviceBaseUrl: AppSettings.defaultLocalDeviceBaseUrl,
        backendBaseUrl: 'http://192.168.1.44:3000',
        refreshInterval: 0,
      ),
    );
    Get.put<HomeController>(controller);

    await tester.pumpWidget(
      GetMaterialApp(
        home: const Scaffold(body: SettingsView()),
      ),
    );
    await tester.pump();

    expect(find.text('Backend Base URL'), findsOneWidget);
    expect(find.text('Local ESP32 URL'), findsNothing);
  });
}

HomeController createController(AppSettings settings) {
  return HomeController(
    settingsService: FakeSettingsService(settings),
    apiService: FakeHydroApiService(),
    enableAutoRefresh: false,
  );
}

class FakeSettingsService extends SettingsService {
  FakeSettingsService(this.settings) : super(GetStorage('settings_view_test'));

  final AppSettings settings;

  @override
  AppSettings loadSettings() => settings;
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
  Future<HydroStatusSnapshot> fetchLocalStatus(String baseUrl) async {
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
    return const Stream.empty();
  }
}
