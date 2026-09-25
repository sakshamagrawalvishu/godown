/**
 * Seed the initial OWNER account (run once per environment).
 *
 * Usage:
 *   ADMIN_EMAIL=owner@example.com ADMIN_PASSWORD=<secret> npm run seed:owner
 *
 * - Credentials come only from environment variables (never hardcoded,
 *   never printed, never committed).
 * - Idempotent: if a user with ADMIN_EMAIL already exists, nothing is
 *   created and the script exits successfully.
 * - The database connection uses the existing src/config/db setup.
 */

require('dotenv').config();

const mongoose = require('mongoose');
const User = require('../src/models/User');
const { connectDB } = require('../src/config/db');

async function main() {
  const email = String(process.env.ADMIN_EMAIL || '').toLowerCase().trim();
  const password = process.env.ADMIN_PASSWORD || '';
  const name = String(process.env.ADMIN_NAME || 'Owner').trim() || 'Owner';

  if (!email || !password) {
    // eslint-disable-next-line no-console
    console.error('Missing ADMIN_EMAIL or ADMIN_PASSWORD environment variables. Nothing was created.');
    process.exitCode = 1;
    return;
  }
  if (password.length < 6) {
    // eslint-disable-next-line no-console
    console.error('ADMIN_PASSWORD must be at least 6 characters. Nothing was created.');
    process.exitCode = 1;
    return;
  }

  const conn = await connectDB();
  if (!conn) {
    // eslint-disable-next-line no-console
    console.error('No database configured (MONGODB_URI missing or placeholder). Nothing was created.');
    process.exitCode = 1;
    return;
  }

  try {
    const existing = await User.findOne({ email });
    if (existing) {
      // eslint-disable-next-line no-console
      console.log(`Owner account already exists for ${email}. Nothing was created.`);
      return;
    }

    const owner = await User.create({ name, email, password, role: 'OWNER' });
    // eslint-disable-next-line no-console
    console.log(`Owner account created for ${owner.email}.`);
  } finally {
    await mongoose.disconnect();
  }
}

main().catch((err) => {
  // eslint-disable-next-line no-console
  console.error('Failed to seed owner:', err.message);
  process.exitCode = 1;
});
