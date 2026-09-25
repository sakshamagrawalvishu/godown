/**
 * Godown controllers — multi-owner isolation enforced in the backend.
 *
 * Writes (create/update/delete) are OWNER-only (enforced in routes).
 * Reads are OWNER/STAFF (enforced in routes) but always scoped to the
 * effective owner id: OWNER -> own id, STAFF -> linked owner id.
 * Cross-owner access by ID returns 404 to prevent IDOR/enumeration.
 */

const mongoose = require('mongoose');
const Godown = require('../models/Godown');
const InventoryItem = require('../models/InventoryItem');
const asyncHandler = require('../utils/asyncHandler');
const { requireOwnerScope } = require('../utils/ownership');

function badId(res, id) {
  if (!mongoose.isValidObjectId(id)) {
    res.status(400).json({ success: false, message: 'Invalid godown id.' });
    return true;
  }
  return false;
}

function validateGodownInput({ name, location, capacity }) {
  if (!name || !location || capacity === undefined || capacity === null) {
    return 'Name, location and capacity are required.';
  }
  if (typeof capacity !== 'number' || !Number.isFinite(capacity) || capacity < 0) {
    return 'Capacity must be a non-negative number.';
  }
  return null;
}

const createGodown = asyncHandler(async (req, res) => {
  const { name, location, capacity } = req.body || {};
  const error = validateGodownInput({ name, location, capacity });
  if (error) return res.status(400).json({ success: false, message: error });

  const godown = await Godown.create({
    name: String(name).trim(),
    location: String(location).trim(),
    capacity,
    owner: req.user.id,
  });

  return res.status(201).json({ success: true, message: 'Godown created.', data: { godown } });
});

const listGodowns = asyncHandler(async (req, res) => {
  const ownerId = await requireOwnerScope(req, res);
  if (!ownerId) return undefined;
  const godowns = await Godown.find({ owner: ownerId }).populate('owner', 'name email').sort({ createdAt: -1 });
  return res.status(200).json({ success: true, data: { godowns } });
});

const getGodown = asyncHandler(async (req, res) => {
  if (badId(res, req.params.id)) return undefined;
  const ownerId = await requireOwnerScope(req, res);
  if (!ownerId) return undefined;
  const godown = await Godown.findOne({ _id: req.params.id, owner: ownerId }).populate('owner', 'name email');
  if (!godown) return res.status(404).json({ success: false, message: 'Godown not found.' });
  return res.status(200).json({ success: true, data: { godown } });
});

const updateGodown = asyncHandler(async (req, res) => {
  if (badId(res, req.params.id)) return undefined;
  const ownerId = await requireOwnerScope(req, res);
  if (!ownerId) return undefined;
  const { name, location, capacity } = req.body || {};
  const updates = {};

  if (name !== undefined) {
    if (!String(name).trim()) return res.status(400).json({ success: false, message: 'Name cannot be empty.' });
    updates.name = String(name).trim();
  }
  if (location !== undefined) {
    if (!String(location).trim()) {
      return res.status(400).json({ success: false, message: 'Location cannot be empty.' });
    }
    updates.location = String(location).trim();
  }
  if (capacity !== undefined) {
    if (typeof capacity !== 'number' || !Number.isFinite(capacity) || capacity < 0) {
      return res.status(400).json({ success: false, message: 'Capacity must be a non-negative number.' });
    }
    updates.capacity = capacity;
  }

  const godown = await Godown.findOneAndUpdate({ _id: req.params.id, owner: ownerId }, updates, {
    new: true,
    runValidators: true,
  });
  if (!godown) return res.status(404).json({ success: false, message: 'Godown not found.' });
  return res.status(200).json({ success: true, message: 'Godown updated.', data: { godown } });
});

const deleteGodown = asyncHandler(async (req, res) => {
  if (badId(res, req.params.id)) return undefined;
  const ownerId = await requireOwnerScope(req, res);
  if (!ownerId) return undefined;
  const godown = await Godown.findOne({ _id: req.params.id, owner: ownerId });
  if (!godown) return res.status(404).json({ success: false, message: 'Godown not found.' });

  const itemsExist = await InventoryItem.exists({ godown: godown._id });
  if (itemsExist) {
    return res.status(409).json({
      success: false,
      message: 'Cannot delete godown while inventory items reference it. Move or delete the items first.',
    });
  }

  await godown.deleteOne();
  return res.status(200).json({ success: true, message: 'Godown deleted.' });
});

module.exports = { createGodown, listGodowns, getGodown, updateGodown, deleteGodown };
