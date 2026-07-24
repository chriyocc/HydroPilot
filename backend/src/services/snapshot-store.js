function createSnapshotStore({ config, now }) {
  const snapshot = {
    deviceId: config.hydroDeviceId,
    broker: {
      connected: false,
      status: 'disconnected',
    },
    availability: {
      online: null,
      status: 'unknown',
    },
    sensors: {
      ph: null,
      ec: null,
      waterTemperature: null,
      waterLevel: null,
      humidity: null,
      tds: null,
      distance: null,
    },
    deviceState: {
      pumpOn: null,
      lightOn: null,
      nutrientAOn: null,
      nutrientBOn: null,
      primeAOn: null,
      primeBOn: null,
      targetDoseAOn: null,
      targetDoseBOn: null,
      targetDoseAbOn: null,
      shotDoseAOn: null,
      shotDoseBOn: null,
      liquidAWet: null,
      liquidBWet: null,
      targetEcA: null,
      targetEcB: null,
      targetEcAb: null,
    },
    ecHistory: {
      periodMs: 0,
      windowMs: 0,
      ecValues: [],
    },
    alarms: {
      latest: null,
    },
    timestamps: {
      lastTelemetryAt: null,
      lastStateAt: null,
      lastAvailabilityAt: null,
      lastAlarmAt: null,
      lastEcHistoryAt: null,
    },
  };

  function getFreshness() {
    const currentTime = now();
    const lastTelemetryTime = snapshot.timestamps.lastTelemetryAt
      ? Date.parse(snapshot.timestamps.lastTelemetryAt)
      : null;
    const lastStateTime = snapshot.timestamps.lastStateAt
      ? Date.parse(snapshot.timestamps.lastStateAt)
      : null;

    return {
      offline:
        snapshot.availability.online !== true || snapshot.broker.connected !== true,
      staleTelemetry:
        lastTelemetryTime === null
          ? false
          : currentTime - lastTelemetryTime > config.telemetryStaleMs,
      staleState:
        lastStateTime === null
          ? false
          : currentTime - lastStateTime > config.stateStaleMs,
    };
  }

  function setBrokerStatus(status) {
    snapshot.broker = {
      connected: status === 'connected',
      status,
    };
  }

  function applyAvailability({ online, status, ts }) {
    snapshot.availability = {
      online,
      status:
        typeof status === 'string' && status.length > 0
          ? status
          : online === true
            ? 'online'
            : online === false
              ? 'offline'
              : 'unknown',
    };
    snapshot.timestamps.lastAvailabilityAt = ts;
  }

  function applyTelemetry({ field, value, ts }) {
    if (!(field in snapshot.sensors)) {
      return;
    }

    snapshot.sensors[field] = value;
    snapshot.timestamps.lastTelemetryAt = ts;
  }

  function applyState({ field, value, ts }) {
    if (!(field in snapshot.deviceState)) {
      return;
    }

    snapshot.deviceState[field] = value;
    snapshot.timestamps.lastStateAt = ts;
  }

  function applyAlarm({ payload, ts }) {
    snapshot.alarms.latest = payload;
    snapshot.timestamps.lastAlarmAt = ts;
  }

  function applyEcHistory({ periodMs, windowMs, ecValues, ts }) {
    snapshot.ecHistory = {
      periodMs: Number.isFinite(periodMs) ? periodMs : 0,
      windowMs: Number.isFinite(windowMs) ? windowMs : 0,
      ecValues: Array.isArray(ecValues) ? [...ecValues] : [],
    };
    snapshot.timestamps.lastEcHistoryAt = ts;
  }

  function getSnapshot() {
    return {
      deviceId: snapshot.deviceId,
      broker: { ...snapshot.broker },
      availability: { ...snapshot.availability },
      sensors: { ...snapshot.sensors },
      deviceState: { ...snapshot.deviceState },
      ecHistory: {
        ...snapshot.ecHistory,
        ecValues: [...snapshot.ecHistory.ecValues],
      },
      alarms: { ...snapshot.alarms },
      timestamps: { ...snapshot.timestamps },
      freshness: getFreshness(),
    };
  }

  return {
    setBrokerStatus,
    applyAvailability,
    applyTelemetry,
    applyState,
    applyAlarm,
    applyEcHistory,
    getSnapshot,
  };
}

module.exports = {
  createSnapshotStore,
};
