import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:home_fi/app/models/device_state.dart';
import 'package:home_fi/app/models/sensor_data.dart';

class HydroStatusSnapshot {
  const HydroStatusSnapshot({
    required this.sensorData,
    required this.deviceState,
  });

  final SensorData sensorData;
  final DeviceState deviceState;
}

class HydroApiService {
  HydroApiService({
    http.Client? client,
    Duration? requestTimeout,
  })  : _client = client ?? http.Client(),
        _requestTimeout = requestTimeout ?? const Duration(seconds: 4);

  final http.Client _client;
  final Duration _requestTimeout;

  Future<HydroStatusSnapshot> fetchStatus(String deviceIp) async {
    final response = await _client
        .get(_buildUri(deviceIp, '/status'))
        .timeout(_requestTimeout);
    _ensureSuccess(response);

    final payload = jsonDecode(response.body) as Map<String, dynamic>;

    return HydroStatusSnapshot(
      sensorData: SensorData(
        ph: _readDouble(payload, ['ph']),
        ec: _readDouble(payload, ['ec']),
        waterTemperature: _readDouble(
          payload,
          ['waterTemperature', 'water_temperature', 'temp', 'temperature'],
        ),
        waterLevel: _readDouble(
          payload,
          ['waterLevel', 'water_level', 'level'],
        ),
      ),
      deviceState: DeviceState(
        pumpOn: _readBool(payload, ['pumpOn', 'pump_on', 'pump']),
        lightOn: _readBool(payload, ['lightOn', 'light_on', 'light']),
      ),
    );
  }

  Future<void> setPump(String deviceIp, bool on) {
    return _postJson(deviceIp, '/control/pump', {'on': on});
  }

  Future<void> setGrowLight(String deviceIp, bool on) {
    return _postJson(deviceIp, '/control/light', {'on': on});
  }

  Future<void> doseNutrientA(String deviceIp) {
    return _postJson(deviceIp, '/control/nutrient/a', {'dose': true});
  }

  Future<void> doseNutrientB(String deviceIp) {
    return _postJson(deviceIp, '/control/nutrient/b', {'dose': true});
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

  Future<void> _postJson(
    String deviceIp,
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client
        .post(
          _buildUri(deviceIp, path),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(_requestTimeout);
    _ensureSuccess(response);
  }

  Uri _buildUri(String deviceIp, String path) {
    return Uri.parse('http://$deviceIp$path');
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw Exception('Request failed with status ${response.statusCode}');
  }

  double? _readDouble(Map<String, dynamic> payload, List<String> keys) {
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

  bool? _readBool(Map<String, dynamic> payload, List<String> keys) {
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
        if (normalized == 'false' ||
            normalized == 'off' ||
            normalized == '0') {
          return false;
        }
      }
    }
    return null;
  }
}
