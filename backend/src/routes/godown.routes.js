const express = require('express');
const { authenticate, authorize } = require('../middleware/auth');
const { createGodown, listGodowns, getGodown, updateGodown, deleteGodown } = require('../controllers/godown.controller');

const router = express.Router();

router.use(authenticate);

router.post('/', authorize('OWNER'), createGodown);
router.get('/', authorize('OWNER', 'STAFF'), listGodowns);
router.get('/:id', authorize('OWNER', 'STAFF'), getGodown);
router.put('/:id', authorize('OWNER'), updateGodown);
router.delete('/:id', authorize('OWNER'), deleteGodown);

module.exports = router;
