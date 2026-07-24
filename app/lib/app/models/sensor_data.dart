const _noSensorDataChange = Object();

class SensorData {
  const SensorData({
    this.ph,
    this.ec,
    this.waterTemperature,
    this.waterLevel,
    this.humidity,
    this.tds,
    this.distance,
  });

  final double? ph;
  final double? ec;
  final double? waterTemperature;
  final double? waterLevel;
  final double? humidity;
  final double? tds;
  final double? distance;

  SensorData copyWith({
    Object? ph = _noSensorDataChange,
    Object? ec = _noSensorDataChange,
    Object? waterTemperature = _noSensorDataChange,
    Object? waterLevel = _noSensorDataChange,
    Object? humidity = _noSensorDataChange,
    Object? tds = _noSensorDataChange,
    Object? distance = _noSensorDataChange,
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
      humidity: identical(humidity, _noSensorDataChange)
          ? this.humidity
          : humidity as double?,
      tds: identical(tds, _noSensorDataChange) ? this.tds : tds as double?,
      distance: identical(distance, _noSensorDataChange)
          ? this.distance
          : distance as double?,
    );
  }
}
