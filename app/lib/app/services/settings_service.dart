import 'package:get_storage/get_storage.dart';
import 'package:home_fi/app/models/app_settings.dart';

class SettingsService {
  SettingsService([GetStorage? storage]) : _storage = storage ?? GetStorage();

  static const _settingsKey = 'hydropilot_settings';

  final GetStorage _storage;

  AppSettings loadSettings() {
    final storedData = _storage.read(_settingsKey);
    if (storedData is Map) {
      return AppSettings.fromJson(Map<String, dynamic>.from(storedData));
    }

    return AppSettings.defaults();
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _storage.write(_settingsKey, settings.toJson());
  }
}
