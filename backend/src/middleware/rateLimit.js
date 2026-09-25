/**
 * Authentication rate limiter (express-rate-limit).
 *
 * - Applied ONLY to POST /api/auth/register and POST /api/auth/login
 *   (see routes/auth.routes.js). Authenticated routes (/me, users,
 *   godowns, inventory, health) are intentionally NOT limited here.
 * - Window/max come from environment (AUTH_RATE_LIMIT_WINDOW_MS,
 *   AUTH_RATE_LIMIT_MAX) with safe development defaults.
 * - The 429 response keeps the API envelope {success, message} and never
 *   includes tokens, passwords, emails, or secrets.
 * - Default MemoryStore is per-process: sufficient for a single instance.
 *   Use an external store (e.g. Redis) when running multiple instances.
 */

const rateLimit = require('express-rate-limit');
const env = require('../config/env');

const authRateLimiter = rateLimit({
  windowMs: env.authRateLimitWindowMs,
  max: env.authRateLimitMax,
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) =>
    res.status(429).json({
      success: false,
      message: 'Too many authentication attempts. Please try again later.',
    }),
});

module.exports = { authRateLimiter };
