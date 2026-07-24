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

function validateToggleCommand(body) {
  const allowedKeys = new Set(['toggle', 'clientRequestId']);
  const bodyKeys = Object.keys(body ?? {});
  const hasUnknownKey = bodyKeys.some((key) => !allowedKeys.has(key));

  if (
    !body ||
    typeof body !== 'object' ||
    Array.isArray(body) ||
    hasUnknownKey ||
    body.toggle !== true ||
    ('clientRequestId' in body && typeof body.clientRequestId !== 'string')
  ) {
    throw createHttpError(
      400,
      'Command body must be {"toggle": true, "clientRequestId"?: string}.',
    );
  }
}

function validateStartCommand(body) {
  const allowedKeys = new Set(['start', 'clientRequestId']);
  const bodyKeys = Object.keys(body ?? {});
  const hasUnknownKey = bodyKeys.some((key) => !allowedKeys.has(key));

  if (
    !body ||
    typeof body !== 'object' ||
    Array.isArray(body) ||
    hasUnknownKey ||
    body.start !== true ||
    ('clientRequestId' in body && typeof body.clientRequestId !== 'string')
  ) {
    throw createHttpError(
      400,
      'Command body must be {"start": true, "clientRequestId"?: string}.',
    );
  }
}

function validateTargetDoseCommand(body) {
  const allowedKeys = new Set(['concentration', 'clientRequestId']);
  const bodyKeys = Object.keys(body ?? {});
  const hasUnknownKey = bodyKeys.some((key) => !allowedKeys.has(key));

  if (
    !body ||
    typeof body !== 'object' ||
    Array.isArray(body) ||
    hasUnknownKey ||
    typeof body.concentration !== 'number' ||
    !Number.isFinite(body.concentration) ||
    body.concentration < 0 ||
    ('clientRequestId' in body && typeof body.clientRequestId !== 'string')
  ) {
    throw createHttpError(
      400,
      'Command body must be {"concentration": number, "clientRequestId"?: string}.',
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

  async function getDeviceEcHistory(_request, response) {
    response.json(deviceService.getEcHistory());
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

  async function postPrimeACommand(request, response) {
    validateToggleCommand(request.body);
    const result = await deviceService.publishPrimeACommand(request.body);
    response.status(202).json(result);
  }

  async function postPrimeBCommand(request, response) {
    validateToggleCommand(request.body);
    const result = await deviceService.publishPrimeBCommand(request.body);
    response.status(202).json(result);
  }

  async function postTargetDoseACommand(request, response) {
    validateTargetDoseCommand(request.body);
    const result = await deviceService.publishTargetDoseACommand(request.body);
    response.status(202).json(result);
  }

  async function postTargetDoseBCommand(request, response) {
    validateTargetDoseCommand(request.body);
    const result = await deviceService.publishTargetDoseBCommand(request.body);
    response.status(202).json(result);
  }

  async function postTargetDoseAbCommand(request, response) {
    validateTargetDoseCommand(request.body);
    const result = await deviceService.publishTargetDoseAbCommand(request.body);
    response.status(202).json(result);
  }

  async function postShotDoseACommand(request, response) {
    validateStartCommand(request.body);
    const result = await deviceService.publishShotDoseACommand(request.body);
    response.status(202).json(result);
  }

  async function postShotDoseBCommand(request, response) {
    validateStartCommand(request.body);
    const result = await deviceService.publishShotDoseBCommand(request.body);
    response.status(202).json(result);
  }

  return {
    getDevice,
    getDeviceStatus,
    getDeviceEcHistory,
    getDeviceEvents,
    postPumpCommand,
    postLightCommand,
    postNutrientACommand,
    postNutrientBCommand,
    postPrimeACommand,
    postPrimeBCommand,
    postTargetDoseACommand,
    postTargetDoseBCommand,
    postTargetDoseAbCommand,
    postShotDoseACommand,
    postShotDoseBCommand,
  };
}

module.exports = {
  createDeviceController,
};
