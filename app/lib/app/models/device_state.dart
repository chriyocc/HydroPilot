const _noDeviceStateChange = Object();

class DeviceState {
  const DeviceState({
    this.pumpOn,
    this.lightOn,
    this.primeAOn,
    this.primeBOn,
    this.targetDoseAOn,
    this.targetDoseBOn,
    this.targetDoseAbOn,
    this.shotDoseAOn,
    this.shotDoseBOn,
    this.liquidAWet,
    this.liquidBWet,
    this.targetEcA,
    this.targetEcB,
    this.targetEcAb,
  });

  final bool? pumpOn;
  final bool? lightOn;
  final bool? primeAOn;
  final bool? primeBOn;
  final bool? targetDoseAOn;
  final bool? targetDoseBOn;
  final bool? targetDoseAbOn;
  final bool? shotDoseAOn;
  final bool? shotDoseBOn;
  final bool? liquidAWet;
  final bool? liquidBWet;
  final double? targetEcA;
  final double? targetEcB;
  final double? targetEcAb;

  DeviceState copyWith({
    Object? pumpOn = _noDeviceStateChange,
    Object? lightOn = _noDeviceStateChange,
    Object? primeAOn = _noDeviceStateChange,
    Object? primeBOn = _noDeviceStateChange,
    Object? targetDoseAOn = _noDeviceStateChange,
    Object? targetDoseBOn = _noDeviceStateChange,
    Object? targetDoseAbOn = _noDeviceStateChange,
    Object? shotDoseAOn = _noDeviceStateChange,
    Object? shotDoseBOn = _noDeviceStateChange,
    Object? liquidAWet = _noDeviceStateChange,
    Object? liquidBWet = _noDeviceStateChange,
    Object? targetEcA = _noDeviceStateChange,
    Object? targetEcB = _noDeviceStateChange,
    Object? targetEcAb = _noDeviceStateChange,
  }) {
    return DeviceState(
      pumpOn: identical(pumpOn, _noDeviceStateChange)
          ? this.pumpOn
          : pumpOn as bool?,
      lightOn: identical(lightOn, _noDeviceStateChange)
          ? this.lightOn
          : lightOn as bool?,
      primeAOn: identical(primeAOn, _noDeviceStateChange)
          ? this.primeAOn
          : primeAOn as bool?,
      primeBOn: identical(primeBOn, _noDeviceStateChange)
          ? this.primeBOn
          : primeBOn as bool?,
      targetDoseAOn: identical(targetDoseAOn, _noDeviceStateChange)
          ? this.targetDoseAOn
          : targetDoseAOn as bool?,
      targetDoseBOn: identical(targetDoseBOn, _noDeviceStateChange)
          ? this.targetDoseBOn
          : targetDoseBOn as bool?,
      targetDoseAbOn: identical(targetDoseAbOn, _noDeviceStateChange)
          ? this.targetDoseAbOn
          : targetDoseAbOn as bool?,
      shotDoseAOn: identical(shotDoseAOn, _noDeviceStateChange)
          ? this.shotDoseAOn
          : shotDoseAOn as bool?,
      shotDoseBOn: identical(shotDoseBOn, _noDeviceStateChange)
          ? this.shotDoseBOn
          : shotDoseBOn as bool?,
      liquidAWet: identical(liquidAWet, _noDeviceStateChange)
          ? this.liquidAWet
          : liquidAWet as bool?,
      liquidBWet: identical(liquidBWet, _noDeviceStateChange)
          ? this.liquidBWet
          : liquidBWet as bool?,
      targetEcA: identical(targetEcA, _noDeviceStateChange)
          ? this.targetEcA
          : targetEcA as double?,
      targetEcB: identical(targetEcB, _noDeviceStateChange)
          ? this.targetEcB
          : targetEcB as double?,
      targetEcAb: identical(targetEcAb, _noDeviceStateChange)
          ? this.targetEcAb
          : targetEcAb as double?,
    );
  }
}
