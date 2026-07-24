function createTopicMap(config) {
  const baseTopic = `${config.hydroTopicPrefix}/device/${config.hydroDeviceId}`;

  return {
    baseTopic,
    availability: `${baseTopic}/availability`,
    alarm: `${baseTopic}/alarm`,
    statePump: `${baseTopic}/state/pump`,
    stateLight: `${baseTopic}/state/light`,
    stateNutrientA: `${baseTopic}/state/nutrient/a`,
    stateNutrientB: `${baseTopic}/state/nutrient/b`,
    telemetryPh: `${baseTopic}/telemetry/ph`,
    telemetryEc: `${baseTopic}/telemetry/ec`,
    telemetryTemp: `${baseTopic}/telemetry/temp`,
    telemetryWaterLevel: `${baseTopic}/telemetry/waterlevel`,
    cmdPump: `${baseTopic}/cmd/pump`,
    cmdLight: `${baseTopic}/cmd/light`,
    cmdNutrientA: `${baseTopic}/cmd/nutrient/a`,
    cmdNutrientB: `${baseTopic}/cmd/nutrient/b`,
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

function createMqttGateway({ config, mqttClient, deviceService, logger }) {
  const topics = createTopicMap(config);
  const subscriptions = [
    topics.availability,
    topics.alarm,
    topics.statePump,
    topics.stateLight,
    topics.stateNutrientA,
    topics.stateNutrientB,
    topics.telemetryPh,
    topics.telemetryEc,
    topics.telemetryTemp,
    topics.telemetryWaterLevel,
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

  function handleMessage(topic, buffer) {
    const payload = parsePayload(buffer);
    const ts = readTimestamp(payload);

    switch (topic) {
      case topics.availability:
        deviceService.handleAvailability({
          online: readBoolean(payload, ['online', 'available', 'status']),
          status: typeof payload === 'object' && payload !== null ? payload.status : null,
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
        logger?.info('State update received', {
          deviceId: config.hydroDeviceId,
          field: 'pumpOn',
          value: readBoolean(payload, ['on', 'value', 'pumpOn', 'pump']),
        });
        deviceService.handleState({
          field: 'pumpOn',
          value: readBoolean(payload, ['on', 'value', 'pumpOn', 'pump']),
          requestId:
            typeof payload === 'object' && payload !== null
              ? payload.requestId ?? null
              : null,
          ts,
        });
        return;
      case topics.stateLight:
        logger?.info('State update received', {
          deviceId: config.hydroDeviceId,
          field: 'lightOn',
          value: readBoolean(payload, ['on', 'value', 'lightOn', 'light']),
        });
        deviceService.handleState({
          field: 'lightOn',
          value: readBoolean(payload, ['on', 'value', 'lightOn', 'light']),
          requestId:
            typeof payload === 'object' && payload !== null
              ? payload.requestId ?? null
              : null,
          ts,
        });
        return;
      case topics.stateNutrientA:
        logger?.info('Nutrient result received', {
          deviceId: config.hydroDeviceId,
          channel: 'a',
        });
        deviceService.handleState({
          field: 'nutrientA',
          value: readBoolean(payload, ['ok', 'value']),
          requestId:
            typeof payload === 'object' && payload !== null
              ? payload.requestId ?? null
              : null,
          ts,
        });
        return;
      case topics.stateNutrientB:
        logger?.info('Nutrient result received', {
          deviceId: config.hydroDeviceId,
          channel: 'b',
        });
        deviceService.handleState({
          field: 'nutrientB',
          value: readBoolean(payload, ['ok', 'value']),
          requestId:
            typeof payload === 'object' && payload !== null
              ? payload.requestId ?? null
              : null,
          ts,
        });
        return;
      case topics.telemetryPh:
        logger?.info('Telemetry received', {
          deviceId: config.hydroDeviceId,
          field: 'ph',
          value: readNumber(payload, ['value', 'ph']),
        });
        deviceService.handleTelemetry({
          field: 'ph',
          value: readNumber(payload, ['value', 'ph']),
          ts,
        });
        return;
      case topics.telemetryEc:
        logger?.info('Telemetry received', {
          deviceId: config.hydroDeviceId,
          field: 'ec',
          value: readNumber(payload, ['value', 'ec']),
        });
        deviceService.handleTelemetry({
          field: 'ec',
          value: readNumber(payload, ['value', 'ec']),
          ts,
        });
        return;
      case topics.telemetryTemp:
        logger?.info('Telemetry received', {
          deviceId: config.hydroDeviceId,
          field: 'waterTemperature',
          value: readNumber(payload, ['value', 'temp', 'temperature', 'waterTemperature']),
        });
        deviceService.handleTelemetry({
          field: 'waterTemperature',
          value: readNumber(payload, ['value', 'temp', 'temperature', 'waterTemperature']),
          ts,
        });
        return;
      case topics.telemetryWaterLevel:
        logger?.info('Telemetry received', {
          deviceId: config.hydroDeviceId,
          field: 'waterLevel',
          value: readNumber(payload, ['value', 'level', 'waterLevel']),
        });
        deviceService.handleTelemetry({
          field: 'waterLevel',
          value: readNumber(payload, ['value', 'level', 'waterLevel']),
          ts,
        });
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
