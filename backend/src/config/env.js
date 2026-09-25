/**
 * Environment configuration.
 *
 * Reads process.env with safe defaults. Never commit real secrets —
 * copy ../.env.example to .env locally and fill in your own values.
 */

const env = {
  nodeEnv: process.env.NODE_ENV || 'development',
  port: Number(process.env.PORT || 5000),
  mongodbUri: process.env.MONGODB_URI || '',
  jwtSecret: process.env.JWT_SECRET || '',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  // Comma-separated allowlist, e.g. "https://app.example.com,https://admin.example.com".
  // Empty preserves open development behavior (with a boot warning in app.js).
  corsOrigins: (process.env.CORS_ORIGINS || '')
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean),
  // Authentication rate limiting (see src/middleware/rateLimit.js).
  authRateLimitWindowMs: Number(process.env.AUTH_RATE_LIMIT_WINDOW_MS || 900000),
  authRateLimitMax: Number(process.env.AUTH_RATE_LIMIT_MAX || 100),
};

module.exports = env;
