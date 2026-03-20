const test = require('node:test');
const assert = require('node:assert/strict');
const EventEmitter = require('node:events');

const { createSnapshotStore } = require('../src/services/snapshot-store');
const { createEventStream } = require('../src/services/event-stream');
const { createCommandService } = require('../src/services/command-service');
const { createDeviceService } = require('../src/services/device-service');
const { createMqttGateway } = require('../src/lib/mqtt-gateway');

function createConfig() {
  return {
    port: 0,
    nodeEnv: 'test',
    mqttBrokerUrl: 'mqtt://broker.example',
    mqttUsername: 'hydro',
    mqttPassword: 'secret',
    hydroTopicPrefix: 'hydro',
    hydroDeviceId: 'device-1',
    commandTimeoutMs: 100,
    telemetryStaleMs: 30000,
    stateStaleMs: 15000,
  };
}

function createFakeMqttClient() {
  const emitter = new EventEmitter();
  const subscriptions = [];

  return {
    subscriptions,
    on: emitter.on.bind(emitter),
    emit: emitter.emit.bind(emitter),
    async subscribe(topics) {
      subscriptions.push(...topics);
    },
    async publish() {},
    end() {},
  };
}

function createLoggerRecorder() {
  const entries = [];

  return {
    entries,
    info(message, context = {}) {
      entries.push({ level: 'info', message, context });
    },
    warn(message, context = {}) {
      entries.push({ level: 'warn', message, context });
    },
    error(message, context = {}) {
      entries.push({ level: 'error', message, context });
    },
  };
}

test('mqtt gateway subscribes on connect and re-subscribes after reconnect', async () => {
  const config = createConfig();
  const snapshotStore = createSnapshotStore({ config, now: Date.now });
  const eventStream = createEventStream();
  const commandService = createCommandService({
    config,
    publisher: { publish: async () => {} },
    eventStream,
    now: Date.now,
  });
  const deviceService = createDeviceService({
    config,
    snapshotStore,
    eventStream,
    commandService,
  });
  const mqttClient = createFakeMqttClient();
  const gateway = createMqttGateway({
    config,
    mqttClient,
    deviceService,
  });

  gateway.start();
  await mqttClient.emit('connect');
  await mqttClient.emit('reconnect');

  assert.deepEqual(mqttClient.subscriptions, [
    'hydro/device/device-1/availability',
    'hydro/device/device-1/alarm',
    'hydro/device/device-1/state/pump',
    'hydro/device/device-1/state/light',
    'hydro/device/device-1/telemetry/ph',
    'hydro/device/device-1/telemetry/ec',
    'hydro/device/device-1/telemetry/temp',
    'hydro/device/device-1/telemetry/waterlevel',
    'hydro/device/device-1/availability',
    'hydro/device/device-1/alarm',
    'hydro/device/device-1/state/pump',
    'hydro/device/device-1/state/light',
    'hydro/device/device-1/telemetry/ph',
    'hydro/device/device-1/telemetry/ec',
    'hydro/device/device-1/telemetry/temp',
    'hydro/device/device-1/telemetry/waterlevel',
  ]);
});

test('mqtt gateway updates snapshot from incoming messages and resolves correlated commands', async () => {
  const now = () => 1_710_000_000_000;
  const config = createConfig();
  const snapshotStore = createSnapshotStore({ config, now });
  const eventStream = createEventStream();
  const publisher = { publish: async () => {} };
  const commandService = createCommandService({
    config,
    publisher,
    eventStream,
    now,
    scheduleTimeout: () => ({ trigger() {}, clear() {} }),
  });
  const deviceService = createDeviceService({
    config,
    snapshotStore,
    eventStream,
    commandService,
  });
  const mqttClient = createFakeMqttClient();
  const gateway = createMqttGateway({
    config,
    mqttClient,
    deviceService,
  });
  const events = [];

  eventStream.subscribe({
    writeEvent(eventName, payload) {
      events.push({ eventName, payload });
    },
    close() {},
  });

  gateway.start();
  await mqttClient.emit('connect');

  const accepted = await commandService.publishCommand({
    topic: 'hydro/device/device-1/cmd/pump',
    payload: { target: true },
  });

  await mqttClient.emit(
    'message',
    'hydro/device/device-1/state/pump',
    Buffer.from(
      JSON.stringify({
        requestId: accepted.requestId,
        on: true,
        ts: new Date(now()).toISOString(),
      }),
    ),
  );

  const snapshot = snapshotStore.getSnapshot();

  assert.equal(snapshot.deviceState.pumpOn, true);
  assert.equal(events.at(-1).eventName, 'command-result');
  assert.equal(events.at(-1).payload.status, 'succeeded');
});

test('mqtt gateway logs broker transitions and inbound summaries', async () => {
  const now = () => 1_710_000_000_000;
  const config = createConfig();
  const snapshotStore = createSnapshotStore({ config, now });
  const eventStream = createEventStream();
  const logger = createLoggerRecorder();
  const commandService = createCommandService({
    config,
    publisher: { publish: async () => {} },
    eventStream,
    now,
    logger,
  });
  const deviceService = createDeviceService({
    config,
    snapshotStore,
    eventStream,
    commandService,
    logger,
  });
  const mqttClient = createFakeMqttClient();
  const gateway = createMqttGateway({
    config,
    mqttClient,
    deviceService,
    logger,
  });

  gateway.start();
  await mqttClient.emit('connect');
  await mqttClient.emit(
    'message',
    'hydro/device/device-1/telemetry/ph',
    Buffer.from(JSON.stringify({ value: 6.3, ts: new Date(now()).toISOString() })),
  );
  await mqttClient.emit(
    'message',
    'hydro/device/device-1/availability',
    Buffer.from(JSON.stringify({ online: true, ts: new Date(now()).toISOString() })),
  );

  assert.deepEqual(
    logger.entries.map((entry) => entry.message),
    [
      'Broker status changed',
      'Broker status changed',
      'Subscribed to device topics',
      'Telemetry received',
      'Availability updated',
    ],
  );
});
