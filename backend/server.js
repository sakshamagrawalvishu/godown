/**
 * Godown Management System — backend entry point.
 *
 * - Loads environment variables.
 * - Runs a safe startup check (JWT secret present, DB status reported).
 * - Connects to MongoDB unless the URI is missing/a placeholder.
 * - Starts the Express app. Exits non-zero on real connection failure.
 * - Handles SIGTERM/SIGINT for graceful shutdown (stops accepting new
 *   connections, closes the server, disconnects MongoDB, then exits).
 * - Never prints secrets or connection strings to the console.
 */

require('dotenv').config();

const mongoose = require('mongoose');
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

  const server = app.listen(env.port, () => {
    // eslint-disable-next-line no-console
    console.log(`Godown backend listening on port ${env.port} (${env.nodeEnv})`);
  });

  registerGracefulShutdown(server);

  return server;
}

/**
 * Graceful shutdown for hosting redeploys/scale-down.
 *
 * Stops accepting new connections, waits for in-flight requests via
 * server.close(), disconnects MongoDB, then exits cleanly. A safety
 * timer forces exit if connections hang. Safe to trigger twice.
 */
function registerGracefulShutdown(server) {
  let shuttingDown = false;

  const shutdown = (signal) => {
    if (shuttingDown) return;
    shuttingDown = true;
    // eslint-disable-next-line no-console
    console.log(`Received ${signal}. Shutting down gracefully...`);
    server.close(async () => {
      try {
        await mongoose.disconnect();
      } catch (err) {
        // eslint-disable-next-line no-console
        console.error('Error disconnecting MongoDB:', err.message);
      } finally {
        process.exit(0);
      }
    });
    setTimeout(() => {
      // eslint-disable-next-line no-console
      console.error('Graceful shutdown timed out. Forcing exit.');
      process.exit(1);
    }, 10000).unref();
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}

start().catch((err) => {
  // eslint-disable-next-line no-console
  console.error('Failed to start server:', err);
  process.exit(1);
});
