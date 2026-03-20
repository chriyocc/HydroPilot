function formatContext(context) {
  const entries = Object.entries(context).filter(([, value]) => value !== undefined);
  if (entries.length === 0) {
    return '';
  }

  const parts = entries.map(([key, value]) => `${key}=${String(value)}`);
  return ` | ${parts.join(' ')}`;
}

function write(level, message, context = {}) {
  const timestamp = new Date().toISOString();
  const line = `[${timestamp}] ${level.toUpperCase()} ${message}${formatContext(context)}`;
  process.stdout.write(`${line}\n`);
}

function createLogger() {
  return {
    info(message, context = {}) {
      write('info', message, context);
    },
    warn(message, context = {}) {
      write('warn', message, context);
    },
    error(message, context = {}) {
      write('error', message, context);
    },
  };
}

module.exports = {
  createLogger,
};
