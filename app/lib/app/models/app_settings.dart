class AppSettings {
  const AppSettings({
    required this.deviceIp,
    required this.mqttBrokerIp,
    required this.topicPrefix,
    required this.refreshInterval,
  });

  final String deviceIp;
  final String mqttBrokerIp;
  final String topicPrefix;
  final int refreshInterval;

  factory AppSettings.defaults() {
    return const AppSettings(
      deviceIp: '192.168.4.1',
      mqttBrokerIp: '',
      topicPrefix: 'hydro',
      refreshInterval: 5,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      deviceIp: (json['deviceIp'] as String?)?.trim().isNotEmpty == true
          ? json['deviceIp'] as String
          : '192.168.4.1',
      mqttBrokerIp: (json['mqttBrokerIp'] as String?) ?? '',
      topicPrefix: (json['topicPrefix'] as String?)?.trim().isNotEmpty == true
          ? json['topicPrefix'] as String
          : 'hydro',
      refreshInterval: (json['refreshInterval'] as int?) ?? 5,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceIp': deviceIp,
      'mqttBrokerIp': mqttBrokerIp,
      'topicPrefix': topicPrefix,
      'refreshInterval': refreshInterval,
    };
  }

  AppSettings copyWith({
    String? deviceIp,
    String? mqttBrokerIp,
    String? topicPrefix,
    int? refreshInterval,
  }) {
    return AppSettings(
      deviceIp: deviceIp ?? this.deviceIp,
      mqttBrokerIp: mqttBrokerIp ?? this.mqttBrokerIp,
      topicPrefix: topicPrefix ?? this.topicPrefix,
      refreshInterval: refreshInterval ?? this.refreshInterval,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is AppSettings &&
        other.deviceIp == deviceIp &&
        other.mqttBrokerIp == mqttBrokerIp &&
        other.topicPrefix == topicPrefix &&
        other.refreshInterval == refreshInterval;
  }

  @override
  int get hashCode =>
      deviceIp.hashCode ^
      mqttBrokerIp.hashCode ^
      topicPrefix.hashCode ^
      refreshInterval.hashCode;
}
