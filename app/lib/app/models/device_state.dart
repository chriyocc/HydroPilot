const _noDeviceStateChange = Object();

class DeviceState {
  const DeviceState({
    this.pumpOn,
    this.lightOn,
  });

  final bool? pumpOn;
  final bool? lightOn;

  DeviceState copyWith({
    Object? pumpOn = _noDeviceStateChange,
    Object? lightOn = _noDeviceStateChange,
  }) {
    return DeviceState(
      pumpOn: identical(pumpOn, _noDeviceStateChange)
          ? this.pumpOn
          : pumpOn as bool?,
      lightOn: identical(lightOn, _noDeviceStateChange)
          ? this.lightOn
          : lightOn as bool?,
    );
  }
}
