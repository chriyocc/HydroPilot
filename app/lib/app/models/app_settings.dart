class AppSettings {
  const AppSettings({
    required this.backendBaseUrl,
    required this.maintenanceDeviceIp,
    required this.refreshInterval,
  });

  final String backendBaseUrl;
  final String maintenanceDeviceIp;
  final int refreshInterval;

  factory AppSettings.defaults() {
    return const AppSettings(
      backendBaseUrl: '',
      maintenanceDeviceIp: '',
      refreshInterval: 0,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      backendBaseUrl: (json['backendBaseUrl'] as String?)?.trim() ?? '',
      maintenanceDeviceIp:
          (json['maintenanceDeviceIp'] as String?)?.trim() ?? '',
      refreshInterval: (json['refreshInterval'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'backendBaseUrl': backendBaseUrl,
      'maintenanceDeviceIp': maintenanceDeviceIp,
      'refreshInterval': refreshInterval,
    };
  }

  AppSettings copyWith({
    String? backendBaseUrl,
    String? maintenanceDeviceIp,
    int? refreshInterval,
  }) {
    return AppSettings(
      backendBaseUrl: backendBaseUrl ?? this.backendBaseUrl,
      maintenanceDeviceIp: maintenanceDeviceIp ?? this.maintenanceDeviceIp,
      refreshInterval: refreshInterval ?? this.refreshInterval,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is AppSettings &&
        other.backendBaseUrl == backendBaseUrl &&
        other.maintenanceDeviceIp == maintenanceDeviceIp &&
        other.refreshInterval == refreshInterval;
  }

  @override
  int get hashCode =>
      backendBaseUrl.hashCode ^
      maintenanceDeviceIp.hashCode ^
      refreshInterval.hashCode;
}
