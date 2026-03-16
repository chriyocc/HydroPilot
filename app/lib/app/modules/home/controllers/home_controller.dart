import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:home_fi/app/models/app_settings.dart';
import 'package:home_fi/app/models/device_state.dart';
import 'package:home_fi/app/models/sensor_data.dart';
import 'package:home_fi/app/modules/connected_device/views/connected_device_view.dart';
import 'package:home_fi/app/modules/home/views/dashboard_view.dart';
import 'package:home_fi/app/modules/home/views/settings_view.dart';
import 'package:home_fi/app/services/hydro_api_service.dart';
import 'package:home_fi/app/services/settings_service.dart';

class HomeController extends GetxController {
  HomeController({
    SettingsService? settingsService,
    HydroApiService? apiService,
    this.enableAutoRefresh = true,
  })  : _settingsService = settingsService ?? SettingsService(),
        _apiService = apiService ?? HydroApiService();

  final SettingsService _settingsService;
  final HydroApiService _apiService;
  final bool enableAutoRefresh;

  final RxInt _currentIndex = 0.obs;
  Timer? _refreshTimer;

  int get currentIndex => _currentIndex.value;

  AppSettings settings = AppSettings.defaults();
  SensorData sensorData = const SensorData();
  DeviceState deviceState = const DeviceState();
  bool isLoadingStatus = true;
  bool isPerformingAction = false;
  String? statusMessage;
  String? lastActionMessage;

  final List<Widget> homeViews = const [
    DashboardView(),
    ConnectedDeviceView(),
    SettingsView(),
  ];

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
  }

  void setCurrentIndex(int index) {
    _currentIndex.value = index;
  }

  Widget navBarSwitcher() {
    return homeViews.elementAt(currentIndex);
  }

  Future<void> refreshStatus({bool showLoading = false}) async {
    if (showLoading) {
      isLoadingStatus = true;
      update(['dashboard', 'control']);
    }

    try {
      final snapshot = await _apiService.fetchStatus(settings.deviceIp);
      sensorData = snapshot.sensorData;
      deviceState = snapshot.deviceState;
      statusMessage = null;
    } catch (_) {
      statusMessage = 'Unable to reach controller at ${settings.deviceIp}.';
    } finally {
      isLoadingStatus = false;
      update(['dashboard', 'control']);
    }
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    settings = newSettings;
    await _settingsService.saveSettings(newSettings);
    _restartRefreshTimer();
    update(['settings']);
    await refreshStatus(showLoading: true);
  }

  Future<void> togglePump(bool value) async {
    await _runDeviceAction(
      optimisticState: deviceState.copyWith(pumpOn: value),
      action: () => _apiService.setPump(settings.deviceIp, value),
      successMessage:
          value ? 'Pump turned on.' : 'Pump turned off.',
    );
  }

  Future<void> toggleGrowLight(bool value) async {
    await _runDeviceAction(
      optimisticState: deviceState.copyWith(lightOn: value),
      action: () => _apiService.setGrowLight(settings.deviceIp, value),
      successMessage:
          value ? 'Grow light turned on.' : 'Grow light turned off.',
    );
  }

  Future<void> doseNutrientA() async {
    await _runSideEffectAction(
      action: () => _apiService.doseNutrientA(settings.deviceIp),
      successMessage: 'Nutrient A dose sent.',
    );
  }

  Future<void> doseNutrientB() async {
    await _runSideEffectAction(
      action: () => _apiService.doseNutrientB(settings.deviceIp),
      successMessage: 'Nutrient B dose sent.',
    );
  }

  Future<void> configureWifi({
    required String ssid,
    required String password,
  }) async {
    await _runSideEffectAction(
      action: () => _apiService.configureWifi(ssid: ssid, password: password),
      successMessage: 'WiFi credentials sent to the controller.',
    );
  }

  Future<void> _loadSettings() async {
    settings = _settingsService.loadSettings();
    update(['settings']);
    if (enableAutoRefresh) {
      _restartRefreshTimer();
    }
    await refreshStatus(showLoading: true);
  }

  void _restartRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      Duration(seconds: settings.refreshInterval),
      (_) => refreshStatus(),
    );
  }

  Future<void> _runDeviceAction({
    required DeviceState optimisticState,
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    final previousState = deviceState;
    deviceState = optimisticState;
    isPerformingAction = true;
    lastActionMessage = null;
    update(['dashboard', 'control']);

    try {
      await action();
      lastActionMessage = successMessage;
    } catch (_) {
      deviceState = previousState;
      lastActionMessage = 'Unable to update controller state.';
    } finally {
      isPerformingAction = false;
      update(['dashboard', 'control']);
    }
  }

  Future<void> _runSideEffectAction({
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    isPerformingAction = true;
    lastActionMessage = null;
    update(['control']);

    try {
      await action();
      lastActionMessage = successMessage;
    } catch (_) {
      lastActionMessage = 'Request failed. Check the controller connection.';
    } finally {
      isPerformingAction = false;
      update(['control']);
    }
  }

  @override
  void onClose() {
    _refreshTimer?.cancel();
    super.onClose();
  }
}
