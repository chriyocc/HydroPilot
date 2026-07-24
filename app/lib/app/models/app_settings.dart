enum TransportMode {
  localNetwork,
  realServer,
}

class AppSettings {
  static const defaultLocalDeviceBaseUrl = 'http://192.168.4.1';

  const AppSettings({
    required this.transportMode,
    required this.localDeviceBaseUrl,
    required this.backendBaseUrl,
    required this.refreshInterval,
  });

  final TransportMode transportMode;
  final String localDeviceBaseUrl;
  final String backendBaseUrl;
  final int refreshInterval;

  bool get usesLocalNetwork => transportMode == TransportMode.localNetwork;
  bool get usesRealServer => transportMode == TransportMode.realServer;

  factory AppSettings.defaults() {
    return const AppSettings(
      transportMode: TransportMode.realServer,
      localDeviceBaseUrl: defaultLocalDeviceBaseUrl,
      backendBaseUrl: '',
      refreshInterval: 0,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      transportMode: _readTransportMode(json['transportMode']),
      localDeviceBaseUrl:
          (json['localDeviceBaseUrl'] as String?)?.trim().isNotEmpty == true
              ? (json['localDeviceBaseUrl'] as String).trim()
              : defaultLocalDeviceBaseUrl,
      backendBaseUrl: (json['backendBaseUrl'] as String?)?.trim() ?? '',
      refreshInterval: (json['refreshInterval'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transportMode': transportMode.name,
      'localDeviceBaseUrl': localDeviceBaseUrl,
      'backendBaseUrl': backendBaseUrl,
      'refreshInterval': refreshInterval,
    };
  }

  AppSettings copyWith({
    TransportMode? transportMode,
    String? localDeviceBaseUrl,
    String? backendBaseUrl,
    int? refreshInterval,
  }) {
    return AppSettings(
      transportMode: transportMode ?? this.transportMode,
      localDeviceBaseUrl: localDeviceBaseUrl ?? this.localDeviceBaseUrl,
      backendBaseUrl: backendBaseUrl ?? this.backendBaseUrl,
      refreshInterval: refreshInterval ?? this.refreshInterval,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is AppSettings &&
        other.transportMode == transportMode &&
        other.localDeviceBaseUrl == localDeviceBaseUrl &&
        other.backendBaseUrl == backendBaseUrl &&
        other.refreshInterval == refreshInterval;
  }

  @override
  int get hashCode =>
      transportMode.hashCode ^
      localDeviceBaseUrl.hashCode ^
      backendBaseUrl.hashCode ^
      refreshInterval.hashCode;

  static TransportMode _readTransportMode(Object? value) {
    if (value is String) {
      for (final mode in TransportMode.values) {
        if (mode.name == value) {
          return mode;
        }
      }
    }
    return TransportMode.realServer;
  }
}
