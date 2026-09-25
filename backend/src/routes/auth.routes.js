const express = require('express');
const { register, login, me } = require('../controllers/auth.controller');
const { authenticate } = require('../middleware/auth');
const { authRateLimiter } = require('../middleware/rateLimit');

const router = express.Router();

// Strict limiting on public auth endpoints only. GET /me and all
// authenticated CRUD routes are intentionally NOT rate limited here.
router.post('/register', authRateLimiter, register);
router.post('/login', authRateLimiter, login);
router.get('/me', authenticate, me);

module.exports = router;
