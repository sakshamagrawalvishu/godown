/**
 * Health controller — reports service liveness.
 */

const env = require('../config/env');

function getHealth(req, res) {
  res.status(200).json({
    success: true,
    message: 'Godown backend is running',
    data: {
      status: 'ok',
      env: env.nodeEnv,
      timestamp: new Date().toISOString(),
    },
  });
}

module.exports = { getHealth };
