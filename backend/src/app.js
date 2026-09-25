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

const app = express();

app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '1mb' }));
app.use(morgan('dev'));

// Root + versioned API routes (see src/routes/index.js)
app.use(routes);

// 404 for unknown routes — must come after routes.
app.use(notFound);

// Central error handler — must be the last middleware.
app.use(errorHandler);

module.exports = app;
