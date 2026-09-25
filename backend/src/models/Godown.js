/**
 * Godown (warehouse) model.
 *
 * - owner tracks which user created/owns the godown (set from req.user.id).
 * - capacity must be a non-negative number.
 */

const mongoose = require('mongoose');

const godownSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, 'Godown name is required'],
      trim: true,
      maxlength: [120, 'Godown name must be at most 120 characters'],
    },
    location: {
      type: String,
      required: [true, 'Location is required'],
      trim: true,
      maxlength: [200, 'Location must be at most 200 characters'],
    },
    capacity: {
      type: Number,
      required: [true, 'Capacity is required'],
      min: [0, 'Capacity cannot be negative'],
    },
    owner: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Owner is required'],
    },
  },
  { timestamps: true }
);

godownSchema.index({ owner: 1 });

module.exports = mongoose.model('Godown', godownSchema);
