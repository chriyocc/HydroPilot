import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:home_fi/app/models/app_settings.dart';
import 'package:home_fi/app/models/device_state.dart';
import 'package:home_fi/app/models/runtime_status.dart';
import 'package:home_fi/app/models/sensor_data.dart';
import 'package:home_fi/app/modules/home/controllers/home_controller.dart';
import 'package:home_fi/app/services/device_provisioning_service.dart';
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
        transportMode: TransportMode.realServer,
        localDeviceBaseUrl: AppSettings.defaultLocalDeviceBaseUrl,
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
        transportMode: TransportMode.realServer,
        localDeviceBaseUrl: AppSettings.defaultLocalDeviceBaseUrl,
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
        transportMode: TransportMode.realServer,
        localDeviceBaseUrl: AppSettings.defaultLocalDeviceBaseUrl,
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
        transportMode: TransportMode.realServer,
        localDeviceBaseUrl: AppSettings.defaultLocalDeviceBaseUrl,
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

  test('controller connects to device AP before posting wifi credentials',
      () async {
    final apiService = FakeHydroApiService();
    final provisioningService = FakeDeviceProvisioningService();
    final settingsService = await createSettingsService(
      const AppSettings(
        transportMode: TransportMode.realServer,
        localDeviceBaseUrl: AppSettings.defaultLocalDeviceBaseUrl,
        backendBaseUrl: 'http://localhost:3000',
        refreshInterval: 0,
      ),
    );
    final controller = HomeController(
      settingsService: settingsService,
      apiService: apiService,
      provisioningService: provisioningService,
      enableAutoRefresh: false,
    );

    controller.onInit();
    await Future<void>.delayed(Duration.zero);

    await controller.startWifiProvisioning(
      homeSsid: 'OfficeWiFi',
      homePassword: 'secret123',
    );

    expect(provisioningService.lastSsid, 'ESP32_WIFI_AP');
    expect(provisioningService.lastPassword, '12345678');
    expect(apiService.lastConfiguredSsid, 'OfficeWiFi');
    expect(apiService.lastConfiguredPassword, 'secret123');
    expect(provisioningService.disconnectCallCount, 1);
    expect(
      controller.lastActionMessage,
      'WiFi credentials sent to the controller. Device is joining your network.',
    );
  });

  test('controller falls back to manual provisioning when unsupported',
      () async {
    final apiService = FakeHydroApiService();
    final provisioningService = FakeDeviceProvisioningService(
      connectionResult: const ProvisioningResult(
        code: ProvisioningResultCode.unsupportedAndroidVersion,
      ),
      isSupported: false,
    );
    final settingsService = await createSettingsService(
      const AppSettings(
        transportMode: TransportMode.realServer,
        localDeviceBaseUrl: AppSettings.defaultLocalDeviceBaseUrl,
        backendBaseUrl: 'http://localhost:3000',
        refreshInterval: 0,
      ),
    );
    final controller = HomeController(
      settingsService: settingsService,
      apiService: apiService,
      provisioningService: provisioningService,
      enableAutoRefresh: false,
    );

    controller.onInit();
    await Future<void>.delayed(Duration.zero);

    expect(controller.isAutoProvisioningSupported, false);

    await expectLater(
      controller.startWifiProvisioning(
        homeSsid: 'OfficeWiFi',
        homePassword: 'secret123',
      ),
      throwsException,
    );
    expect(apiService.lastConfiguredSsid, isNull);
    expect(
      controller.lastActionMessage,
      'Automatic setup is unavailable on this Android version. Join the controller Wi-Fi manually.',
    );
  });

  test('local network mode fetches local status without opening SSE', () async {
    final apiService = FakeHydroApiService();
    final settingsService = await createSettingsService(
      const AppSettings(
        transportMode: TransportMode.localNetwork,
        localDeviceBaseUrl: 'http://192.168.1.50',
        backendBaseUrl: '',
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

    expect(apiService.lastLocalStatusBaseUrl, 'http://192.168.1.50');
    expect(apiService.openEventStreamCallCount, 0);
    expect(controller.runtimeStatus.isDeviceOnline, true);
    expect(controller.statusMessage, isNull);
  });

  test('local network pump command posts locally and refreshes status',
      () async {
    final apiService = FakeHydroApiService();
    final settingsService = await createSettingsService(
      const AppSettings(
        transportMode: TransportMode.localNetwork,
        localDeviceBaseUrl: 'http://192.168.1.50',
        backendBaseUrl: '',
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

    expect(apiService.lastLocalPumpBaseUrl, 'http://192.168.1.50');
    expect(apiService.lastLocalPumpValue, true);
    expect(apiService.localStatusCallCount, 2);
    expect(controller.isCommandPending(CommandType.pump), false);
    expect(controller.lastActionMessage, 'Pump updated.');
  });

  test('local network nutrient command posts once without backend pending state',
      () async {
    final apiService = FakeHydroApiService();
    final settingsService = await createSettingsService(
      const AppSettings(
        transportMode: TransportMode.localNetwork,
        localDeviceBaseUrl: 'http://192.168.1.50',
        backendBaseUrl: '',
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
    await controller.doseNutrientA();

    expect(apiService.localNutrientACallCount, 1);
    expect(apiService.openEventStreamCallCount, 0);
    expect(controller.isCommandPending(CommandType.nutrientA), false);
    expect(controller.lastActionMessage, 'Nutrient A updated.');
  });

  test('local network target dose sends selected EC concentration', () async {
    final apiService = FakeHydroApiService();
    final settingsService = await createSettingsService(
      const AppSettings(
        transportMode: TransportMode.localNetwork,
        localDeviceBaseUrl: 'http://192.168.1.50',
        backendBaseUrl: '',
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
    controller.setTargetEcAb('1.7');
    await controller.toggleTargetDoseAb();

    expect(apiService.lastToggledDevice, 'target_dose_ab');
    expect(apiService.lastToggleConcentration, 1.7);
    expect(controller.isCommandPending(CommandType.targetDoseAb), false);
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
  String? lastLocalStatusBaseUrl;
  String? lastLocalPumpBaseUrl;
  bool? lastLocalPumpValue;
  String? lastToggledDevice;
  double? lastToggleConcentration;
  int localStatusCallCount = 0;
  int localNutrientACallCount = 0;
  int openEventStreamCallCount = 0;

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
  Future<HydroStatusSnapshot> fetchLocalStatus(String baseUrl) async {
    lastLocalStatusBaseUrl = baseUrl;
    localStatusCallCount += 1;
    return const HydroStatusSnapshot(
      sensorData: SensorData(
        ec: 1413,
        waterTemperature: 24.5,
        waterLevel: 82,
        humidity: 60,
        tds: 420,
        distance: 110,
      ),
      deviceState: DeviceState(
        lightOn: false,
        primeAOn: false,
        targetDoseAbOn: false,
        targetEcA: 1.1,
        targetEcB: 1.2,
        targetEcAb: 1.3,
      ),
      runtimeStatus: RuntimeStatus(
        isBackendReachable: true,
        isDeviceOnline: true,
        isStreamConnected: false,
      ),
    );
  }

  @override
  Stream<HydroSseEvent> openEventStream(String backendBaseUrl) {
    openEventStreamCallCount += 1;
    return _streamController.stream;
  }

  @override
  Future<HydroCommandAccepted> setPump(String backendBaseUrl, bool on) async {
    return const HydroCommandAccepted(requestId: 'pump-1', status: 'accepted');
  }

  @override
  Future<void> setLocalPump(String baseUrl, bool on) async {
    lastLocalPumpBaseUrl = baseUrl;
    lastLocalPumpValue = on;
  }

  @override
  Future<void> doseLocalNutrientA(String baseUrl) async {
    localNutrientACallCount += 1;
  }

  @override
  Future<void> toggleLocalDevice(
    String baseUrl,
    String device, {
    double? concentration,
  }) async {
    lastToggledDevice = device;
    lastToggleConcentration = concentration;
  }

  @override
  Future<HydroEcHistory> fetchLocalEcHistory(String baseUrl) async {
    return const HydroEcHistory(
      periodMs: 2000,
      windowMs: 180000,
      ecValues: [1200, 1300],
    );
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

class FakeDeviceProvisioningService extends DeviceProvisioningService {
  FakeDeviceProvisioningService({
    this.isSupported = true,
    this.connectionResult = const ProvisioningResult(
      code: ProvisioningResultCode.connected,
    ),
  }) : super(platformInvoker: _unusedPlatformInvoker);

  static Future<Map<Object?, Object?>> _unusedPlatformInvoker({
    required String method,
    required Map<String, Object?> arguments,
  }) {
    throw UnimplementedError();
  }

  final bool isSupported;
  final ProvisioningResult connectionResult;
  String? lastSsid;
  String? lastPassword;
  int disconnectCallCount = 0;

  @override
  Future<bool> isAutoProvisioningSupported() async => isSupported;

  @override
  Future<ProvisioningResult> connectToDeviceAp({
    required String ssid,
    required String password,
  }) async {
    lastSsid = ssid;
    lastPassword = password;
    return connectionResult;
  }

  @override
  Future<void> disconnectFromDeviceAp() async {
    disconnectCallCount += 1;
  }
}
