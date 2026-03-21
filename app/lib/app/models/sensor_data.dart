const _noSensorDataChange = Object();

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
    Object? ph = _noSensorDataChange,
    Object? ec = _noSensorDataChange,
    Object? waterTemperature = _noSensorDataChange,
    Object? waterLevel = _noSensorDataChange,
  }) {
    return SensorData(
      ph: identical(ph, _noSensorDataChange) ? this.ph : ph as double?,
      ec: identical(ec, _noSensorDataChange) ? this.ec : ec as double?,
      waterTemperature: identical(waterTemperature, _noSensorDataChange)
          ? this.waterTemperature
          : waterTemperature as double?,
      waterLevel: identical(waterLevel, _noSensorDataChange)
          ? this.waterLevel
          : waterLevel as double?,
    );
  }
}
