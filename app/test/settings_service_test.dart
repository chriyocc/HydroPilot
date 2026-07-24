import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:home_fi/app/models/app_settings.dart';
import 'package:home_fi/app/services/settings_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'test_helpers/fake_path_provider_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    PathProviderPlatform.instance = FakePathProviderPlatform();
    await GetStorage.init('settings_service_test');
    await GetStorage('settings_service_test').erase();
  });

  test('settings service persists hydropilot settings', () async {
    final service = SettingsService(GetStorage('settings_service_test'));

    const settings = AppSettings(
      transportMode: TransportMode.localNetwork,
      localDeviceBaseUrl: 'http://192.168.1.50',
      backendBaseUrl: 'http://192.168.1.44:3000',
      refreshInterval: 8,
    );

    await service.saveSettings(settings);

    expect(service.loadSettings(), settings);
  });

  test('settings service migrates old device settings to empty backend url',
      () {
    final storage = GetStorage('settings_service_test');
    storage.write('hydropilot_settings', {
      'deviceIp': '192.168.1.44',
      'mqttBrokerIp': '192.168.1.50',
      'topicPrefix': 'hydro',
      'refreshInterval': 8,
    });

    final service = SettingsService(storage);

    expect(
      service.loadSettings(),
      const AppSettings(
        transportMode: TransportMode.realServer,
        localDeviceBaseUrl: AppSettings.defaultLocalDeviceBaseUrl,
        backendBaseUrl: '',
        refreshInterval: 8,
      ),
    );
  });
}
