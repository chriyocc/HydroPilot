const mqtt = require('mqtt');

function createMqttClient({ config }) {
  return mqtt.connect(config.mqttBrokerUrl, {
    username: config.mqttUsername,
    password: config.mqttPassword,
    reconnectPeriod: 1000,
  });
}

module.exports = {
  createMqttClient,
};
