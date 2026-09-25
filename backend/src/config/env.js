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
};

module.exports = env;
