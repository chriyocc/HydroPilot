const express = require('express');

const { createDeviceController } = require('../controllers/device.controller');
const { createHealthController } = require('../controllers/health.controller');

function createRouter({ config, deviceService }) {
  const router = express.Router();
  const healthController = createHealthController({ deviceService });
  const deviceController = createDeviceController({ config, deviceService });

  router.get('/health', healthController.getHealth);
  router.get('/device', deviceController.getDevice);
  router.get('/device/status', deviceController.getDeviceStatus);
  router.get('/device/ec-history', deviceController.getDeviceEcHistory);
  router.get('/device/events', deviceController.getDeviceEvents);
  router.post('/device/commands/pump', deviceController.postPumpCommand);
  router.post('/device/commands/light', deviceController.postLightCommand);
  router.post(
    '/device/commands/nutrient/a',
    deviceController.postNutrientACommand,
  );
  router.post(
    '/device/commands/nutrient/b',
    deviceController.postNutrientBCommand,
  );
  router.post('/device/commands/prime/a', deviceController.postPrimeACommand);
  router.post('/device/commands/prime/b', deviceController.postPrimeBCommand);
  router.post(
    '/device/commands/target-dose/a',
    deviceController.postTargetDoseACommand,
  );
  router.post(
    '/device/commands/target-dose/b',
    deviceController.postTargetDoseBCommand,
  );
  router.post(
    '/device/commands/target-dose/ab',
    deviceController.postTargetDoseAbCommand,
  );
  router.post(
    '/device/commands/shot-dose/a',
    deviceController.postShotDoseACommand,
  );
  router.post(
    '/device/commands/shot-dose/b',
    deviceController.postShotDoseBCommand,
  );

  return router;
}

module.exports = {
  createRouter,
};
