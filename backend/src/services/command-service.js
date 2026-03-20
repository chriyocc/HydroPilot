const crypto = require('node:crypto');

function defaultScheduleTimeout(callback, delay) {
  const timer = setTimeout(callback, delay);
  return {
    clear() {
      clearTimeout(timer);
    },
    trigger: callback,
  };
}

function createCommandService({
  config,
  publisher,
  eventStream,
  now,
  logger,
  scheduleTimeout = defaultScheduleTimeout,
}) {
  const pendingCommands = new Map();
  const dedupeIndex = new Map();
  const dedupeTtlMs = config.commandTimeoutMs;

  function getTimestamp() {
    return new Date(now()).toISOString();
  }

  function publishEvent(status, requestId, detail = {}) {
    eventStream.publish('command-result', {
      deviceId: config.hydroDeviceId,
      requestId,
      status,
      ts: getTimestamp(),
      ...detail,
    });
  }

  async function publishCommand({ topic, payload, clientRequestId }) {
    if (clientRequestId) {
      const existing = dedupeIndex.get(clientRequestId);
      if (existing && existing.expiresAt > now()) {
        return existing.result;
      }
    }

    const requestId = crypto.randomUUID();
    const message = {
      requestId,
      ts: getTimestamp(),
      source: 'hydropilot-backend',
      ...payload,
    };

    await publisher.publish(topic, JSON.stringify(message));
    logger?.info('Command accepted', {
      deviceId: config.hydroDeviceId,
      topic,
      requestId,
    });

    const timeoutHandle = scheduleTimeout(() => {
      if (!pendingCommands.has(requestId)) {
        return;
      }

      pendingCommands.delete(requestId);
      logger?.warn('Command timed out', {
        deviceId: config.hydroDeviceId,
        requestId,
      });
      publishEvent('timeout', requestId);
    }, config.commandTimeoutMs);

    const result = {
      ok: true,
      status: 'accepted',
      requestId,
      timeoutHandle,
    };

    pendingCommands.set(requestId, {
      requestId,
      timeoutHandle,
    });

    if (clientRequestId) {
      dedupeIndex.set(clientRequestId, {
        expiresAt: now() + dedupeTtlMs,
        result,
      });
    }

    return result;
  }

  function completeCommand({ requestId, status, detail }) {
    if (!requestId) {
      return false;
    }

    const pending = pendingCommands.get(requestId);
    if (!pending) {
      return false;
    }

    pending.timeoutHandle.clear();
    pendingCommands.delete(requestId);
    logger?.info('Command completed', {
      deviceId: config.hydroDeviceId,
      requestId,
      status,
    });
    publishEvent(status, requestId, detail);
    return true;
  }

  return {
    publishCommand,
    completeCommand,
  };
}

module.exports = {
  createCommandService,
};
