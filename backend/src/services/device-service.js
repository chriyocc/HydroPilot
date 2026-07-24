const healthService = require('./health.service');
const { createTopicMap } = require('../lib/mqtt-gateway');

function createDeviceService({
  config,
  snapshotStore,
  eventStream,
  commandService,
  logger,
}) {
  const topics = createTopicMap(config);

  function getMetadata() {
    return {
      deviceId: config.hydroDeviceId,
      topicPrefix: config.hydroTopicPrefix,
      capabilities: {
        commands: {
          pump: true,
          light: true,
        nutrientA: true,
        nutrientB: true,
        primeA: true,
        primeB: true,
        targetDoseA: true,
        targetDoseB: true,
        targetDoseAb: true,
        shotDoseA: true,
        shotDoseB: true,
      },
        streaming: {
          sse: true,
        },
      },
      freshness: {
        telemetryStaleMs: config.telemetryStaleMs,
        stateStaleMs: config.stateStaleMs,
      },
    };
  }

  function getStatus() {
    return snapshotStore.getSnapshot();
  }

  function getEcHistory() {
    const snapshot = snapshotStore.getSnapshot();
    return snapshot.ecHistory;
  }

  function getHealth() {
    return healthService.getStatus({
      brokerConnected: snapshotStore.getSnapshot().broker.connected,
    });
  }

  function openEventStream(request, response) {
    response.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      Connection: 'keep-alive',
    });

    const client = {
      writeEvent(eventName, payload) {
        response.write(`event: ${eventName}\n`);
        response.write(`data: ${JSON.stringify(payload)}\n\n`);
      },
      close() {
        response.end();
      },
    };

    const unsubscribe = eventStream.subscribe(client);
    client.writeEvent('snapshot', getStatus());
    request.on('close', unsubscribe);
  }

  function handleTelemetry({ field, value, ts }) {
    snapshotStore.applyTelemetry({ field, value, ts });
    eventStream.publish('telemetry', {
      deviceId: config.hydroDeviceId,
      field,
      value,
      ts,
    });
  }

  function handleState({ field, value, requestId, ts }) {
    snapshotStore.applyState({ field, value, ts });
    eventStream.publish('state', {
      deviceId: config.hydroDeviceId,
      field,
      value,
      ts,
    });
    commandService.completeCommand({
      requestId,
      status: 'succeeded',
      detail: {
        field,
        value,
      },
    });
  }

  function handleAvailability({ online, status, ts }) {
    snapshotStore.applyAvailability({ online, status, ts });
    logger?.info('Availability updated', {
      deviceId: config.hydroDeviceId,
      online,
      status,
    });
    eventStream.publish('availability', {
      deviceId: config.hydroDeviceId,
      online,
      status,
      ts,
    });
  }

  function handleAlarm({ payload, ts }) {
    snapshotStore.applyAlarm({ payload, ts });
    eventStream.publish('alarm', {
      deviceId: config.hydroDeviceId,
      payload,
      ts,
    });
  }

  function handleEcHistory({ periodMs, windowMs, ecValues, ts }) {
    snapshotStore.applyEcHistory({ periodMs, windowMs, ecValues, ts });
    eventStream.publish('ec-history', {
      deviceId: config.hydroDeviceId,
      periodMs,
      windowMs,
      ecValues,
      ts,
    });
  }

  function setBrokerStatus(status) {
    snapshotStore.setBrokerStatus(status);
    logger?.info('Broker status changed', {
      deviceId: config.hydroDeviceId,
      status,
    });
    eventStream.publish('broker-status', {
      deviceId: config.hydroDeviceId,
      status,
      ts: new Date().toISOString(),
    });
  }

  async function publishPumpCommand({ on, clientRequestId }) {
    const result = await commandService.publishCommand({
      topic: topics.cmdPump,
      payload: { target: on },
      clientRequestId,
    });
    return {
      ok: result.ok,
      requestId: result.requestId,
      status: result.status,
    };
  }

  async function publishLightCommand({ on, clientRequestId }) {
    const result = await commandService.publishCommand({
      topic: topics.cmdLight,
      payload: { target: on },
      clientRequestId,
    });
    return {
      ok: result.ok,
      requestId: result.requestId,
      status: result.status,
    };
  }

  async function publishNutrientACommand({ clientRequestId }) {
    const result = await commandService.publishCommand({
      topic: topics.cmdNutrientA,
      payload: { action: 'dose' },
      clientRequestId,
    });
    return {
      ok: result.ok,
      requestId: result.requestId,
      status: result.status,
    };
  }

  async function publishNutrientBCommand({ clientRequestId }) {
    const result = await commandService.publishCommand({
      topic: topics.cmdNutrientB,
      payload: { action: 'dose' },
      clientRequestId,
    });
    return {
      ok: result.ok,
      requestId: result.requestId,
      status: result.status,
    };
  }

  async function publishPrimeACommand({ clientRequestId }) {
    const result = await commandService.publishCommand({
      topic: topics.cmdPrimeA,
      payload: { action: 'toggle' },
      clientRequestId,
    });
    return {
      ok: result.ok,
      requestId: result.requestId,
      status: result.status,
    };
  }

  async function publishPrimeBCommand({ clientRequestId }) {
    const result = await commandService.publishCommand({
      topic: topics.cmdPrimeB,
      payload: { action: 'toggle' },
      clientRequestId,
    });
    return {
      ok: result.ok,
      requestId: result.requestId,
      status: result.status,
    };
  }

  async function publishTargetDoseACommand({ concentration, clientRequestId }) {
    const result = await commandService.publishCommand({
      topic: topics.cmdTargetDoseA,
      payload: { action: 'toggle', concentration },
      clientRequestId,
    });
    return {
      ok: result.ok,
      requestId: result.requestId,
      status: result.status,
    };
  }

  async function publishTargetDoseBCommand({ concentration, clientRequestId }) {
    const result = await commandService.publishCommand({
      topic: topics.cmdTargetDoseB,
      payload: { action: 'toggle', concentration },
      clientRequestId,
    });
    return {
      ok: result.ok,
      requestId: result.requestId,
      status: result.status,
    };
  }

  async function publishTargetDoseAbCommand({ concentration, clientRequestId }) {
    const result = await commandService.publishCommand({
      topic: topics.cmdTargetDoseAb,
      payload: { action: 'toggle', concentration },
      clientRequestId,
    });
    return {
      ok: result.ok,
      requestId: result.requestId,
      status: result.status,
    };
  }

  async function publishShotDoseACommand({ clientRequestId }) {
    const result = await commandService.publishCommand({
      topic: topics.cmdShotDoseA,
      payload: { action: 'start' },
      clientRequestId,
    });
    return {
      ok: result.ok,
      requestId: result.requestId,
      status: result.status,
    };
  }

  async function publishShotDoseBCommand({ clientRequestId }) {
    const result = await commandService.publishCommand({
      topic: topics.cmdShotDoseB,
      payload: { action: 'start' },
      clientRequestId,
    });
    return {
      ok: result.ok,
      requestId: result.requestId,
      status: result.status,
    };
  }

  return {
    getMetadata,
    getStatus,
    getEcHistory,
    getHealth,
    openEventStream,
    handleTelemetry,
    handleState,
    handleAvailability,
    handleAlarm,
    handleEcHistory,
    setBrokerStatus,
    publishPumpCommand,
    publishLightCommand,
    publishNutrientACommand,
    publishNutrientBCommand,
    publishPrimeACommand,
    publishPrimeBCommand,
    publishTargetDoseACommand,
    publishTargetDoseBCommand,
    publishTargetDoseAbCommand,
    publishShotDoseACommand,
    publishShotDoseBCommand,
  };
}

module.exports = {
  createDeviceService,
};
