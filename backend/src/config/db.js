/**
 * MongoDB Atlas connection via Mongoose.
 *
 * - Connection string comes only from MONGODB_URI (never hardcoded).
 * - Skips connecting when the URI is missing or still a placeholder,
 *   so the API (health check) still runs without a database.
 * - Throws on real connection errors so startup fails safely.
 */

const mongoose = require('mongoose');
const env = require('./env');

const PLACEHOLDER_MARKERS = ['your_', 'placeholder', 'example', 'changeme'];

function isPlaceholderUri(uri) {
  if (!uri) return true;
  const lowered = String(uri).toLowerCase();
  return PLACEHOLDER_MARKERS.some((marker) => lowered.includes(marker));
}

async function connectDB() {
  if (isPlaceholderUri(env.mongodbUri)) {
    // eslint-disable-next-line no-console
    console.log('Skipping MongoDB connection (no real MONGODB_URI configured).');
    return null;
  }

  try {
    mongoose.set('strictQuery', true);
    const conn = await mongoose.connect(env.mongodbUri);
    // eslint-disable-next-line no-console
    console.log(`MongoDB connected: ${conn.connection.host}`);
    return conn;
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('MongoDB connection failed:', err.message);
    throw err;
  }
}

module.exports = { connectDB, isPlaceholderUri };
