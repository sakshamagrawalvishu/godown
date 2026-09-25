const express = require('express');
const { authenticate, authorize } = require('../middleware/auth');
const { createStaff, listStaff } = require('../controllers/user.controller');

const router = express.Router();

// Staff management is OWNER-only: staff can never create owners
// nor manage other users.
router.use(authenticate, authorize('OWNER'));

router.post('/', createStaff);
router.get('/', listStaff);

module.exports = router;
