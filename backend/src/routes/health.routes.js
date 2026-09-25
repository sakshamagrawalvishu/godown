const express = require('express');
const { getHealth } = require('../controllers/health.controller');

const router = express.Router();

// GET /health and GET /api/v1/health (mounted in src/routes/index.js)
router.get('/', getHealth);

module.exports = router;
