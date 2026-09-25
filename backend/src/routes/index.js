const express = require('express');
const healthRoutes = require('./health.routes');
const authRoutes = require('./auth.routes');
const godownRoutes = require('./godown.routes');
const inventoryRoutes = require('./inventory.routes');
const userRoutes = require('./user.routes');

const router = express.Router();

// Liveness probes (no auth required by design).
router.use('/health', healthRoutes);
router.use('/api/v1/health', healthRoutes);

// Authentication (register/login public, /me protected inside authRoutes).
router.use('/api/auth', authRoutes);

// Staff management (OWNER only, enforced inside userRoutes).
router.use('/api/users', userRoutes);

// Godown + inventory (writes OWNER only, reads OWNER/STAFF — enforced in routes).
router.use('/api/godowns', godownRoutes);
router.use('/api/inventory', inventoryRoutes);

module.exports = router;
