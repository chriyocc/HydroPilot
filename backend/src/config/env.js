const fs = require('node:fs');
const path = require('node:path');

const dotenv = require('dotenv');

function parseInteger(value, fallback) {
  const parsed = Number.parseInt(value ?? '', 10);
  return Number.isNaN(parsed) ? fallback : parsed;
}

function loadDotEnvFile(envFilePath) {
  if (!fs.existsSync(envFilePath)) {
    return {};
  }

  const fileContents = fs.readFileSync(envFilePath, 'utf8');
  return dotenv.parse(fileContents);
}

function loadEnv(source = process.env, options = {}) {
  const envFilePath = options.envFilePath ?? path.resolve(process.cwd(), '.env');
  const fileValues = loadDotEnvFile(envFilePath);
  const mergedSource = {
    ...fileValues,
    ...source,
  };
  const requiredKeys = [
    'MQTT_BROKER_URL',
    'MQTT_USERNAME',
    'MQTT_PASSWORD',
    'HYDRO_DEVICE_ID',
  ];
  const missingKeys = requiredKeys.filter((key) => {
    const value = mergedSource[key];
    return typeof value !== 'string' || value.trim().length === 0;
  });

  if (missingKeys.length > 0) {
    throw new Error(
      `Missing required environment variables: ${missingKeys.join(', ')}`,
    );
  }

  return {
    port: parseInteger(mergedSource.PORT, 3000),
    nodeEnv: mergedSource.NODE_ENV ?? 'development',
    mqttBrokerUrl: mergedSource.MQTT_BROKER_URL,
    mqttUsername: mergedSource.MQTT_USERNAME,
    mqttPassword: mergedSource.MQTT_PASSWORD,
    hydroTopicPrefix: mergedSource.HYDRO_TOPIC_PREFIX ?? 'hydro',
    hydroDeviceId: mergedSource.HYDRO_DEVICE_ID,
    commandTimeoutMs: parseInteger(mergedSource.COMMAND_TIMEOUT_MS, 5000),
    telemetryStaleMs: parseInteger(mergedSource.TELEMETRY_STALE_MS, 30000),
    stateStaleMs: parseInteger(mergedSource.STATE_STALE_MS, 15000),
  };
}

module.exports = {
  loadEnv,
};
