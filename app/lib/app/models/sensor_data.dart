class SensorData {
  const SensorData({
    this.ph,
    this.ec,
    this.waterTemperature,
    this.waterLevel,
  });

  final double? ph;
  final double? ec;
  final double? waterTemperature;
  final double? waterLevel;

  SensorData copyWith({
    double? ph,
    double? ec,
    double? waterTemperature,
    double? waterLevel,
  }) {
    return SensorData(
      ph: ph ?? this.ph,
      ec: ec ?? this.ec,
      waterTemperature: waterTemperature ?? this.waterTemperature,
      waterLevel: waterLevel ?? this.waterLevel,
    );
  }
}
