const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const { loadEnv } = require('../src/config/env');

test('loadEnv throws when required MQTT gateway configuration is missing', () => {
  assert.throws(
    () =>
      loadEnv({
        PORT: '3000',
        NODE_ENV: 'test',
      }, {
        envFilePath: path.join(os.tmpdir(), 'hydropilot-missing-env-file'),
      }),
    /Missing required environment variables/,
  );
});

test('loadEnv returns parsed config with defaults', () => {
  const config = loadEnv({
    PORT: '3001',
    NODE_ENV: 'test',
    MQTT_BROKER_URL: 'mqtt://broker.example',
    MQTT_USERNAME: 'hydro',
    MQTT_PASSWORD: 'secret',
    HYDRO_DEVICE_ID: 'device-1',
  });

  assert.equal(config.port, 3001);
  assert.equal(config.nodeEnv, 'test');
  assert.equal(config.mqttBrokerUrl, 'mqtt://broker.example');
  assert.equal(config.hydroTopicPrefix, 'hydro');
  assert.equal(config.commandTimeoutMs, 5000);
  assert.equal(config.telemetryStaleMs, 30000);
  assert.equal(config.stateStaleMs, 15000);
});

test('loadEnv falls back to values from a .env file', () => {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'hydropilot-env-'));
  const envFilePath = path.join(tempDir, '.env');

  fs.writeFileSync(
    envFilePath,
    [
      'MQTT_BROKER_URL=mqtts://broker.example:8883',
      'MQTT_USERNAME=hydro-user',
      'MQTT_PASSWORD=hydro-pass',
      'HYDRO_DEVICE_ID=device-from-file',
    ].join('\n'),
  );

  const config = loadEnv(
    {
      PORT: '3002',
      NODE_ENV: 'test',
    },
    { envFilePath },
  );

  assert.equal(config.port, 3002);
  assert.equal(config.mqttBrokerUrl, 'mqtts://broker.example:8883');
  assert.equal(config.mqttUsername, 'hydro-user');
  assert.equal(config.mqttPassword, 'hydro-pass');
  assert.equal(config.hydroDeviceId, 'device-from-file');
});
