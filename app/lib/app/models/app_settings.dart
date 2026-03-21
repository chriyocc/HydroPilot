class AppSettings {
  const AppSettings({
    required this.backendBaseUrl,
    required this.refreshInterval,
  });

  final String backendBaseUrl;
  final int refreshInterval;

  factory AppSettings.defaults() {
    return const AppSettings(
      backendBaseUrl: '',
      refreshInterval: 0,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      backendBaseUrl: (json['backendBaseUrl'] as String?)?.trim() ?? '',
      refreshInterval: (json['refreshInterval'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'backendBaseUrl': backendBaseUrl,
      'refreshInterval': refreshInterval,
    };
  }

  AppSettings copyWith({
    String? backendBaseUrl,
    int? refreshInterval,
  }) {
    return AppSettings(
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
        other.backendBaseUrl == backendBaseUrl &&
        other.refreshInterval == refreshInterval;
  }

  @override
  int get hashCode => backendBaseUrl.hashCode ^ refreshInterval.hashCode;
}
