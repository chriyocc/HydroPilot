import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_fi/app/services/device_provisioning_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reports automatic provisioning support from the platform', () async {
    final service = DeviceProvisioningService(
      platformInvoker: ({required method, required arguments}) async {
        expect(method, 'isAutoProvisioningSupported');
        expect(arguments, isEmpty);
        return {'supported': true};
      },
    );

    final isSupported = await service.isAutoProvisioningSupported();

    expect(isSupported, true);
  });

  test('returns unsupported when platform invoker reports unsupported version',
      () async {
    final service = DeviceProvisioningService(
      platformInvoker: ({required method, required arguments}) async {
        expect(method, 'connectToDeviceAp');
        expect(arguments, {
          'ssid': 'HydroPilot-Setup',
          'password': 'setup-password',
        });
        return {'code': 'unsupported_android_version'};
      },
    );

    final result = await service.connectToDeviceAp(
      ssid: 'HydroPilot-Setup',
      password: 'setup-password',
    );

    expect(result.code, ProvisioningResultCode.unsupportedAndroidVersion);
    expect(result.isConnected, false);
  });

  test('maps connection result codes from the platform payload', () async {
    final responses = <Map<String, Object?>>[
      {'code': 'connected'},
      {'code': 'user_denied'},
      {'code': 'connection_timeout'},
      {'code': 'connection_failed'},
    ];
    final service = DeviceProvisioningService(
      platformInvoker: ({required method, required arguments}) async {
        expect(method, 'connectToDeviceAp');
        return responses.removeAt(0);
      },
    );

    expect(
      (await service.connectToDeviceAp(ssid: 's', password: 'p')).code,
      ProvisioningResultCode.connected,
    );
    expect(
      (await service.connectToDeviceAp(ssid: 's', password: 'p')).code,
      ProvisioningResultCode.userDenied,
    );
    expect(
      (await service.connectToDeviceAp(ssid: 's', password: 'p')).code,
      ProvisioningResultCode.connectionTimeout,
    );
    expect(
      (await service.connectToDeviceAp(ssid: 's', password: 'p')).code,
      ProvisioningResultCode.connectionFailed,
    );
  });

  test('maps platform exceptions to connection failures', () async {
    final service = DeviceProvisioningService(
      platformInvoker: ({required method, required arguments}) async {
        throw PlatformException(code: 'native-error', message: 'boom');
      },
    );

    final result = await service.connectToDeviceAp(ssid: 's', password: 'p');

    expect(result.code, ProvisioningResultCode.connectionFailed);
    expect(result.message, 'boom');
  });

  test('disconnects from the device AP through the platform channel', () async {
    var disconnectCalled = false;
    final service = DeviceProvisioningService(
      platformInvoker: ({required method, required arguments}) async {
        if (method == 'disconnectFromDeviceAp') {
          disconnectCalled = true;
          expect(arguments, isEmpty);
          return const <Object?, Object?>{};
        }
        return {'supported': true};
      },
    );

    await service.disconnectFromDeviceAp();

    expect(disconnectCalled, true);
  });
}
