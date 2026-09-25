/**
 * Central error handler (must be registered last in app.js).
 * Keeps error responses in a consistent shape.
 */

// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  // Mongoose validation errors.
  if (err && err.name === 'ValidationError') {
    return res.status(400).json({ success: false, message: err.message });
  }

  // Duplicate key (e.g. email already registered).
  if (err && err.code === 11000) {
    return res.status(409).json({ success: false, message: 'Duplicate value. Resource already exists.' });
  }

  // Malformed ObjectId that slipped past controller guards.
  if (err && err.name === 'CastError') {
    return res.status(400).json({ success: false, message: 'Invalid id format.' });
  }

  // JWT errors (only reached for flows that forward instead of responding).
  if (err && err.name === 'TokenExpiredError') {
    return res.status(401).json({ success: false, message: 'Token expired. Please log in again.' });
  }
  if (err && err.name === 'JsonWebTokenError') {
    return res.status(401).json({ success: false, message: 'Invalid token.' });
  }

  const statusCode = err.statusCode || 500;

  res.status(statusCode).json({
    success: false,
    message: err.message || 'Internal server error',
  });
}

module.exports = errorHandler;
