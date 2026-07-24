import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:home_fi/app/models/app_settings.dart';
import 'package:home_fi/app/models/device_state.dart';
import 'package:home_fi/app/models/runtime_status.dart';
import 'package:home_fi/app/models/sensor_data.dart';
import 'package:home_fi/app/modules/connected_device/views/connected_device_view.dart';
import 'package:home_fi/app/modules/home/views/dashboard_view.dart';
import 'package:home_fi/app/modules/home/views/settings_view.dart';
import 'package:home_fi/app/services/device_provisioning_service.dart';
import 'package:home_fi/app/services/hydro_api_service.dart';
import 'package:home_fi/app/services/settings_service.dart';

enum CommandType {
  pump,
  light,
  nutrientA,
  nutrientB,
  primeA,
  primeB,
  targetDoseA,
  targetDoseB,
  targetDoseAb,
  shotDoseA,
  shotDoseB,
}

class HomeController extends GetxController {
  static const String setupAccessPointSsid = 'ESP32_WIFI_AP';
  static const String setupAccessPointPassword = '12345678';

  HomeController({
    SettingsService? settingsService,
    HydroApiService? apiService,
    DeviceProvisioningService? provisioningService,
    this.enableAutoRefresh = true,
  })  : _settingsService = settingsService ?? SettingsService(),
        _apiService = apiService ?? HydroApiService(),
        _provisioningService =
            provisioningService ?? DeviceProvisioningService();

  final SettingsService _settingsService;
  final HydroApiService _apiService;
  final DeviceProvisioningService _provisioningService;
  final bool enableAutoRefresh;

  final RxInt _currentIndex = 0.obs;
  final Map<CommandType, String> _pendingCommandRequestIds = {};

  StreamSubscription<HydroSseEvent>? _eventSubscription;
  Timer? _reconnectTimer;
  Timer? _localRefreshTimer;
  int _reconnectAttempt = 0;

  int get currentIndex => _currentIndex.value;
  bool get hasBackendConfigured => settings.backendBaseUrl.trim().isNotEmpty;
  bool get hasLocalDeviceConfigured =>
      settings.localDeviceBaseUrl.trim().isNotEmpty;
  bool get hasActiveTransportConfigured => settings.usesLocalNetwork
      ? hasLocalDeviceConfigured
      : hasBackendConfigured;

  AppSettings settings = AppSettings.defaults();
  SensorData sensorData = const SensorData();
  DeviceState deviceState = const DeviceState();
  RuntimeStatus runtimeStatus = const RuntimeStatus();
  HydroEcHistory ecHistory = const HydroEcHistory(
    periodMs: 0,
    windowMs: 0,
    ecValues: [],
  );
  bool isLoadingStatus = true;
  bool isAutoProvisioningSupported = false;
  String? statusMessage;
  String? lastActionMessage;
  double targetEcA = 1.0;
  double targetEcB = 1.0;
  double targetEcAb = 1.0;

  final List<Widget> homeViews = const [
    DashboardView(),
    ConnectedDeviceView(),
    SettingsView(),
  ];

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
    _loadProvisioningSupport();
  }

  void setCurrentIndex(int index) {
    _currentIndex.value = index;
  }

  Widget navBarSwitcher() {
    return homeViews.elementAt(currentIndex);
  }

  bool isCommandPending(CommandType type) {
    return _pendingCommandRequestIds.containsKey(type);
  }

  Future<void> refreshStatus({bool showLoading = false}) async {
    if (!hasActiveTransportConfigured) {
      _resetRuntimeState();
      update(['dashboard', 'control', 'settings']);
      return;
    }

    if (showLoading) {
      isLoadingStatus = true;
      update(['dashboard', 'control', 'settings']);
    }

    try {
      final snapshot = settings.usesLocalNetwork
          ? await _apiService.fetchLocalStatus(settings.localDeviceBaseUrl)
          : await _apiService.fetchStatus(settings.backendBaseUrl);
      _applySnapshot(snapshot);
      await _refreshEcHistory();
    } catch (_) {
      runtimeStatus = runtimeStatus.copyWith(
        isBackendReachable: false,
        isStreamConnected: false,
        isDeviceOnline: settings.usesLocalNetwork ? false : null,
      );
      _recomputeStatusMessage();
    } finally {
      isLoadingStatus = false;
      update(['dashboard', 'control', 'settings']);
    }
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    settings = newSettings;
    await _settingsService.saveSettings(newSettings);
    update(['settings']);

    await _clearConnectionState();
    await _loadRuntime();
  }

  Future<void> togglePump(bool value) async {
    if (settings.usesLocalNetwork) {
      await _runLocalCommand(
        type: CommandType.pump,
        action: () => _apiService.setLocalPump(
          settings.localDeviceBaseUrl,
          value,
        ),
      );
      return;
    }

    await _runCommand(
      type: CommandType.pump,
      action: () => _apiService.setPump(settings.backendBaseUrl, value),
      pendingMessage: 'Pump command sent. Waiting for device confirmation.',
    );
  }

  Future<void> toggleGrowLight(bool value) async {
    if (settings.usesLocalNetwork) {
      await _runLocalCommand(
        type: CommandType.light,
        action: () => _apiService.setLocalGrowLight(
          settings.localDeviceBaseUrl,
          value,
        ),
      );
      return;
    }

    await _runCommand(
      type: CommandType.light,
      action: () => _apiService.setGrowLight(settings.backendBaseUrl, value),
      pendingMessage:
          'Grow light command sent. Waiting for device confirmation.',
    );
  }

  Future<void> doseNutrientA() async {
    if (settings.usesLocalNetwork) {
      await _runLocalCommand(
        type: CommandType.nutrientA,
        action: () => _apiService.doseLocalNutrientA(
          settings.localDeviceBaseUrl,
        ),
      );
      return;
    }

    await _runCommand(
      type: CommandType.nutrientA,
      action: () => _apiService.doseNutrientA(settings.backendBaseUrl),
      pendingMessage:
          'Nutrient A command sent. Waiting for device confirmation.',
    );
  }

  Future<void> doseNutrientB() async {
    if (settings.usesLocalNetwork) {
      await _runLocalCommand(
        type: CommandType.nutrientB,
        action: () => _apiService.doseLocalNutrientB(
          settings.localDeviceBaseUrl,
        ),
      );
      return;
    }

    await _runCommand(
      type: CommandType.nutrientB,
      action: () => _apiService.doseNutrientB(settings.backendBaseUrl),
      pendingMessage:
          'Nutrient B command sent. Waiting for device confirmation.',
    );
  }

  Future<void> configureWifi({
    required String ssid,
    required String password,
  }) async {
    try {
      await _apiService.configureWifi(ssid: ssid, password: password);
      lastActionMessage = 'WiFi credentials sent to the controller.';
    } catch (_) {
      lastActionMessage = 'Request failed. Check the controller connection.';
      rethrow;
    } finally {
      update(['control']);
    }
  }

  Future<void> startWifiProvisioning({
    required String homeSsid,
    required String homePassword,
  }) async {
    final provisioningResult = await _provisioningService.connectToDeviceAp(
      ssid: setupAccessPointSsid,
      password: setupAccessPointPassword,
    );

    if (!provisioningResult.isConnected) {
      lastActionMessage = switch (provisioningResult.code) {
        ProvisioningResultCode.unsupportedAndroidVersion =>
          'Automatic setup is unavailable on this Android version. Join the controller Wi-Fi manually.',
        ProvisioningResultCode.userDenied =>
          'Android did not connect to the controller Wi-Fi.',
        ProvisioningResultCode.connectionTimeout =>
          'Timed out waiting for the controller Wi-Fi.',
        ProvisioningResultCode.connectionFailed => provisioningResult.message ??
            'Unable to connect to the controller Wi-Fi.',
        ProvisioningResultCode.connected => lastActionMessage,
      };
      update(['control']);
      throw Exception(lastActionMessage);
    }

    try {
      await _apiService.configureWifi(
        ssid: homeSsid,
        password: homePassword,
      );
      lastActionMessage =
          'WiFi credentials sent to the controller. Device is joining your network.';
    } catch (_) {
      lastActionMessage = 'Request failed. Check the controller connection.';
      rethrow;
    } finally {
      await _provisioningService.disconnectFromDeviceAp();
      update(['control']);
    }
  }

  Future<void> _loadSettings() async {
    settings = _settingsService.loadSettings();
    update(['settings']);
    await _loadRuntime();
  }

  Future<void> _loadProvisioningSupport() async {
    isAutoProvisioningSupported =
        await _provisioningService.isAutoProvisioningSupported();
    update(['control']);
  }

  Future<void> _loadRuntime() async {
    if (!hasActiveTransportConfigured) {
      _resetRuntimeState();
      update(['dashboard', 'control', 'settings']);
      return;
    }

    await refreshStatus(showLoading: true);
    if (settings.usesLocalNetwork) {
      _startLocalRefreshTimer();
    } else {
      _connectEventStream();
    }
  }

  void _resetRuntimeState() {
    sensorData = const SensorData();
    deviceState = const DeviceState();
    runtimeStatus = const RuntimeStatus();
    ecHistory = const HydroEcHistory(periodMs: 0, windowMs: 0, ecValues: []);
    isLoadingStatus = false;
    statusMessage = settings.usesLocalNetwork
        ? 'Set a local ESP32 URL in Settings.'
        : 'Set a backend URL in Settings.';
  }

  Future<void> _clearConnectionState() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _localRefreshTimer?.cancel();
    _localRefreshTimer = null;
    _reconnectAttempt = 0;
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    _pendingCommandRequestIds.clear();
  }

  void _connectEventStream() {
    if (!hasBackendConfigured || settings.usesLocalNetwork) {
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _eventSubscription?.cancel();

    runtimeStatus = runtimeStatus.copyWith(
      isBackendReachable: true,
      isStreamConnected: true,
    );
    _recomputeStatusMessage();
    update(['dashboard', 'control', 'settings']);

    _eventSubscription =
        _apiService.openEventStream(settings.backendBaseUrl).listen(
              _handleSseEvent,
              onError: _handleSseDisconnect,
              onDone: _handleSseDisconnect,
              cancelOnError: true,
            );
  }

  void _handleSseEvent(HydroSseEvent event) {
    runtimeStatus = runtimeStatus.copyWith(
      isBackendReachable: true,
      isStreamConnected: true,
    );
    _reconnectAttempt = 0;

    switch (event.name) {
      case 'snapshot':
        _applySnapshot(
          HydroStatusSnapshot.fromBackendPayload(
            event.payload,
            isStreamConnected: true,
          ),
        );
        break;
      case 'telemetry':
        _applyTelemetryDelta(event.payload);
        break;
      case 'state':
        _applyStateDelta(event.payload);
        break;
      case 'availability':
        runtimeStatus = runtimeStatus.copyWith(
          isDeviceOnline: event.payload['online'] as bool?,
        );
        break;
      case 'broker-status':
        break;
      case 'alarm':
        break;
      case 'ec-history':
        _applyEcHistoryDelta(event.payload);
        break;
      case 'command-result':
        _handleCommandResult(event.payload);
        break;
      default:
        break;
    }

    _recomputeStatusMessage();
    update(['dashboard', 'control', 'settings']);
  }

  void _handleSseDisconnect([Object? _]) {
    if (!hasBackendConfigured || settings.usesLocalNetwork) {
      return;
    }

    runtimeStatus = runtimeStatus.copyWith(isStreamConnected: false);
    _recomputeStatusMessage();
    update(['dashboard', 'control', 'settings']);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectTimer != null ||
        !hasBackendConfigured ||
        settings.usesLocalNetwork) {
      return;
    }

    final delaySeconds = math.min(1 << _reconnectAttempt, 30);
    _reconnectAttempt += 1;
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _reconnectTimer = null;
      _connectEventStream();
    });
  }

  void _startLocalRefreshTimer() {
    if (!enableAutoRefresh || !settings.usesLocalNetwork) {
      return;
    }

    _localRefreshTimer?.cancel();
    final intervalSeconds =
        settings.refreshInterval > 0 ? settings.refreshInterval : 2;
    _localRefreshTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) => refreshStatus(),
    );
  }

  void setTargetEcA(String value) {
    targetEcA = _parseTargetEc(value, targetEcA);
  }

  void setTargetEcB(String value) {
    targetEcB = _parseTargetEc(value, targetEcB);
  }

  void setTargetEcAb(String value) {
    targetEcAb = _parseTargetEc(value, targetEcAb);
  }

  Future<void> togglePrimeA() {
    if (settings.usesLocalNetwork) {
      return _runLocalToggle(type: CommandType.primeA, device: 'prime_a');
    }

    return _runCommand(
      type: CommandType.primeA,
      action: () => _apiService.togglePrimeA(settings.backendBaseUrl),
      pendingMessage: 'Prime line A command sent.',
    );
  }

  Future<void> togglePrimeB() {
    if (settings.usesLocalNetwork) {
      return _runLocalToggle(type: CommandType.primeB, device: 'prime_b');
    }

    return _runCommand(
      type: CommandType.primeB,
      action: () => _apiService.togglePrimeB(settings.backendBaseUrl),
      pendingMessage: 'Prime line B command sent.',
    );
  }

  Future<void> startShotDoseA() {
    if (settings.usesLocalNetwork) {
      return _runLocalToggle(
          type: CommandType.shotDoseA, device: 'shot_dose_a');
    }

    return _runCommand(
      type: CommandType.shotDoseA,
      action: () => _apiService.startShotDoseA(settings.backendBaseUrl),
      pendingMessage: 'Shot dose A command sent.',
    );
  }

  Future<void> startShotDoseB() {
    if (settings.usesLocalNetwork) {
      return _runLocalToggle(
          type: CommandType.shotDoseB, device: 'shot_dose_b');
    }

    return _runCommand(
      type: CommandType.shotDoseB,
      action: () => _apiService.startShotDoseB(settings.backendBaseUrl),
      pendingMessage: 'Shot dose B command sent.',
    );
  }

  Future<void> toggleTargetDoseA() {
    if (!settings.usesLocalNetwork) {
      return _runCommand(
        type: CommandType.targetDoseA,
        action: () => _apiService.toggleTargetDoseA(
          settings.backendBaseUrl,
          targetEcA,
        ),
        pendingMessage: 'Target dose A command sent.',
      );
    }

    return _runLocalToggle(
      type: CommandType.targetDoseA,
      device: 'target_dose_a',
      concentration: targetEcA,
    );
  }

  Future<void> toggleTargetDoseB() {
    if (!settings.usesLocalNetwork) {
      return _runCommand(
        type: CommandType.targetDoseB,
        action: () => _apiService.toggleTargetDoseB(
          settings.backendBaseUrl,
          targetEcB,
        ),
        pendingMessage: 'Target dose B command sent.',
      );
    }

    return _runLocalToggle(
      type: CommandType.targetDoseB,
      device: 'target_dose_b',
      concentration: targetEcB,
    );
  }

  Future<void> toggleTargetDoseAb() {
    if (!settings.usesLocalNetwork) {
      return _runCommand(
        type: CommandType.targetDoseAb,
        action: () => _apiService.toggleTargetDoseAb(
          settings.backendBaseUrl,
          targetEcAb,
        ),
        pendingMessage: 'Target dose A+B command sent.',
      );
    }

    return _runLocalToggle(
      type: CommandType.targetDoseAb,
      device: 'target_dose_ab',
      concentration: targetEcAb,
    );
  }

  void _applySnapshot(HydroStatusSnapshot snapshot) {
    sensorData = snapshot.sensorData;
    deviceState = snapshot.deviceState;
    targetEcA = snapshot.deviceState.targetEcA ?? targetEcA;
    targetEcB = snapshot.deviceState.targetEcB ?? targetEcB;
    targetEcAb = snapshot.deviceState.targetEcAb ?? targetEcAb;
    runtimeStatus = snapshot.runtimeStatus.copyWith(
      isStreamConnected: runtimeStatus.isStreamConnected,
    );
    _recomputeStatusMessage();
  }

  Future<void> _refreshEcHistory() async {
    if (!hasActiveTransportConfigured) {
      return;
    }

    try {
      ecHistory = settings.usesLocalNetwork
          ? await _apiService.fetchLocalEcHistory(settings.localDeviceBaseUrl)
          : await _apiService.fetchEcHistory(settings.backendBaseUrl);
    } catch (_) {
      // EC history is secondary to control/status, so keep the last chart data.
    }
  }

  void _applyTelemetryDelta(Map<String, dynamic> payload) {
    final field = payload['field'] as String?;
    final value = payload['value'];
    if (field == null) {
      return;
    }

    sensorData = switch (field) {
      'ph' => sensorData.copyWith(ph: _toDouble(value)),
      'ec' => sensorData.copyWith(ec: _toDouble(value)),
      'waterTemperature' => sensorData.copyWith(
          waterTemperature: _toDouble(value),
        ),
      'waterLevel' => sensorData.copyWith(waterLevel: _toDouble(value)),
      'humidity' => sensorData.copyWith(humidity: _toDouble(value)),
      'tds' => sensorData.copyWith(tds: _toDouble(value)),
      'distance' => sensorData.copyWith(distance: _toDouble(value)),
      _ => sensorData,
    };
  }

  void _applyStateDelta(Map<String, dynamic> payload) {
    final field = payload['field'] as String?;
    final value = payload['value'];
    if (field == null) {
      return;
    }

    if (field == 'pumpOn') {
      deviceState = deviceState.copyWith(pumpOn: value as bool?);
    } else if (field == 'lightOn') {
      deviceState = deviceState.copyWith(lightOn: value as bool?);
    } else if (field == 'primeAOn') {
      deviceState = deviceState.copyWith(primeAOn: value as bool?);
    } else if (field == 'primeBOn') {
      deviceState = deviceState.copyWith(primeBOn: value as bool?);
    } else if (field == 'targetDoseAOn') {
      deviceState = deviceState.copyWith(targetDoseAOn: value as bool?);
    } else if (field == 'targetDoseBOn') {
      deviceState = deviceState.copyWith(targetDoseBOn: value as bool?);
    } else if (field == 'targetDoseAbOn') {
      deviceState = deviceState.copyWith(targetDoseAbOn: value as bool?);
    } else if (field == 'shotDoseAOn') {
      deviceState = deviceState.copyWith(shotDoseAOn: value as bool?);
    } else if (field == 'shotDoseBOn') {
      deviceState = deviceState.copyWith(shotDoseBOn: value as bool?);
    } else if (field == 'liquidAWet') {
      deviceState = deviceState.copyWith(liquidAWet: value as bool?);
    } else if (field == 'liquidBWet') {
      deviceState = deviceState.copyWith(liquidBWet: value as bool?);
    } else if (field == 'targetEcA') {
      final nextValue = _toDouble(value);
      deviceState = deviceState.copyWith(targetEcA: nextValue);
      targetEcA = nextValue ?? targetEcA;
    } else if (field == 'targetEcB') {
      final nextValue = _toDouble(value);
      deviceState = deviceState.copyWith(targetEcB: nextValue);
      targetEcB = nextValue ?? targetEcB;
    } else if (field == 'targetEcAb') {
      final nextValue = _toDouble(value);
      deviceState = deviceState.copyWith(targetEcAb: nextValue);
      targetEcAb = nextValue ?? targetEcAb;
    }

    final requestId = payload['requestId'] as String?;
    if (requestId != null) {
      final type = _matchPendingCommand(requestId);
      if (type != null) {
        _pendingCommandRequestIds.remove(type);
        lastActionMessage = '${_commandLabel(type)} updated.';
      }
    }
  }

  void _applyEcHistoryDelta(Map<String, dynamic> payload) {
    ecHistory = HydroEcHistory.fromPayload(payload);
  }

  void _handleCommandResult(Map<String, dynamic> payload) {
    final requestId = payload['requestId'] as String?;
    final status = payload['status'] as String?;
    if (requestId == null || status == null) {
      return;
    }

    final type = _matchPendingCommand(requestId);
    if (type == null) {
      return;
    }

    _pendingCommandRequestIds.remove(type);
    if (status == 'timeout') {
      lastActionMessage = '${_commandLabel(type)} command timed out.';
    } else if (status == 'failed') {
      lastActionMessage = '${_commandLabel(type)} command failed.';
    } else if (status == 'succeeded') {
      lastActionMessage = '${_commandLabel(type)} updated.';
    }
  }

  Future<void> _runCommand({
    required CommandType type,
    required Future<HydroCommandAccepted> Function() action,
    required String pendingMessage,
  }) async {
    if (!hasBackendConfigured) {
      statusMessage = 'Set a backend URL in Settings.';
      update(['dashboard', 'control', 'settings']);
      return;
    }

    lastActionMessage = null;
    update(['control']);

    try {
      final accepted = await action();
      _pendingCommandRequestIds[type] = accepted.requestId;
      lastActionMessage = pendingMessage;
    } catch (_) {
      lastActionMessage = 'Unable to send command to the backend.';
    } finally {
      update(['dashboard', 'control', 'settings']);
    }
  }

  Future<void> _runLocalCommand({
    required CommandType type,
    required Future<void> Function() action,
  }) async {
    if (!hasLocalDeviceConfigured) {
      statusMessage = 'Set a local ESP32 URL in Settings.';
      update(['dashboard', 'control', 'settings']);
      return;
    }

    lastActionMessage = null;
    _pendingCommandRequestIds[type] = 'local';
    update(['control']);

    try {
      await action();
      lastActionMessage = '${_commandLabel(type)} updated.';
      await refreshStatus();
    } catch (_) {
      lastActionMessage = 'Unable to reach local ESP32.';
      runtimeStatus = runtimeStatus.copyWith(
        isBackendReachable: false,
        isDeviceOnline: false,
        isStreamConnected: false,
      );
      _recomputeStatusMessage();
    } finally {
      _pendingCommandRequestIds.remove(type);
      update(['dashboard', 'control', 'settings']);
    }
  }

  Future<void> _runLocalToggle({
    required CommandType type,
    required String device,
    double? concentration,
  }) {
    return _runLocalCommand(
      type: type,
      action: () => _apiService.toggleLocalDevice(
        settings.localDeviceBaseUrl,
        device,
        concentration: concentration,
      ),
    );
  }

  CommandType? _matchPendingCommand(String requestId) {
    for (final entry in _pendingCommandRequestIds.entries) {
      if (entry.value == requestId) {
        return entry.key;
      }
    }
    return null;
  }

  String _commandLabel(CommandType type) {
    return switch (type) {
      CommandType.pump => 'Pump',
      CommandType.light => 'Grow light',
      CommandType.nutrientA => 'Nutrient A',
      CommandType.nutrientB => 'Nutrient B',
      CommandType.primeA => 'Prime line A',
      CommandType.primeB => 'Prime line B',
      CommandType.targetDoseA => 'Target dose A',
      CommandType.targetDoseB => 'Target dose B',
      CommandType.targetDoseAb => 'Target dose A+B',
      CommandType.shotDoseA => 'Shot dose A',
      CommandType.shotDoseB => 'Shot dose B',
    };
  }

  double _parseTargetEc(String value, double fallback) {
    final parsed = double.tryParse(value);
    if (parsed == null) {
      return fallback;
    }
    return parsed.clamp(0.0, 5.0).toDouble();
  }

  void _recomputeStatusMessage() {
    if (!hasActiveTransportConfigured) {
      statusMessage = settings.usesLocalNetwork
          ? 'Set a local ESP32 URL in Settings.'
          : 'Set a backend URL in Settings.';
      return;
    }

    if (settings.usesLocalNetwork) {
      if (!runtimeStatus.isBackendReachable ||
          runtimeStatus.isDeviceOnline == false) {
        statusMessage =
            'Unable to reach local ESP32 at ${settings.localDeviceBaseUrl}.';
        return;
      }

      if (runtimeStatus.isDeviceOnline == null) {
        statusMessage = 'Waiting for local ESP32 status.';
        return;
      }

      statusMessage = null;
      return;
    }

    if (!runtimeStatus.isBackendReachable) {
      statusMessage = 'Unable to reach backend at ${settings.backendBaseUrl}.';
      return;
    }

    if (!runtimeStatus.isStreamConnected) {
      statusMessage = 'Live updates disconnected. Reconnecting...';
      return;
    }

    if (runtimeStatus.isDeviceOnline == false) {
      statusMessage = 'Device is offline.';
      return;
    }

    if (runtimeStatus.isDeviceOnline == null) {
      statusMessage = 'Waiting for device status from the backend.';
      return;
    }

    if (runtimeStatus.isTelemetryStale || runtimeStatus.isStateStale) {
      statusMessage = 'Live device data may be stale.';
      return;
    }

    statusMessage = null;
  }

  double? _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }

  @override
  void onClose() {
    _clearConnectionState();
    super.onClose();
  }
}
