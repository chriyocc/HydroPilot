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

    final settings = AppSettings(
      deviceIp: '192.168.1.44',
      mqttBrokerIp: '192.168.1.50',
      topicPrefix: 'hydro',
      refreshInterval: 8,
    );

    await service.saveSettings(settings);

    expect(service.loadSettings(), settings);
  });
}
