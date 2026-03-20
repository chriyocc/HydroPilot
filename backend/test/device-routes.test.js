const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { once } = require('node:events');

const { createApp } = require('../src/app');
const { createSnapshotStore } = require('../src/services/snapshot-store');
const { createEventStream } = require('../src/services/event-stream');
const { createCommandService } = require('../src/services/command-service');
const { createDeviceService } = require('../src/services/device-service');

function createConfig(overrides = {}) {
  return {
    port: 0,
    nodeEnv: 'test',
    mqttBrokerUrl: 'mqtt://broker.example',
    mqttUsername: 'hydro',
    mqttPassword: 'secret',
    hydroTopicPrefix: 'hydro',
    hydroDeviceId: 'device-1',
    commandTimeoutMs: 50,
    telemetryStaleMs: 40,
    stateStaleMs: 30,
    ...overrides,
  };
}

function createClock(start = 1_710_000_000_000) {
  let current = start;

  return {
    now: () => current,
    advance: (ms) => {
      current += ms;
      return current;
    },
  };
}

function createPublishRecorder() {
  const calls = [];

  return {
    calls,
    async publish(topic, payload) {
      calls.push({ topic, payload });
    },
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

async function startServer(app) {
  const server = http.createServer(app);
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');

  const address = server.address();
  const baseUrl = `http://127.0.0.1:${address.port}`;

  return {
    server,
    baseUrl,
    close: () =>
      new Promise((resolve, reject) => {
        server.close((error) => (error ? reject(error) : resolve()));
      }),
  };
}

test('GET /api/device and /api/device/status stay semantically distinct', async () => {
  const clock = createClock();
  const config = createConfig();
  const snapshotStore = createSnapshotStore({ config, now: clock.now });
  const eventStream = createEventStream();
  const commandService = createCommandService({
    config,
    publisher: createPublishRecorder(),
    eventStream,
    now: clock.now,
  });
  const deviceService = createDeviceService({
    config,
    snapshotStore,
    eventStream,
    commandService,
  });
  const app = createApp({ config, deviceService });
  const server = await startServer(app);

  try {
    const deviceResponse = await fetch(`${server.baseUrl}/api/device`);
    const statusResponse = await fetch(`${server.baseUrl}/api/device/status`);

    assert.equal(deviceResponse.status, 200);
    assert.equal(statusResponse.status, 200);

    const device = await deviceResponse.json();
    const status = await statusResponse.json();

    assert.equal(device.deviceId, 'device-1');
    assert.equal(device.topicPrefix, 'hydro');
    assert.equal(device.capabilities.commands.pump, true);
    assert.equal(device.capabilities.commands.nutrientA, true);
    assert.equal(status.deviceId, 'device-1');
    assert.equal(status.sensors.ph, null);
    assert.equal(status.deviceState.pumpOn, null);
    assert.equal(status.availability.online, null);
    assert.equal(status.freshness.offline, true);
  } finally {
    await server.close();
  }
});

test('GET /api/device/status marks telemetry and state stale based on configured windows', () => {
  const clock = createClock();
  const config = createConfig();
  const snapshotStore = createSnapshotStore({ config, now: clock.now });

  snapshotStore.applyTelemetry({
    field: 'ph',
    value: 6.2,
    ts: new Date(clock.now()).toISOString(),
  });
  snapshotStore.applyState({
    field: 'pumpOn',
    value: true,
    ts: new Date(clock.now()).toISOString(),
  });

  clock.advance(31);
  let snapshot = snapshotStore.getSnapshot();
  assert.equal(snapshot.freshness.staleState, true);
  assert.equal(snapshot.freshness.staleTelemetry, false);

  clock.advance(10);
  snapshot = snapshotStore.getSnapshot();
  assert.equal(snapshot.freshness.staleTelemetry, true);
});

test('POST /api/device/commands/pump accepts command publication and rejects unknown fields', async () => {
  const clock = createClock();
  const config = createConfig();
  const publisher = createPublishRecorder();
  const snapshotStore = createSnapshotStore({ config, now: clock.now });
  const eventStream = createEventStream();
  const commandService = createCommandService({
    config,
    publisher,
    eventStream,
    now: clock.now,
  });
  const deviceService = createDeviceService({
    config,
    snapshotStore,
    eventStream,
    commandService,
  });
  const app = createApp({ config, deviceService });
  const server = await startServer(app);

  try {
    const invalidResponse = await fetch(`${server.baseUrl}/api/device/commands/pump`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ on: true, extra: 'nope' }),
    });

    assert.equal(invalidResponse.status, 400);

    const acceptedResponse = await fetch(`${server.baseUrl}/api/device/commands/pump`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ on: true, clientRequestId: 'client-1' }),
    });

    assert.equal(acceptedResponse.status, 202);

    const body = await acceptedResponse.json();
    assert.equal(body.ok, true);
    assert.equal(body.status, 'accepted');
    assert.match(body.requestId, /-/);
    assert.equal(publisher.calls.length, 1);
    assert.equal(
      publisher.calls[0].topic,
      'hydro/device/device-1/cmd/pump',
    );
  } finally {
    await server.close();
  }
});

test('SSE sends initial snapshot and later delta events', async () => {
  const clock = createClock();
  const config = createConfig();
  const snapshotStore = createSnapshotStore({ config, now: clock.now });
  const eventStream = createEventStream();
  const commandService = createCommandService({
    config,
    publisher: createPublishRecorder(),
    eventStream,
    now: clock.now,
  });
  const deviceService = createDeviceService({
    config,
    snapshotStore,
    eventStream,
    commandService,
  });
  const app = createApp({ config, deviceService });
  const server = await startServer(app);

  try {
    const response = await fetch(`${server.baseUrl}/api/device/events`, {
      headers: { accept: 'text/event-stream' },
    });

    assert.equal(response.status, 200);

    const reader = response.body.getReader();
    const firstChunk = await reader.read();
    const initialText = Buffer.from(firstChunk.value).toString('utf8');
    assert.match(initialText, /event: snapshot/);

    deviceService.handleTelemetry({
      field: 'ph',
      value: 6.4,
      ts: new Date(clock.now()).toISOString(),
    });

    const nextChunk = await reader.read();
    const nextText = Buffer.from(nextChunk.value).toString('utf8');
    assert.match(nextText, /event: telemetry/);
    assert.match(nextText, /"field":"ph"/);

    await reader.cancel();
  } finally {
    await server.close();
  }
});

test('command service emits timeout and deduplicates clientRequestId within TTL', async () => {
  const clock = createClock();
  const config = createConfig({ commandTimeoutMs: 20 });
  const publisher = createPublishRecorder();
  const eventStream = createEventStream();
  const commandService = createCommandService({
    config,
    publisher,
    eventStream,
    now: clock.now,
    scheduleTimeout: (callback) => ({
      trigger: callback,
      clear() {},
    }),
  });

  const accepted = await commandService.publishCommand({
    topic: 'hydro/device/device-1/cmd/pump',
    payload: { target: true },
    clientRequestId: 'client-1',
  });

  const duplicate = await commandService.publishCommand({
    topic: 'hydro/device/device-1/cmd/pump',
    payload: { target: true },
    clientRequestId: 'client-1',
  });

  assert.equal(duplicate.requestId, accepted.requestId);
  assert.equal(publisher.calls.length, 1);

  const timeoutEvents = [];
  eventStream.subscribe({
    writeEvent(eventName, payload) {
      timeoutEvents.push({ eventName, payload });
    },
    close() {},
  });

  accepted.timeoutHandle.trigger();

  assert.equal(timeoutEvents[0].eventName, 'command-result');
  assert.equal(timeoutEvents[0].payload.status, 'timeout');
});

test('command service logs accepted and timeout command lifecycle events', async () => {
  const clock = createClock();
  const config = createConfig({ commandTimeoutMs: 20 });
  const logger = createLoggerRecorder();
  const commandService = createCommandService({
    config,
    publisher: createPublishRecorder(),
    eventStream: createEventStream(),
    now: clock.now,
    logger,
    scheduleTimeout: (callback) => ({
      trigger: callback,
      clear() {},
    }),
  });

  const accepted = await commandService.publishCommand({
    topic: 'hydro/device/device-1/cmd/light',
    payload: { target: true },
    clientRequestId: 'log-test-1',
  });

  accepted.timeoutHandle.trigger();

  assert.deepEqual(
    logger.entries.map((entry) => entry.message),
    ['Command accepted', 'Command timed out'],
  );
});
