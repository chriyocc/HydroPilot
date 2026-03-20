function createHealthController({ deviceService }) {
  function getHealth(_request, response) {
    response.json(deviceService.getHealth());
  }

  return {
    getHealth,
  };
}

module.exports = {
  createHealthController,
};
