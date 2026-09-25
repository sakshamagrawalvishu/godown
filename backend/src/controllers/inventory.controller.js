/**
 * Inventory controllers — multi-owner isolation enforced in the backend.
 *
 * Writes (create/update/delete) are OWNER-only (enforced in routes).
 * Reads are OWNER/STAFF (enforced in routes) but always scoped through
 * the parent Godown's ownership. Cross-owner access by ID returns 404.
 */

const mongoose = require('mongoose');
const Godown = require('../models/Godown');
const InventoryItem = require('../models/InventoryItem');
const asyncHandler = require('../utils/asyncHandler');
const { requireOwnerScope } = require('../utils/ownership');

function badId(res, id, label) {
  if (!mongoose.isValidObjectId(id)) {
    res.status(400).json({ success: false, message: `Invalid ${label || 'id'}.` });
    return true;
  }
  return false;
}

function validateQuantity(quantity) {
  return typeof quantity === 'number' && Number.isFinite(quantity) && quantity >= 0;
}

async function ownedGodownExists(godownId, ownerId) {
  return Godown.exists({ _id: godownId, owner: ownerId });
}

async function ownedGodownIds(ownerId) {
  const godowns = await Godown.find({ owner: ownerId }).select('_id');
  return godowns.map((g) => g._id);
}

/** Returns true when the item's godown belongs to ownerId. */
async function itemBelongsToOwner(item, ownerId) {
  if (!item || !item.godown) return false;
  const godownId = item.godown._id ? item.godown._id : item.godown;
  return !!(await ownedGodownExists(godownId, ownerId));
}

const createItem = asyncHandler(async (req, res) => {
  const { itemName, quantity, unit, godown } = req.body || {};

  if (!itemName || quantity === undefined || quantity === null || !unit || !godown) {
    return res.status(400).json({
      success: false,
      message: 'itemName, quantity, unit and godown are required.',
    });
  }
  if (!validateQuantity(quantity)) {
    return res.status(400).json({ success: false, message: 'Quantity must be a non-negative number.' });
  }
  if (badId(res, godown, 'godown id')) return undefined;
  const ownerId = await requireOwnerScope(req, res);
  if (!ownerId) return undefined;
  if (!(await ownedGodownExists(godown, ownerId))) {
    return res.status(404).json({ success: false, message: 'Godown not found.' });
  }

  const item = await InventoryItem.create({
    itemName: String(itemName).trim(),
    quantity,
    unit: String(unit).trim(),
    godown,
    createdBy: req.user.id,
  });
  await item.populate('godown', 'name location');

  return res.status(201).json({ success: true, message: 'Inventory item created.', data: { item } });
});

const listItems = asyncHandler(async (req, res) => {
  const ownerId = await requireOwnerScope(req, res);
  if (!ownerId) return undefined;
  const ids = await ownedGodownIds(ownerId);
  const filter = { godown: { $in: ids } };
  if (req.query.godown) {
    if (badId(res, req.query.godown, 'godown filter id')) return undefined;
    if (!(await ownedGodownExists(req.query.godown, ownerId))) {
      return res.status(404).json({ success: false, message: 'Godown not found.' });
    }
    filter.godown = req.query.godown;
  }
  const items = await InventoryItem.find(filter)
    .populate('godown', 'name location')
    .populate('createdBy', 'name email')
    .sort({ createdAt: -1 });
  return res.status(200).json({ success: true, data: { items } });
});

const getItem = asyncHandler(async (req, res) => {
  if (badId(res, req.params.id, 'item id')) return undefined;
  const ownerId = await requireOwnerScope(req, res);
  if (!ownerId) return undefined;
  const raw = await InventoryItem.findById(req.params.id);
  if (!raw) return res.status(404).json({ success: false, message: 'Inventory item not found.' });
  if (!(await itemBelongsToOwner(raw, ownerId))) {
    return res.status(404).json({ success: false, message: 'Inventory item not found.' });
  }
  const item = await InventoryItem.findById(req.params.id)
    .populate('godown', 'name location')
    .populate('createdBy', 'name email');
  if (!item) return res.status(404).json({ success: false, message: 'Inventory item not found.' });
  return res.status(200).json({ success: true, data: { item } });
});

const updateItem = asyncHandler(async (req, res) => {
  if (badId(res, req.params.id, 'item id')) return undefined;
  const ownerId = await requireOwnerScope(req, res);
  if (!ownerId) return undefined;
  const existing = await InventoryItem.findById(req.params.id);
  if (!existing) return res.status(404).json({ success: false, message: 'Inventory item not found.' });
  if (!(await itemBelongsToOwner(existing, ownerId))) {
    return res.status(404).json({ success: false, message: 'Inventory item not found.' });
  }
  const { itemName, quantity, unit, godown } = req.body || {};
  const updates = {};

  if (itemName !== undefined) {
    if (!String(itemName).trim()) {
      return res.status(400).json({ success: false, message: 'Item name cannot be empty.' });
    }
    updates.itemName = String(itemName).trim();
  }
  if (quantity !== undefined) {
    if (!validateQuantity(quantity)) {
      return res.status(400).json({ success: false, message: 'Quantity must be a non-negative number.' });
    }
    updates.quantity = quantity;
  }
  if (unit !== undefined) {
    if (!String(unit).trim()) return res.status(400).json({ success: false, message: 'Unit cannot be empty.' });
    updates.unit = String(unit).trim();
  }
  if (godown !== undefined) {
    if (badId(res, godown, 'godown id')) return undefined;
    if (!(await ownedGodownExists(godown, ownerId))) {
      return res.status(404).json({ success: false, message: 'Godown not found.' });
    }
    updates.godown = godown;
  }

  const item = await InventoryItem.findByIdAndUpdate(req.params.id, updates, {
    new: true,
    runValidators: true,
  }).populate('godown', 'name location');
  if (!item) return res.status(404).json({ success: false, message: 'Inventory item not found.' });
  return res.status(200).json({ success: true, message: 'Inventory item updated.', data: { item } });
});

const deleteItem = asyncHandler(async (req, res) => {
  if (badId(res, req.params.id, 'item id')) return undefined;
  const ownerId = await requireOwnerScope(req, res);
  if (!ownerId) return undefined;
  const item = await InventoryItem.findById(req.params.id);
  if (!item) return res.status(404).json({ success: false, message: 'Inventory item not found.' });
  if (!(await itemBelongsToOwner(item, ownerId))) {
    return res.status(404).json({ success: false, message: 'Inventory item not found.' });
  }
  await item.deleteOne();
  return res.status(200).json({ success: true, message: 'Inventory item deleted.' });
});

module.exports = { createItem, listItems, getItem, updateItem, deleteItem };
