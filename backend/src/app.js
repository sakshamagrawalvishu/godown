/**
 * Express application composition (Phase B scaffold).
 *
 * Middleware order:
 * 1. Security / parsing / logging
 * 2. API routes
 * 3. 404 handler
 * 4. Central error handler
 */

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const routes = require('./routes');
const notFound = require('./middleware/notFound');
const errorHandler = require('./middleware/errorHandler');
const env = require('./config/env');

const app = express();

// The API runs behind a hosting proxy in production (Render/Heroku/etc).
// Trusting the first proxy keeps req.ip accurate for logging and the
// authentication rate limiter. Never log tokens, passwords, or secrets.
app.set('trust proxy', 1);

app.use(helmet());

// CORS: configurable allowlist via CORS_ORIGINS (comma-separated).
// Empty preserves open development behavior; a configured list restricts
// browser cross-origin access to those origins. Bearer-token auth uses no
// cookies, so credentials are not required. Native mobile clients and curl
// are unaffected by CORS either way.
if (env.corsOrigins.length === 0) {
  // eslint-disable-next-line no-console
  console.warn('WARNING: CORS_ORIGINS is empty — CORS is unrestricted. Set CORS_ORIGINS in production.');
  app.use(cors());
} else {
  app.use(cors({ origin: env.corsOrigins }));
}
app.use(express.json({ limit: '1mb' }));
app.use(morgan('dev'));

// Root + versioned API routes (see src/routes/index.js)
app.use(routes);

// 404 for unknown routes — must come after routes.
app.use(notFound);

// Central error handler — must be the last middleware.
app.use(errorHandler);

module.exports = app;
