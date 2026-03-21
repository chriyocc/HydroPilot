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

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
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
