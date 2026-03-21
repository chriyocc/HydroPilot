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
import 'package:home_fi/app/services/hydro_api_service.dart';
import 'package:home_fi/app/services/settings_service.dart';

enum CommandType {
  pump,
  light,
  nutrientA,
  nutrientB,
}

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
  final Map<CommandType, String> _pendingCommandRequestIds = {};

  StreamSubscription<HydroSseEvent>? _eventSubscription;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;

  int get currentIndex => _currentIndex.value;
  bool get hasBackendConfigured => settings.backendBaseUrl.trim().isNotEmpty;

  AppSettings settings = AppSettings.defaults();
  SensorData sensorData = const SensorData();
  DeviceState deviceState = const DeviceState();
  RuntimeStatus runtimeStatus = const RuntimeStatus();
  bool isLoadingStatus = true;
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

  bool isCommandPending(CommandType type) {
    return _pendingCommandRequestIds.containsKey(type);
  }

  Future<void> refreshStatus({bool showLoading = false}) async {
    if (!hasBackendConfigured) {
      _resetRuntimeState();
      update(['dashboard', 'control', 'settings']);
      return;
    }

    if (showLoading) {
      isLoadingStatus = true;
      update(['dashboard', 'control']);
    }

    try {
      final snapshot = await _apiService.fetchStatus(settings.backendBaseUrl);
      _applySnapshot(snapshot);
    } catch (_) {
      runtimeStatus = runtimeStatus.copyWith(
        isBackendReachable: false,
        isStreamConnected: false,
      );
      _recomputeStatusMessage();
    } finally {
      isLoadingStatus = false;
      update(['dashboard', 'control']);
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
    await _runCommand(
      type: CommandType.pump,
      action: () => _apiService.setPump(settings.backendBaseUrl, value),
      pendingMessage: 'Pump command sent. Waiting for device confirmation.',
    );
  }

  Future<void> toggleGrowLight(bool value) async {
    await _runCommand(
      type: CommandType.light,
      action: () => _apiService.setGrowLight(settings.backendBaseUrl, value),
      pendingMessage:
          'Grow light command sent. Waiting for device confirmation.',
    );
  }

  Future<void> doseNutrientA() async {
    await _runCommand(
      type: CommandType.nutrientA,
      action: () => _apiService.doseNutrientA(settings.backendBaseUrl),
      pendingMessage:
          'Nutrient A command sent. Waiting for device confirmation.',
    );
  }

  Future<void> doseNutrientB() async {
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

  Future<void> _loadSettings() async {
    settings = _settingsService.loadSettings();
    update(['settings']);
    await _loadRuntime();
  }

  Future<void> _loadRuntime() async {
    if (!hasBackendConfigured) {
      _resetRuntimeState();
      update(['dashboard', 'control']);
      return;
    }

    await refreshStatus(showLoading: true);
    _connectEventStream();
  }

  void _resetRuntimeState() {
    sensorData = const SensorData();
    deviceState = const DeviceState();
    runtimeStatus = const RuntimeStatus();
    isLoadingStatus = false;
    statusMessage = 'Set a backend URL in Settings.';
  }

  Future<void> _clearConnectionState() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    _pendingCommandRequestIds.clear();
  }

  void _connectEventStream() {
    if (!hasBackendConfigured) {
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
    update(['dashboard', 'control']);

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
      case 'command-result':
        _handleCommandResult(event.payload);
        break;
      default:
        break;
    }

    _recomputeStatusMessage();
    update(['dashboard', 'control']);
  }

  void _handleSseDisconnect([Object? _]) {
    if (!hasBackendConfigured) {
      return;
    }

    runtimeStatus = runtimeStatus.copyWith(isStreamConnected: false);
    _recomputeStatusMessage();
    update(['dashboard', 'control']);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectTimer != null || !hasBackendConfigured) {
      return;
    }

    final delaySeconds = math.min(1 << _reconnectAttempt, 30);
    _reconnectAttempt += 1;
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _reconnectTimer = null;
      _connectEventStream();
    });
  }

  void _applySnapshot(HydroStatusSnapshot snapshot) {
    sensorData = snapshot.sensorData;
    deviceState = snapshot.deviceState;
    runtimeStatus = snapshot.runtimeStatus.copyWith(
      isStreamConnected: runtimeStatus.isStreamConnected,
    );
    _recomputeStatusMessage();
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
      update(['dashboard', 'control']);
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
      update(['dashboard', 'control']);
    }
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
    };
  }

  void _recomputeStatusMessage() {
    if (!hasBackendConfigured) {
      statusMessage = 'Set a backend URL in Settings.';
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
