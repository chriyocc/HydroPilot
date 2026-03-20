function createHttpError(statusCode, message) {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
}

function validateBooleanCommand(body) {
  const allowedKeys = new Set(['on', 'clientRequestId']);
  const bodyKeys = Object.keys(body ?? {});
  const hasUnknownKey = bodyKeys.some((key) => !allowedKeys.has(key));

  if (
    !body ||
    typeof body !== 'object' ||
    Array.isArray(body) ||
    hasUnknownKey ||
    typeof body.on !== 'boolean' ||
    ('clientRequestId' in body && typeof body.clientRequestId !== 'string')
  ) {
    throw createHttpError(
      400,
      'Command body must be {"on": boolean, "clientRequestId"?: string}.',
    );
  }
}

function validateDoseCommand(body) {
  const allowedKeys = new Set(['dose', 'clientRequestId']);
  const bodyKeys = Object.keys(body ?? {});
  const hasUnknownKey = bodyKeys.some((key) => !allowedKeys.has(key));

  if (
    !body ||
    typeof body !== 'object' ||
    Array.isArray(body) ||
    hasUnknownKey ||
    body.dose !== true ||
    ('clientRequestId' in body && typeof body.clientRequestId !== 'string')
  ) {
    throw createHttpError(
      400,
      'Command body must be {"dose": true, "clientRequestId"?: string}.',
    );
  }
}

function createDeviceController({ deviceService }) {
  async function getDevice(_request, response) {
    response.json(deviceService.getMetadata());
  }

  async function getDeviceStatus(_request, response) {
    response.json(deviceService.getStatus());
  }

  async function getDeviceEvents(request, response) {
    deviceService.openEventStream(request, response);
  }

  async function postPumpCommand(request, response) {
    validateBooleanCommand(request.body);
    const result = await deviceService.publishPumpCommand(request.body);
    response.status(202).json(result);
  }

  async function postLightCommand(request, response) {
    validateBooleanCommand(request.body);
    const result = await deviceService.publishLightCommand(request.body);
    response.status(202).json(result);
  }

  async function postNutrientACommand(request, response) {
    validateDoseCommand(request.body);
    const result = await deviceService.publishNutrientACommand(request.body);
    response.status(202).json(result);
  }

  async function postNutrientBCommand(request, response) {
    validateDoseCommand(request.body);
    const result = await deviceService.publishNutrientBCommand(request.body);
    response.status(202).json(result);
  }

  return {
    getDevice,
    getDeviceStatus,
    getDeviceEvents,
    postPumpCommand,
    postLightCommand,
    postNutrientACommand,
    postNutrientBCommand,
  };
}

module.exports = {
  createDeviceController,
};
