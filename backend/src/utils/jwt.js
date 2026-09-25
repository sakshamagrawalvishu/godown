/**
 * JWT helpers.
 *
 * The secret always comes from environment variables (never hardcoded).
 * Sign/verify failures are surfaced to the central error handler.
 */

const jwt = require('jsonwebtoken');
const env = require('../config/env');

function requireJwtSecret() {
  if (!env.jwtSecret || env.jwtSecret.length < 16) {
    const err = new Error('JWT_SECRET is not configured. Set it in your .env file.');
    err.statusCode = 500;
    throw err;
  }
  return env.jwtSecret;
}

function signToken(user) {
  const secret = requireJwtSecret();
  return jwt.sign({ id: user._id.toString(), role: user.role }, secret, {
    expiresIn: env.jwtExpiresIn,
  });
}

function verifyToken(token) {
  return jwt.verify(token, requireJwtSecret());
}

module.exports = { signToken, verifyToken };
