import 'package:flutter/services.dart';

enum ProvisioningResultCode {
  connected,
  unsupportedAndroidVersion,
  userDenied,
  connectionTimeout,
  connectionFailed,
}

class ProvisioningResult {
  const ProvisioningResult({
    required this.code,
    this.message,
  });

  final ProvisioningResultCode code;
  final String? message;

  bool get isConnected => code == ProvisioningResultCode.connected;

  factory ProvisioningResult.fromPayload(Map<Object?, Object?> payload) {
    final rawCode = payload['code'] as String? ?? 'connection_failed';

    return ProvisioningResult(
      code: switch (rawCode) {
        'connected' => ProvisioningResultCode.connected,
        'unsupported_android_version' =>
          ProvisioningResultCode.unsupportedAndroidVersion,
        'user_denied' => ProvisioningResultCode.userDenied,
        'connection_timeout' => ProvisioningResultCode.connectionTimeout,
        _ => ProvisioningResultCode.connectionFailed,
      },
      message: payload['message'] as String?,
    );
  }
}

typedef ProvisioningPlatformInvoker =
    Future<Map<Object?, Object?>> Function({
  required String method,
  required Map<String, Object?> arguments,
});

class DeviceProvisioningService {
  DeviceProvisioningService({
    ProvisioningPlatformInvoker? platformInvoker,
  }) : _platformInvoker = platformInvoker ?? _invokeMethodChannel;

  static const MethodChannel _channel = MethodChannel('hydropilot/provisioning');

  final ProvisioningPlatformInvoker _platformInvoker;

  Future<bool> isAutoProvisioningSupported() async {
    try {
      final payload = await _platformInvoker(
        method: 'isAutoProvisioningSupported',
        arguments: const {},
      );
      return payload['supported'] == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<ProvisioningResult> connectToDeviceAp({
    required String ssid,
    required String password,
  }) async {
    try {
      final payload = await _platformInvoker(
        method: 'connectToDeviceAp',
        arguments: {
          'ssid': ssid,
          'password': password,
        },
      );
      return ProvisioningResult.fromPayload(payload);
    } on MissingPluginException {
      return const ProvisioningResult(
        code: ProvisioningResultCode.unsupportedAndroidVersion,
      );
    } on PlatformException catch (error) {
      return ProvisioningResult(
        code: ProvisioningResultCode.connectionFailed,
        message: error.message,
      );
    }
  }

  Future<void> disconnectFromDeviceAp() async {
    try {
      await _platformInvoker(
        method: 'disconnectFromDeviceAp',
        arguments: const {},
      );
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  static Future<Map<Object?, Object?>> _invokeMethodChannel({
    required String method,
    required Map<String, Object?> arguments,
  }) async {
    final response = await _channel.invokeMethod<Object?>(method, arguments);
    if (response is Map<Object?, Object?>) {
      return response;
    }
    return const {'code': 'connection_failed'};
  }
}
