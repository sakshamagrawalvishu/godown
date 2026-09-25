/**
 * Godown Management System — backend entry point.
 *
 * - Loads environment variables.
 * - Runs a safe startup check (JWT secret present, DB status reported).
 * - Connects to MongoDB unless the URI is missing/a placeholder.
 * - Starts the Express app. Exits non-zero on real connection failure.
 * - Never prints secrets or connection strings to the console.
 */

require('dotenv').config();

const app = require('./src/app');
const env = require('./src/config/env');
const { connectDB } = require('./src/config/db');

async function start() {
  // Safe startup check: warn (never print the value) when auth is unusable.
  if (!env.jwtSecret || env.jwtSecret.length < 16) {
    // eslint-disable-next-line no-console
    console.warn('WARNING: JWT_SECRET is missing or too short. Auth endpoints will fail until it is set in .env.');
  }

  const conn = await connectDB();
  if (!conn) {
    // eslint-disable-next-line no-console
    console.warn('Running WITHOUT a database: only /health works. Set MONGODB_URI in .env for full API.');
  }

  app.listen(env.port, () => {
    // eslint-disable-next-line no-console
    console.log(`Godown backend listening on port ${env.port} (${env.nodeEnv})`);
  });
}

start().catch((err) => {
  // eslint-disable-next-line no-console
  console.error('Failed to start server:', err);
  process.exit(1);
});
