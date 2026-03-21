const _noRuntimeStatusChange = Object();

class RuntimeStatus {
  const RuntimeStatus({
    this.isBackendReachable = false,
    this.isDeviceOnline,
    this.isStreamConnected = false,
    this.isTelemetryStale = false,
    this.isStateStale = false,
  });

  final bool isBackendReachable;
  final bool? isDeviceOnline;
  final bool isStreamConnected;
  final bool isTelemetryStale;
  final bool isStateStale;

  RuntimeStatus copyWith({
    Object? isBackendReachable = _noRuntimeStatusChange,
    Object? isDeviceOnline = _noRuntimeStatusChange,
    Object? isStreamConnected = _noRuntimeStatusChange,
    Object? isTelemetryStale = _noRuntimeStatusChange,
    Object? isStateStale = _noRuntimeStatusChange,
  }) {
    return RuntimeStatus(
      isBackendReachable: identical(isBackendReachable, _noRuntimeStatusChange)
          ? this.isBackendReachable
          : isBackendReachable as bool,
      isDeviceOnline: identical(isDeviceOnline, _noRuntimeStatusChange)
          ? this.isDeviceOnline
          : isDeviceOnline as bool?,
      isStreamConnected: identical(isStreamConnected, _noRuntimeStatusChange)
          ? this.isStreamConnected
          : isStreamConnected as bool,
      isTelemetryStale: identical(isTelemetryStale, _noRuntimeStatusChange)
          ? this.isTelemetryStale
          : isTelemetryStale as bool,
      isStateStale: identical(isStateStale, _noRuntimeStatusChange)
          ? this.isStateStale
          : isStateStale as bool,
    );
  }
}
