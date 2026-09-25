/**
 * Staff management controllers — OWNER only (enforced in routes).
 *
 * - createStaff: owner creates STAFF accounts scoped via owner=req.user.id.
 *   Creating OWNER accounts through this endpoint is rejected.
 * - listStaff: owner views only their own staff (plus self on OWNER filter).
 *   Never returns another owner's users.
 * - Password hashes never leave the server (toSafeJSON).
 */

const User = require('../models/User');
const asyncHandler = require('../utils/asyncHandler');

const EMAIL_RE = /^\S+@\S+\.\S+$/;

const createStaff = asyncHandler(async (req, res) => {
  const { name, email, password, role } = req.body || {};

  if (!name || !email || !password) {
    return res.status(400).json({ success: false, message: 'Name, email and password are required.' });
  }
  if (!EMAIL_RE.test(String(email))) {
    return res.status(400).json({ success: false, message: 'Please provide a valid email address.' });
  }
  if (String(password).length < 6) {
    return res.status(400).json({ success: false, message: 'Password must be at least 6 characters.' });
  }
  if (role && String(role).toUpperCase() !== 'STAFF') {
    return res.status(400).json({ success: false, message: 'Only STAFF accounts can be created here.' });
  }

  const normalizedEmail = String(email).toLowerCase().trim();
  const existing = await User.findOne({ email: normalizedEmail });
  if (existing) {
    return res.status(409).json({ success: false, message: 'Email is already registered.' });
  }

  const staff = await User.create({
    name: String(name).trim(),
    email: normalizedEmail,
    password,
    role: 'STAFF',
    owner: req.user.id,
  });

  return res.status(201).json({
    success: true,
    message: 'Staff account created.',
    data: { user: staff.toSafeJSON() },
  });
});

const listStaff = asyncHandler(async (req, res) => {
  if (req.query.role) {
    const role = String(req.query.role).toUpperCase();
    if (!['OWNER', 'STAFF'].includes(role)) {
      return res.status(400).json({ success: false, message: 'Role filter must be OWNER or STAFF.' });
    }
    if (role === 'OWNER') {
      // An owner must never enumerate other owners: return self only.
      const self = await User.findById(req.user.id);
      const users = self ? [self.toSafeJSON()] : [];
      return res.status(200).json({ success: true, data: { users } });
    }
    const users = await User.find({ owner: req.user.id, role: 'STAFF' }).sort({ createdAt: -1 });
    return res.status(200).json({ success: true, data: { users: users.map((u) => u.toSafeJSON()) } });
  }
  // Default: only staff scoped to this owner (legacy unscoped staff excluded).
  const users = await User.find({ owner: req.user.id, role: 'STAFF' }).sort({ createdAt: -1 });
  return res.status(200).json({ success: true, data: { users: users.map((u) => u.toSafeJSON()) } });
});

module.exports = { createStaff, listStaff };
