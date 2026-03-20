const express = require('express');

const { createRouter } = require('./routes');
const errorHandler = require('./middleware/error-handler');

function createApp({ config, deviceService }) {
  const app = express();

  app.use(express.json());
  app.use('/api', createRouter({ config, deviceService }));
  app.use(errorHandler);

  return app;
}

module.exports = {
  createApp,
};
