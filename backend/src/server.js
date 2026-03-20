const { createApp } = require('./app');
const { loadEnv } = require('./config/env');
const { createLogger } = require('./lib/logger');
const { createMqttClient } = require('./lib/mqtt-client');
const { createMqttGateway } = require('./lib/mqtt-gateway');
const { createCommandService } = require('./services/command-service');
const { createDeviceService } = require('./services/device-service');
const { createEventStream } = require('./services/event-stream');
const { createSnapshotStore } = require('./services/snapshot-store');

const config = loadEnv();
const logger = createLogger();
const snapshotStore = createSnapshotStore({ config, now: Date.now });
const eventStream = createEventStream();
const mqttClient = createMqttClient({ config });
const commandService = createCommandService({
  config,
  publisher: mqttClient,
  eventStream,
  now: Date.now,
  logger,
});
const deviceService = createDeviceService({
  config,
  snapshotStore,
  eventStream,
  commandService,
  logger,
});
const gateway = createMqttGateway({
  config,
  mqttClient,
  deviceService,
  logger,
});
const app = createApp({ config, deviceService });

gateway.start();

app.listen(config.port, () => {
  logger.info('Backend started', {
    port: config.port,
    deviceId: config.hydroDeviceId,
  });
  console.log(`HydroPilot backend listening on port ${config.port}`);
});
