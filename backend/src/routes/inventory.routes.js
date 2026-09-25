const express = require('express');
const { authenticate, authorize } = require('../middleware/auth');
const { createItem, listItems, getItem, updateItem, deleteItem } = require('../controllers/inventory.controller');

const router = express.Router();

router.use(authenticate);

router.post('/', authorize('OWNER'), createItem);
router.get('/', authorize('OWNER', 'STAFF'), listItems);
router.get('/:id', authorize('OWNER', 'STAFF'), getItem);
router.put('/:id', authorize('OWNER'), updateItem);
router.delete('/:id', authorize('OWNER'), deleteItem);

module.exports = router;
