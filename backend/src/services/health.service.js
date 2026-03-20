function getStatus({ brokerConnected }) {
  return {
    ok: true,
    service: 'hydropilot-backend',
    brokerConnected,
  };
}

module.exports = {
  getStatus,
};
