import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:home_fi/app/models/app_settings.dart';
import 'package:home_fi/app/models/device_state.dart';
import 'package:home_fi/app/models/runtime_status.dart';
import 'package:home_fi/app/models/sensor_data.dart';
import 'package:home_fi/app/modules/home/controllers/home_controller.dart';
import 'package:home_fi/app/services/hydro_api_service.dart';
import 'package:home_fi/app/services/settings_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'test_helpers/fake_path_provider_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    PathProviderPlatform.instance = FakePathProviderPlatform();
    await GetStorage.init('home_controller_test');
    await GetStorage('home_controller_test').erase();
  });

  test('controller stays disconnected when backend URL is empty', () async {
    final settingsService = await createSettingsService(
      const AppSettings(
        backendBaseUrl: '',
        refreshInterval: 0,
      ),
    );
    final controller = HomeController(
      settingsService: settingsService,
      apiService: FakeHydroApiService(),
      enableAutoRefresh: false,
    );

    controller.onInit();
    await Future<void>.delayed(Duration.zero);

    expect(controller.statusMessage, 'Set a backend URL in Settings.');
    expect(controller.runtimeStatus.isBackendReachable, false);
  });

  test('controller tracks pending commands and clears matched timeout results',
      () async {
    final apiService = FakeHydroApiService();
    final settingsService = await createSettingsService(
      const AppSettings(
        backendBaseUrl: 'http://localhost:3000',
        refreshInterval: 0,
      ),
    );
    final controller = HomeController(
      settingsService: settingsService,
      apiService: apiService,
      enableAutoRefresh: false,
    );

    controller.onInit();
    await Future<void>.delayed(Duration.zero);
    await controller.togglePump(true);

    expect(controller.isCommandPending(CommandType.pump), true);

    apiService.emit(
      const HydroSseEvent(
        name: 'command-result',
        payload: {
          'requestId': 'pump-1',
          'status': 'timeout',
        },
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.isCommandPending(CommandType.pump), false);
    expect(controller.lastActionMessage, 'Pump command timed out.');
  });

  test('controller applies SSE snapshot and state updates authoritatively',
      () async {
    final apiService = FakeHydroApiService();
    final settingsService = await createSettingsService(
      const AppSettings(
        backendBaseUrl: 'http://localhost:3000',
        refreshInterval: 0,
      ),
    );
    final controller = HomeController(
      settingsService: settingsService,
      apiService: apiService,
      enableAutoRefresh: false,
    );

    controller.onInit();
    await Future<void>.delayed(Duration.zero);

    apiService.emit(
      const HydroSseEvent(
        name: 'snapshot',
        payload: {
          'deviceId': 'device-1',
          'broker': {'connected': true, 'status': 'connected'},
          'availability': {'online': true, 'status': 'online'},
          'sensors': {
            'ph': 6.8,
            'ec': 2.1,
            'waterTemperature': 25.0,
            'waterLevel': 78,
          },
          'deviceState': {
            'pumpOn': false,
            'lightOn': true,
          },
          'alarms': {'latest': null},
          'timestamps': {
            'lastTelemetryAt': '2026-03-20T12:00:01.000Z',
            'lastStateAt': '2026-03-20T12:00:02.000Z',
            'lastAvailabilityAt': '2026-03-20T12:00:00.000Z',
            'lastAlarmAt': null,
          },
          'freshness': {
            'offline': false,
            'staleTelemetry': false,
            'staleState': false,
          },
        },
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.sensorData.ph, 6.8);
    expect(controller.deviceState.lightOn, true);
    expect(controller.runtimeStatus.isDeviceOnline, true);

    apiService.emit(
      const HydroSseEvent(
        name: 'state',
        payload: {
          'field': 'pumpOn',
          'value': true,
          'requestId': 'pump-2',
        },
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.deviceState.pumpOn, true);
  });

  test('controller posts wifi credentials to device setup endpoint', () async {
    final apiService = FakeHydroApiService();
    final settingsService = await createSettingsService(
      const AppSettings(
        backendBaseUrl: 'http://localhost:3000',
        refreshInterval: 0,
      ),
    );
    final controller = HomeController(
      settingsService: settingsService,
      apiService: apiService,
      enableAutoRefresh: false,
    );

    controller.onInit();
    await Future<void>.delayed(Duration.zero);

    await controller.configureWifi(ssid: 'OfficeWiFi', password: 'secret123');

    expect(apiService.lastConfiguredSsid, 'OfficeWiFi');
    expect(apiService.lastConfiguredPassword, 'secret123');
    expect(
      controller.lastActionMessage,
      'WiFi credentials sent to the controller.',
    );
  });
}

Future<SettingsService> createSettingsService(AppSettings settings) async {
    final storage = GetStorage('home_controller_test');
    await storage.write('hydropilot_settings', settings.toJson());
    return SettingsService(storage);
}

class FakeHydroApiService extends HydroApiService {
  FakeHydroApiService()
      : _streamController = StreamController<HydroSseEvent>.broadcast();

  final StreamController<HydroSseEvent> _streamController;
  String? lastConfiguredSsid;
  String? lastConfiguredPassword;

  @override
  Future<HydroStatusSnapshot> fetchStatus(String backendBaseUrl) async {
    return HydroStatusSnapshot(
      sensorData: const SensorData(),
      deviceState: const DeviceState(),
      runtimeStatus: RuntimeStatus(
        isBackendReachable: true,
        isDeviceOnline: null,
      ),
    );
  }

  @override
  Stream<HydroSseEvent> openEventStream(String backendBaseUrl) {
    return _streamController.stream;
  }

  @override
  Future<HydroCommandAccepted> setPump(String backendBaseUrl, bool on) async {
    return const HydroCommandAccepted(requestId: 'pump-1', status: 'accepted');
  }

  @override
  Future<void> configureWifi({
    required String ssid,
    required String password,
  }) async {
    lastConfiguredSsid = ssid;
    lastConfiguredPassword = password;
  }

  void emit(HydroSseEvent event) {
    _streamController.add(event);
  }
}
