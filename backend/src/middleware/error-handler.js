function errorHandler(error, _request, response, _next) {
  const statusCode = error.statusCode ?? 500;

  response.status(statusCode).json({
    ok: false,
    error: error.message || 'Internal server error',
  });
}

module.exports = errorHandler;
