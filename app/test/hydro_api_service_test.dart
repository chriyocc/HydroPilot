import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:home_fi/app/services/hydro_api_service.dart';
import 'package:http/http.dart' as http;

void main() {
  test('fetchStatus times out when controller does not respond', () async {
    final service = HydroApiService(
      client: HangingHttpClient(),
      requestTimeout: const Duration(milliseconds: 50),
    );

    await expectLater(
      service.fetchStatus('192.168.4.1'),
      throwsA(isA<TimeoutException>()),
    );
  });
}

class HangingHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final completer = Completer<http.StreamedResponse>();
    return completer.future;
  }
}
