import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:home_fi/app/models/device_state.dart';
import 'package:home_fi/app/models/runtime_status.dart';
import 'package:home_fi/app/models/sensor_data.dart';

class HydroStatusSnapshot {
  const HydroStatusSnapshot({
    required this.sensorData,
    required this.deviceState,
    required this.runtimeStatus,
  });

  final SensorData sensorData;
  final DeviceState deviceState;
  final RuntimeStatus runtimeStatus;

  factory HydroStatusSnapshot.fromBackendPayload(
    Map<String, dynamic> payload, {
    bool isStreamConnected = false,
  }) {
    final availability = HydroApiService._readMap(payload, 'availability');
    final sensors = HydroApiService._readMap(payload, 'sensors');
    final deviceState = HydroApiService._readMap(payload, 'deviceState');
    final freshness = HydroApiService._readMap(payload, 'freshness');

    return HydroStatusSnapshot(
      sensorData: SensorData(
        ph: HydroApiService._readDouble(sensors, ['ph']),
        ec: HydroApiService._readDouble(sensors, ['ec']),
        waterTemperature:
            HydroApiService._readDouble(sensors, ['waterTemperature']),
        waterLevel: HydroApiService._readDouble(sensors, ['waterLevel']),
      ),
      deviceState: DeviceState(
        pumpOn: HydroApiService._readBool(deviceState, ['pumpOn']),
        lightOn: HydroApiService._readBool(deviceState, ['lightOn']),
      ),
      runtimeStatus: RuntimeStatus(
        isBackendReachable: true,
        isDeviceOnline: HydroApiService._readBool(availability, ['online']),
        isStreamConnected: isStreamConnected,
        isTelemetryStale:
            HydroApiService._readBool(freshness, ['staleTelemetry']) ?? false,
        isStateStale:
            HydroApiService._readBool(freshness, ['staleState']) ?? false,
      ),
    );
  }

  factory HydroStatusSnapshot.fromLocalStatusPayload(
    Map<String, dynamic> payload,
  ) {
    return HydroStatusSnapshot(
      sensorData: SensorData(
        ph: HydroApiService._readDouble(payload, ['ph']),
        ec: HydroApiService._readDouble(payload, ['ec']),
        waterTemperature: HydroApiService._readDouble(
          payload,
          ['waterTemperature', 'water_temperature', 'temp', 'temperature'],
        ),
        waterLevel: HydroApiService._readDouble(
          payload,
          ['waterLevel', 'water_level', 'level'],
        ),
        humidity: HydroApiService._readDouble(payload, ['humidity']),
        tds: HydroApiService._readDouble(payload, ['tds']),
        distance: HydroApiService._readDouble(payload, ['distance']),
      ),
      deviceState: DeviceState(
        pumpOn: HydroApiService._readBool(
          payload,
          ['pumpOn', 'pump_on', 'pump'],
        ),
        lightOn: HydroApiService._readBool(
          payload,
          ['lightOn', 'light_on', 'light'],
        ),
        primeAOn: HydroApiService._readBool(payload, ['prime_a']),
        primeBOn: HydroApiService._readBool(payload, ['prime_b']),
        targetDoseAOn: HydroApiService._readBool(payload, ['target_dose_a']),
        targetDoseBOn: HydroApiService._readBool(payload, ['target_dose_b']),
        targetDoseAbOn: HydroApiService._readBool(payload, ['target_dose_ab']),
        shotDoseAOn: HydroApiService._readBool(payload, ['shot_dose_a']),
        shotDoseBOn: HydroApiService._readBool(payload, ['shot_dose_b']),
        liquidAWet: HydroApiService._readBool(payload, ['liquid1']),
        liquidBWet: HydroApiService._readBool(payload, ['liquid2']),
        targetEcA: HydroApiService._readDouble(payload, ['target_ec_a']),
        targetEcB: HydroApiService._readDouble(payload, ['target_ec_b']),
        targetEcAb: HydroApiService._readDouble(payload, ['target_ec_ab']),
      ),
      runtimeStatus: const RuntimeStatus(
        isBackendReachable: true,
        isDeviceOnline: true,
        isStreamConnected: false,
      ),
    );
  }
}

class HydroCommandAccepted {
  const HydroCommandAccepted({
    required this.requestId,
    required this.status,
  });

  final String requestId;
  final String status;
}

class HydroSseEvent {
  const HydroSseEvent({
    required this.name,
    required this.payload,
  });

  final String name;
  final Map<String, dynamic> payload;
}

class HydroEcHistory {
  const HydroEcHistory({
    required this.periodMs,
    required this.windowMs,
    required this.ecValues,
  });

  final int periodMs;
  final int windowMs;
  final List<double> ecValues;

  factory HydroEcHistory.fromPayload(Map<String, dynamic> payload) {
    final values = payload['ec'];
    return HydroEcHistory(
      periodMs: HydroApiService._readInt(payload, ['period_ms']) ?? 0,
      windowMs: HydroApiService._readInt(payload, ['window_ms']) ?? 0,
      ecValues: values is List
          ? values
              .map((value) => value is num
                  ? value.toDouble()
                  : double.tryParse(value.toString()))
              .whereType<double>()
              .toList()
          : const [],
    );
  }
}

class LocalMaintenanceHealth {
  const LocalMaintenanceHealth({
    required this.isReachable,
    required this.mode,
    required this.baseUrl,
    this.details = const {},
  });

  final bool isReachable;
  final String mode;
  final String baseUrl;
  final Map<String, dynamic> details;
}

class HydroApiService {
  HydroApiService({
    http.Client? client,
    Duration? requestTimeout,
  })  : _client = client ?? http.Client(),
        _requestTimeout = requestTimeout ?? const Duration(seconds: 4);

  final http.Client _client;
  final Duration _requestTimeout;

  Future<HydroStatusSnapshot> fetchStatus(String backendBaseUrl) async {
    final response = await _client
        .get(_buildBackendUri(backendBaseUrl, '/api/device/status'))
        .timeout(_requestTimeout);
    _ensureSuccess(response);

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return HydroStatusSnapshot.fromBackendPayload(payload);
  }

  Future<HydroStatusSnapshot> fetchLocalStatus(String baseUrl) async {
    final response = await _client
        .get(_buildLocalUri(baseUrl, '/api/status'))
        .timeout(_requestTimeout);
    _ensureSuccess(response);

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return HydroStatusSnapshot.fromLocalStatusPayload(payload);
  }

  Future<HydroEcHistory> fetchLocalEcHistory(String baseUrl) async {
    final response = await _client
        .get(_buildLocalUri(baseUrl, '/api/ec_history'))
        .timeout(_requestTimeout);
    _ensureSuccess(response);

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return HydroEcHistory.fromPayload(payload);
  }

  Stream<HydroSseEvent> openEventStream(String backendBaseUrl) async* {
    final request = http.Request(
      'GET',
      _buildBackendUri(backendBaseUrl, '/api/device/events'),
    );
    request.headers['Accept'] = 'text/event-stream';

    final response = await _client.send(request).timeout(_requestTimeout);
    _ensureStreamSuccess(response);

    String? currentEventName;
    final currentData = StringBuffer();

    await for (final line in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.isEmpty) {
        if (currentEventName != null && currentData.isNotEmpty) {
          yield HydroSseEvent(
            name: currentEventName,
            payload: jsonDecode(currentData.toString()) as Map<String, dynamic>,
          );
        }
        currentEventName = null;
        currentData.clear();
        continue;
      }

      if (line.startsWith('event:')) {
        currentEventName = line.substring(6).trim();
        continue;
      }

      if (line.startsWith('data:')) {
        if (currentData.isNotEmpty) {
          currentData.write('\n');
        }
        currentData.write(line.substring(5).trim());
      }
    }
  }

  Future<HydroCommandAccepted> setPump(String backendBaseUrl, bool on) {
    return _postCommand(
      backendBaseUrl,
      '/api/device/commands/pump',
      {'on': on},
    );
  }

  Future<HydroCommandAccepted> setGrowLight(String backendBaseUrl, bool on) {
    return _postCommand(
      backendBaseUrl,
      '/api/device/commands/light',
      {'on': on},
    );
  }

  Future<HydroCommandAccepted> doseNutrientA(String backendBaseUrl) {
    return _postCommand(
      backendBaseUrl,
      '/api/device/commands/nutrient/a',
      {'dose': true},
    );
  }

  Future<HydroCommandAccepted> doseNutrientB(String backendBaseUrl) {
    return _postCommand(
      backendBaseUrl,
      '/api/device/commands/nutrient/b',
      {'dose': true},
    );
  }

  Future<void> setLocalPump(String baseUrl, bool on) {
    return toggleLocalDevice(baseUrl, 'pump');
  }

  Future<void> setLocalGrowLight(String baseUrl, bool on) {
    return toggleLocalDevice(baseUrl, 'light');
  }

  Future<void> doseLocalNutrientA(String baseUrl) {
    return toggleLocalDevice(baseUrl, 'shot_dose_a');
  }

  Future<void> doseLocalNutrientB(String baseUrl) {
    return toggleLocalDevice(baseUrl, 'shot_dose_b');
  }

  Future<void> toggleLocalDevice(
    String baseUrl,
    String device, {
    double? concentration,
  }) async {
    final query = <String, String>{'device': device};
    if (concentration != null) {
      query['concentration'] = concentration.toStringAsFixed(1);
    }
    final response = await _client
        .post(_buildLocalUri(baseUrl, '/api/toggle', query))
        .timeout(_requestTimeout);
    _ensureSuccess(response);
  }

  Future<LocalMaintenanceHealth> fetchLocalHealth(String baseUrl) async {
    final response = await _client
        .get(_buildLocalUri(baseUrl, '/health'))
        .timeout(_requestTimeout);
    _ensureSuccess(response);

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return LocalMaintenanceHealth(
      isReachable: true,
      mode: payload['mode'] as String? ?? 'maintenance',
      baseUrl: baseUrl,
      details: payload,
    );
  }

  Future<Map<String, dynamic>?> fetchLocalConfig(String baseUrl) async {
    final response = await _client
        .get(_buildLocalUri(baseUrl, '/config'))
        .timeout(_requestTimeout);
    _ensureSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> fetchLocalDebugStatus(String baseUrl) async {
    final response = await _client
        .get(_buildLocalUri(baseUrl, '/debug/status'))
        .timeout(_requestTimeout);
    _ensureSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> configureWifi({
    required String ssid,
    required String password,
  }) async {
    final response = await _client
        .post(
          Uri.parse('http://192.168.4.1/wifi'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'ssid': ssid, 'password': password}),
        )
        .timeout(_requestTimeout);
    _ensureSuccess(response);
  }

  Future<HydroCommandAccepted> _postCommand(
    String backendBaseUrl,
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client
        .post(
          _buildBackendUri(backendBaseUrl, path),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(_requestTimeout);
    _ensureSuccess(response);

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return HydroCommandAccepted(
      requestId: payload['requestId'] as String,
      status: payload['status'] as String? ?? 'accepted',
    );
  }

  Uri _buildBackendUri(String backendBaseUrl, String path) {
    final normalizedBaseUrl = backendBaseUrl.endsWith('/')
        ? backendBaseUrl.substring(0, backendBaseUrl.length - 1)
        : backendBaseUrl;
    return Uri.parse('$normalizedBaseUrl$path');
  }

  Uri _buildLocalUri(
    String baseUrl,
    String path, [
    Map<String, String>? queryParameters,
  ]) {
    final normalizedBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final uri = Uri.parse('$normalizedBaseUrl$path');
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }
    return uri.replace(queryParameters: queryParameters);
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw Exception('Request failed with status ${response.statusCode}');
  }

  void _ensureStreamSuccess(http.StreamedResponse response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw Exception('Request failed with status ${response.statusCode}');
  }

  static Map<String, dynamic> _readMap(
    Map<String, dynamic> payload,
    String key,
  ) {
    final value = payload[key];
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return const {};
  }

  static double? _readDouble(Map<String, dynamic> payload, List<String> keys) {
    for (final key in keys) {
      final value = payload[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        return double.tryParse(value);
      }
    }
    return null;
  }

  static int? _readInt(Map<String, dynamic> payload, List<String> keys) {
    for (final key in keys) {
      final value = payload[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        return int.tryParse(value);
      }
    }
    return null;
  }

  static bool? _readBool(Map<String, dynamic> payload, List<String> keys) {
    for (final key in keys) {
      final value = payload[key];
      if (value is bool) {
        return value;
      }
      if (value is num) {
        return value != 0;
      }
      if (value is String) {
        final normalized = value.toLowerCase();
        if (normalized == 'true' || normalized == 'on' || normalized == '1') {
          return true;
        }
        if (normalized == 'false' || normalized == 'off' || normalized == '0') {
          return false;
        }
      }
    }
    return null;
  }
}
