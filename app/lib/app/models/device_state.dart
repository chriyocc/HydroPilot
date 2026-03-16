class DeviceState {
  const DeviceState({
    this.pumpOn,
    this.lightOn,
  });

  final bool? pumpOn;
  final bool? lightOn;

  DeviceState copyWith({
    bool? pumpOn,
    bool? lightOn,
  }) {
    return DeviceState(
      pumpOn: pumpOn ?? this.pumpOn,
      lightOn: lightOn ?? this.lightOn,
    );
  }
}
