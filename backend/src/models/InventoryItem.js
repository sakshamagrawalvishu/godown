/**
 * Inventory item model.
 *
 * - godown must reference an existing Godown (checked in the controller).
 * - quantity must be a non-negative number (validated here and in the controller).
 * - createdBy tracks which user added the item (set from req.user.id).
 */

const mongoose = require('mongoose');

const inventoryItemSchema = new mongoose.Schema(
  {
    itemName: {
      type: String,
      required: [true, 'Item name is required'],
      trim: true,
      maxlength: [120, 'Item name must be at most 120 characters'],
    },
    quantity: {
      type: Number,
      required: [true, 'Quantity is required'],
      min: [0, 'Quantity cannot be negative'],
    },
    unit: {
      type: String,
      required: [true, 'Unit is required (e.g. bags, tons, pieces, kg)'],
      trim: true,
      maxlength: [30, 'Unit must be at most 30 characters'],
    },
    godown: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Godown',
      required: [true, 'Godown reference is required'],
    },
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'CreatedBy user reference is required'],
    },
  },
  { timestamps: true }
);

inventoryItemSchema.index({ godown: 1, itemName: 1 });

module.exports = mongoose.model('InventoryItem', inventoryItemSchema);
