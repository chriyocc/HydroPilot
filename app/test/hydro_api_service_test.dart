import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:home_fi/app/services/hydro_api_service.dart';
import 'package:http/http.dart' as http;

void main() {
  test('fetchStatus parses backend device snapshot payload', () async {
    final service = HydroApiService(
      client: QueueHttpClient([
        http.Response(
          jsonEncode({
            'deviceId': 'device-1',
            'broker': {'connected': true, 'status': 'connected'},
            'availability': {'online': true, 'status': 'online'},
            'sensors': {
              'ph': 6.2,
              'ec': 1.8,
              'waterTemperature': 24.5,
              'waterLevel': 82,
            },
            'deviceState': {
              'pumpOn': true,
              'lightOn': false,
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
          }),
          200,
        ),
      ]),
    );

    final snapshot = await service.fetchStatus('http://localhost:3000');

    expect(snapshot.sensorData.ph, 6.2);
    expect(snapshot.sensorData.ec, 1.8);
    expect(snapshot.sensorData.waterTemperature, 24.5);
    expect(snapshot.sensorData.waterLevel, 82);
    expect(snapshot.deviceState.pumpOn, true);
    expect(snapshot.deviceState.lightOn, false);
    expect(snapshot.runtimeStatus.isBackendReachable, true);
    expect(snapshot.runtimeStatus.isDeviceOnline, true);
  });

  test('openEventStream parses backend SSE events', () async {
    final streamController = StreamController<List<int>>();
    final service = HydroApiService(
      client: QueueHttpClient.stream([
        http.StreamedResponse(
          streamController.stream,
          200,
          headers: {'content-type': 'text/event-stream'},
        ),
      ]),
    );

    final eventsFuture =
        service.openEventStream('http://localhost:3000').take(2).toList();

    streamController.add(
      utf8.encode(
        'event: availability\n'
        'data: {"deviceId":"device-1","online":true,"status":"online","ts":"2026-03-20T12:00:00.000Z"}\n\n'
        'event: command-result\n'
        'data: {"deviceId":"device-1","requestId":"req-1","status":"timeout","ts":"2026-03-20T12:00:01.000Z"}\n\n',
      ),
    );
    await streamController.close();
    final events = await eventsFuture;

    expect(events, hasLength(2));
    expect(events.first.name, 'availability');
    expect(events.first.payload['online'], true);
    expect(events.last.name, 'command-result');
    expect(events.last.payload['requestId'], 'req-1');
    expect(events.last.payload['status'], 'timeout');
  });

  test('fetchLocalStatus parses ESP32 status payload', () async {
    final client = QueueHttpClient([
      http.Response(
        jsonEncode({
          'light': false,
          'prime_a': true,
          'prime_b': false,
          'target_dose_a': false,
          'target_dose_b': false,
          'target_dose_ab': true,
          'shot_dose_a': false,
          'shot_dose_b': true,
          'target_ec_a': 1.2,
          'target_ec_b': 1.3,
          'target_ec_ab': 1.4,
          'temp': 24.8,
          'humidity': 62.5,
          'water': 79,
          'tds': 400,
          'ec': 1413,
          'distance': 120,
          'liquid1': true,
          'liquid2': false,
        }),
        200,
      ),
    ]);
    final service = HydroApiService(client: client);

    final snapshot = await service.fetchLocalStatus('http://192.168.1.50');

    expect(
      client.requests.single.url.toString(),
      'http://192.168.1.50/api/status',
    );
    expect(snapshot.sensorData.ec, 1413);
    expect(snapshot.sensorData.waterTemperature, 24.8);
    expect(snapshot.sensorData.humidity, 62.5);
    expect(snapshot.sensorData.waterLevel, 79);
    expect(snapshot.sensorData.tds, 400);
    expect(snapshot.sensorData.distance, 120);
    expect(snapshot.deviceState.lightOn, false);
    expect(snapshot.deviceState.primeAOn, true);
    expect(snapshot.deviceState.targetDoseAbOn, true);
    expect(snapshot.deviceState.shotDoseBOn, true);
    expect(snapshot.deviceState.liquidAWet, true);
    expect(snapshot.deviceState.targetEcAb, 1.4);
    expect(snapshot.runtimeStatus.isDeviceOnline, true);
    expect(snapshot.runtimeStatus.isStreamConnected, false);
  });

  test('local command helpers post to firmware webserver toggle endpoint',
      () async {
    final client = QueueHttpClient([
      http.Response('{"ok":true}', 200),
      http.Response('{"ok":true}', 200),
    ]);
    final service = HydroApiService(client: client);

    await service.setLocalPump('http://192.168.1.50', true);
    await service.toggleLocalDevice(
      'http://192.168.1.50',
      'target_dose_ab',
      concentration: 1.4,
    );

    expect(
      client.requests.map((request) => request.url.toString()),
      [
        'http://192.168.1.50/api/toggle?device=pump',
        'http://192.168.1.50/api/toggle?device=target_dose_ab&concentration=1.4',
      ],
    );
    expect(client.requests.first.method, 'POST');
  });

  test('remote routine command helpers post to backend command endpoints',
      () async {
    final client = QueueHttpClient([
      http.Response('{"requestId":"prime-1","status":"accepted"}', 202),
      http.Response('{"requestId":"target-1","status":"accepted"}', 202),
      http.Response('{"requestId":"shot-1","status":"accepted"}', 202),
    ]);
    final service = HydroApiService(client: client);

    await service.togglePrimeA('https://api2.yoyojun.site');
    await service.toggleTargetDoseAb('https://api2.yoyojun.site', 1.7);
    await service.startShotDoseB('https://api2.yoyojun.site');

    expect(
      client.requests.map((request) => request.url.toString()),
      [
        'https://api2.yoyojun.site/api/device/commands/prime/a',
        'https://api2.yoyojun.site/api/device/commands/target-dose/ab',
        'https://api2.yoyojun.site/api/device/commands/shot-dose/b',
      ],
    );
    expect(
      client.requests.map((request) => request.method),
      ['POST', 'POST', 'POST'],
    );
    expect(
      client.requests.map((request) => request is http.Request ? request.body : ''),
      [
        '{"toggle":true}',
        '{"concentration":1.7}',
        '{"start":true}',
      ],
    );
  });

  test('fetchLocalEcHistory parses firmware EC history payload', () async {
    final client = QueueHttpClient([
      http.Response(
        jsonEncode({
          'period_ms': 2000,
          'window_ms': 180000,
          'ec': [1200, 1300, 1413],
        }),
        200,
      ),
    ]);
    final service = HydroApiService(client: client);

    final history = await service.fetchLocalEcHistory('http://192.168.1.50');

    expect(
      client.requests.single.url.toString(),
      'http://192.168.1.50/api/ec_history',
    );
    expect(history.periodMs, 2000);
    expect(history.windowMs, 180000);
    expect(history.ecValues, [1200.0, 1300.0, 1413.0]);
  });

  test('fetchStatus times out when backend does not respond', () async {
    final service = HydroApiService(
      client: HangingHttpClient(),
      requestTimeout: const Duration(milliseconds: 50),
    );

    await expectLater(
      service.fetchStatus('http://localhost:3000'),
      throwsA(isA<TimeoutException>()),
    );
  });
}

class QueueHttpClient extends http.BaseClient {
  QueueHttpClient(List<http.Response> responses)
      : _streamedResponses = responses
            .map(
              (response) => http.StreamedResponse(
                Stream.value(utf8.encode(response.body)),
                response.statusCode,
                headers: response.headers,
              ),
            )
            .toList();

  QueueHttpClient.stream(List<http.StreamedResponse> streamedResponses)
      : _streamedResponses = streamedResponses;

  final List<http.StreamedResponse> _streamedResponses;
  final List<http.BaseRequest> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    if (_streamedResponses.isEmpty) {
      throw StateError('No queued response available for ${request.url}.');
    }
    return _streamedResponses.removeAt(0);
  }
}

class HangingHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final completer = Completer<http.StreamedResponse>();
    return completer.future;
  }
}
