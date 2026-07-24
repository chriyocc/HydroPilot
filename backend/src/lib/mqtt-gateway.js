function createTopicMap(config) {
  const baseTopic = `${config.hydroTopicPrefix}/device/${config.hydroDeviceId}`;
  const legacyRoot = config.hydroTopicPrefix;

  return {
    baseTopic,
    availability: `${baseTopic}/availability`,
    alarm: `${baseTopic}/alarm`,
    statePump: `${baseTopic}/state/pump`,
    stateLight: `${baseTopic}/state/light`,
    stateNutrientA: `${baseTopic}/state/nutrient/a`,
    stateNutrientB: `${baseTopic}/state/nutrient/b`,
    statePrimeA: `${baseTopic}/state/prime/a`,
    statePrimeB: `${baseTopic}/state/prime/b`,
    stateTargetDoseA: `${baseTopic}/state/target-dose/a`,
    stateTargetDoseB: `${baseTopic}/state/target-dose/b`,
    stateTargetDoseAb: `${baseTopic}/state/target-dose/ab`,
    stateShotDoseA: `${baseTopic}/state/shot-dose/a`,
    stateShotDoseB: `${baseTopic}/state/shot-dose/b`,
    stateLiquidA: `${baseTopic}/state/liquid/a`,
    stateLiquidB: `${baseTopic}/state/liquid/b`,
    telemetryPh: `${baseTopic}/telemetry/ph`,
    telemetryEc: `${baseTopic}/telemetry/ec`,
    telemetryTemp: `${baseTopic}/telemetry/temp`,
    telemetryHumidity: `${baseTopic}/telemetry/humidity`,
    telemetryWaterLevel: `${baseTopic}/telemetry/waterlevel`,
    telemetryDistance: `${baseTopic}/telemetry/distance`,
    telemetryTds: `${baseTopic}/telemetry/tds`,
    ecHistory: `${baseTopic}/ec-history`,
    cmdPump: `${baseTopic}/cmd/pump`,
    cmdLight: `${baseTopic}/cmd/light`,
    cmdNutrientA: `${baseTopic}/cmd/nutrient/a`,
    cmdNutrientB: `${baseTopic}/cmd/nutrient/b`,
    cmdPrimeA: `${baseTopic}/cmd/prime/a`,
    cmdPrimeB: `${baseTopic}/cmd/prime/b`,
    cmdTargetDoseA: `${baseTopic}/cmd/target-dose/a`,
    cmdTargetDoseB: `${baseTopic}/cmd/target-dose/b`,
    cmdTargetDoseAb: `${baseTopic}/cmd/target-dose/ab`,
    cmdShotDoseA: `${baseTopic}/cmd/shot-dose/a`,
    cmdShotDoseB: `${baseTopic}/cmd/shot-dose/b`,
    legacyStatus: `${legacyRoot}/status`,
    legacySensorTemperature: `${legacyRoot}/sensor/temperature`,
    legacySensorHumidity: `${legacyRoot}/sensor/humidity`,
    legacySensorWaterLevel: `${legacyRoot}/sensor/water_level`,
    legacySensorDistance: `${legacyRoot}/sensor/distance`,
    legacySensorEc: `${legacyRoot}/sensor/ec`,
    legacySensorTds: `${legacyRoot}/sensor/tds`,
    legacySensorLiquid1: `${legacyRoot}/sensor/liquid1`,
    legacySensorLiquid2: `${legacyRoot}/sensor/liquid2`,
    legacyStatePump: `${legacyRoot}/state/pump`,
    legacyStateLight: `${legacyRoot}/state/light`,
    legacyStateNutrientA: `${legacyRoot}/state/fert_a`,
    legacyStateNutrientB: `${legacyRoot}/state/fert_b`,
    legacyStatePrimeA: `${legacyRoot}/state/prime_a`,
    legacyStatePrimeB: `${legacyRoot}/state/prime_b`,
    legacyStateTargetDoseA: `${legacyRoot}/state/target_dose_a`,
    legacyStateTargetDoseB: `${legacyRoot}/state/target_dose_b`,
    legacyStateTargetDoseAb: `${legacyRoot}/state/target_dose_ab`,
    legacyStateShotDoseA: `${legacyRoot}/state/shot_dose_a`,
    legacyStateShotDoseB: `${legacyRoot}/state/shot_dose_b`,
  };
}

function parsePayload(buffer) {
  const text = buffer.toString('utf8').trim();

  if (!text) {
    return null;
  }

  try {
    return JSON.parse(text);
  } catch (_) {
    if (text === 'true') {
      return true;
    }
    if (text === 'false') {
      return false;
    }
    const numeric = Number(text);
    return Number.isNaN(numeric) ? text : numeric;
  }
}

function readBoolean(payload, keys) {
  const candidates = Array.isArray(payload)
    ? []
    : typeof payload === 'object' && payload !== null
      ? keys.map((key) => payload[key])
      : [payload];

  for (const value of candidates) {
    if (typeof value === 'boolean') {
      return value;
    }
    if (typeof value === 'number') {
      return value !== 0;
    }
    if (typeof value === 'string') {
      const normalized = value.toLowerCase();
      if (['true', 'on', '1', 'online'].includes(normalized)) {
        return true;
      }
      if (['false', 'off', '0', 'offline'].includes(normalized)) {
        return false;
      }
    }
  }

  return null;
}

function readNumber(payload, keys) {
  const candidates = Array.isArray(payload)
    ? []
    : typeof payload === 'object' && payload !== null
      ? keys.map((key) => payload[key])
      : [payload];

  for (const value of candidates) {
    if (typeof value === 'number') {
      return value;
    }
    if (typeof value === 'string' && value.trim()) {
      const numeric = Number(value);
      if (!Number.isNaN(numeric)) {
        return numeric;
      }
    }
  }

  return null;
}

function readTimestamp(payload) {
  if (typeof payload === 'object' && payload !== null && payload.ts) {
    return payload.ts;
  }

  return new Date().toISOString();
}

function readRequestId(payload) {
  return typeof payload === 'object' && payload !== null
    ? payload.requestId ?? null
    : null;
}

function createMqttGateway({ config, mqttClient, deviceService, logger }) {
  const topics = createTopicMap(config);
  const subscriptions = [
    topics.availability,
    topics.alarm,
    topics.statePump,
    topics.stateLight,
    topics.stateNutrientA,
    topics.stateNutrientB,
    topics.statePrimeA,
    topics.statePrimeB,
    topics.stateTargetDoseA,
    topics.stateTargetDoseB,
    topics.stateTargetDoseAb,
    topics.stateShotDoseA,
    topics.stateShotDoseB,
    topics.stateLiquidA,
    topics.stateLiquidB,
    topics.telemetryPh,
    topics.telemetryEc,
    topics.telemetryTemp,
    topics.telemetryHumidity,
    topics.telemetryWaterLevel,
    topics.telemetryDistance,
    topics.telemetryTds,
    topics.ecHistory,
    topics.legacyStatus,
    topics.legacySensorTemperature,
    topics.legacySensorHumidity,
    topics.legacySensorWaterLevel,
    topics.legacySensorDistance,
    topics.legacySensorEc,
    topics.legacySensorTds,
    topics.legacySensorLiquid1,
    topics.legacySensorLiquid2,
    topics.legacyStatePump,
    topics.legacyStateLight,
    topics.legacyStateNutrientA,
    topics.legacyStateNutrientB,
    topics.legacyStatePrimeA,
    topics.legacyStatePrimeB,
    topics.legacyStateTargetDoseA,
    topics.legacyStateTargetDoseB,
    topics.legacyStateTargetDoseAb,
    topics.legacyStateShotDoseA,
    topics.legacyStateShotDoseB,
  ];

  async function subscribeAll() {
    await mqttClient.subscribe(subscriptions);
    logger?.info('Subscribed to device topics', {
      count: subscriptions.length,
      deviceId: config.hydroDeviceId,
    });
  }

  async function handleConnect() {
    deviceService.setBrokerStatus('connected');
    await subscribeAll();
  }

  async function handleReconnect() {
    deviceService.setBrokerStatus('reconnecting');
    await subscribeAll();
  }

  function handleDisconnect() {
    deviceService.setBrokerStatus('disconnected');
  }

  function applyTelemetry(field, value, ts) {
    logger?.info('Telemetry received', {
      deviceId: config.hydroDeviceId,
      field,
      value,
    });
    deviceService.handleTelemetry({ field, value, ts });
  }

  function applyState(field, value, payload, ts) {
    logger?.info('State update received', {
      deviceId: config.hydroDeviceId,
      field,
      value,
    });
    deviceService.handleState({
      field,
      value,
      requestId: readRequestId(payload),
      ts,
    });
  }

  function applyStatusPayload(payload, ts) {
    if (typeof payload !== 'object' || payload === null || Array.isArray(payload)) {
      return;
    }

    for (const [field, keys] of [
      ['waterTemperature', ['waterTemperature', 'water_temperature', 'temp', 'temperature']],
      ['humidity', ['humidity']],
      ['waterLevel', ['waterLevel', 'water_level', 'water']],
      ['tds', ['tds']],
      ['ec', ['ec']],
      ['distance', ['distance']],
    ]) {
      const value = readNumber(payload, keys);
      if (value !== null) {
        applyTelemetry(field, value, ts);
      }
    }

    for (const [field, keys] of [
      ['pumpOn', ['pumpOn', 'pump_on', 'pump']],
      ['lightOn', ['lightOn', 'light_on', 'light']],
      ['nutrientAOn', ['nutrientAOn', 'fert_a', 'nutrient_a']],
      ['nutrientBOn', ['nutrientBOn', 'fert_b', 'nutrient_b']],
      ['primeAOn', ['primeAOn', 'prime_a']],
      ['primeBOn', ['primeBOn', 'prime_b']],
      ['targetDoseAOn', ['targetDoseAOn', 'target_dose_a']],
      ['targetDoseBOn', ['targetDoseBOn', 'target_dose_b']],
      ['targetDoseAbOn', ['targetDoseAbOn', 'target_dose_ab']],
      ['shotDoseAOn', ['shotDoseAOn', 'shot_dose_a']],
      ['shotDoseBOn', ['shotDoseBOn', 'shot_dose_b']],
      ['liquidAWet', ['liquidAWet', 'liquid1']],
      ['liquidBWet', ['liquidBWet', 'liquid2']],
    ]) {
      const value = readBoolean(payload, keys);
      if (value !== null) {
        applyState(field, value, payload, ts);
      }
    }

    for (const [field, keys] of [
      ['targetEcA', ['targetEcA', 'target_ec_a']],
      ['targetEcB', ['targetEcB', 'target_ec_b']],
      ['targetEcAb', ['targetEcAb', 'target_ec_ab']],
    ]) {
      const value = readNumber(payload, keys);
      if (value !== null) {
        applyState(field, value, payload, ts);
      }
    }
  }

  function applyEcHistory(payload, ts) {
    if (typeof payload !== 'object' || payload === null || Array.isArray(payload)) {
      return;
    }

    const values = payload.ecValues ?? payload.ec;
    deviceService.handleEcHistory({
      periodMs: readNumber(payload, ['periodMs', 'period_ms']) ?? 0,
      windowMs: readNumber(payload, ['windowMs', 'window_ms']) ?? 0,
      ecValues: Array.isArray(values)
        ? values
            .map((value) =>
              typeof value === 'number' ? value : Number(value),
            )
            .filter((value) => !Number.isNaN(value))
        : [],
      ts,
    });
  }

  function applyTargetDoseState(field, payload, ts) {
    applyState(
      field,
      readBoolean(payload, ['active', 'on', 'value']) ?? false,
      payload,
      ts,
    );
    const targetEcField =
      field === 'targetDoseAOn'
        ? 'targetEcA'
        : field === 'targetDoseBOn'
          ? 'targetEcB'
          : 'targetEcAb';
    const targetEc = readNumber(payload, ['targetEc', 'target_ec', 'concentration']);
    if (targetEc !== null) {
      applyState(targetEcField, targetEc, payload, ts);
    }
  }

  function handleMessage(topic, buffer) {
    const payload = parsePayload(buffer);
    const ts = readTimestamp(payload);

    switch (topic) {
      case topics.availability:
        deviceService.handleAvailability({
          online: readBoolean(payload, ['online', 'available', 'status']),
          status:
            typeof payload === 'object' && payload !== null
              ? payload.status
              : null,
          ts,
        });
        return;
      case topics.alarm:
        logger?.warn('Alarm received', {
          deviceId: config.hydroDeviceId,
        });
        deviceService.handleAlarm({
          payload,
          ts,
        });
        return;
      case topics.statePump:
      case topics.legacyStatePump:
        applyState('pumpOn', readBoolean(payload, ['on', 'value', 'pumpOn', 'pump']), payload, ts);
        return;
      case topics.stateLight:
      case topics.legacyStateLight:
        applyState('lightOn', readBoolean(payload, ['on', 'value', 'lightOn', 'light']), payload, ts);
        return;
      case topics.stateNutrientA:
      case topics.legacyStateNutrientA:
        applyState('nutrientAOn', readBoolean(payload, ['ok', 'on', 'value']), payload, ts);
        return;
      case topics.stateNutrientB:
      case topics.legacyStateNutrientB:
        applyState('nutrientBOn', readBoolean(payload, ['ok', 'on', 'value']), payload, ts);
        return;
      case topics.statePrimeA:
      case topics.legacyStatePrimeA:
        applyState('primeAOn', readBoolean(payload, ['active', 'on', 'value']), payload, ts);
        return;
      case topics.statePrimeB:
      case topics.legacyStatePrimeB:
        applyState('primeBOn', readBoolean(payload, ['active', 'on', 'value']), payload, ts);
        return;
      case topics.stateTargetDoseA:
      case topics.legacyStateTargetDoseA:
        applyTargetDoseState('targetDoseAOn', payload, ts);
        return;
      case topics.stateTargetDoseB:
      case topics.legacyStateTargetDoseB:
        applyTargetDoseState('targetDoseBOn', payload, ts);
        return;
      case topics.stateTargetDoseAb:
      case topics.legacyStateTargetDoseAb:
        applyTargetDoseState('targetDoseAbOn', payload, ts);
        return;
      case topics.stateShotDoseA:
      case topics.legacyStateShotDoseA:
        applyState('shotDoseAOn', readBoolean(payload, ['active', 'on', 'value']), payload, ts);
        return;
      case topics.stateShotDoseB:
      case topics.legacyStateShotDoseB:
        applyState('shotDoseBOn', readBoolean(payload, ['active', 'on', 'value']), payload, ts);
        return;
      case topics.stateLiquidA:
      case topics.legacySensorLiquid1:
        applyState('liquidAWet', readBoolean(payload, ['wet', 'on', 'value', 'liquid1']), payload, ts);
        return;
      case topics.stateLiquidB:
      case topics.legacySensorLiquid2:
        applyState('liquidBWet', readBoolean(payload, ['wet', 'on', 'value', 'liquid2']), payload, ts);
        return;
      case topics.telemetryPh:
        applyTelemetry('ph', readNumber(payload, ['value', 'ph']), ts);
        return;
      case topics.telemetryEc:
      case topics.legacySensorEc:
        applyTelemetry('ec', readNumber(payload, ['value', 'ec']), ts);
        return;
      case topics.telemetryTemp:
      case topics.legacySensorTemperature:
        applyTelemetry('waterTemperature', readNumber(payload, ['value', 'temp', 'temperature', 'waterTemperature']), ts);
        return;
      case topics.telemetryHumidity:
      case topics.legacySensorHumidity:
        applyTelemetry('humidity', readNumber(payload, ['value', 'humidity']), ts);
        return;
      case topics.telemetryWaterLevel:
      case topics.legacySensorWaterLevel:
        applyTelemetry('waterLevel', readNumber(payload, ['value', 'level', 'waterLevel', 'water']), ts);
        return;
      case topics.telemetryDistance:
      case topics.legacySensorDistance:
        applyTelemetry('distance', readNumber(payload, ['value', 'distance']), ts);
        return;
      case topics.telemetryTds:
      case topics.legacySensorTds:
        applyTelemetry('tds', readNumber(payload, ['value', 'tds']), ts);
        return;
      case topics.ecHistory:
        applyEcHistory(payload, ts);
        return;
      case topics.legacyStatus:
        applyStatusPayload(payload, ts);
        return;
      default:
        return;
    }
  }

  function start() {
    deviceService.setBrokerStatus('connecting');
    mqttClient.on('connect', handleConnect);
    mqttClient.on('reconnect', handleReconnect);
    mqttClient.on('close', handleDisconnect);
    mqttClient.on('offline', handleDisconnect);
    mqttClient.on('message', handleMessage);
  }

  return {
    start,
    topics,
  };
}

module.exports = {
  createMqttGateway,
  createTopicMap,
};
