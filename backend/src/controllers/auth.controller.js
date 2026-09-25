/**
 * Authentication controllers: register, login, me.
 *
 * - Passwords are hashed by the User model pre-save hook.
 * - Password hashes never leave the server (select: false + toSafeJSON).
 * - Login uses a generic error so callers can't probe which emails exist.
 */

const User = require('../models/User');
const asyncHandler = require('../utils/asyncHandler');
const { signToken } = require('../utils/jwt');

const VALID_ROLES = ['OWNER', 'STAFF'];
const EMAIL_RE = /^\S+@\S+\.\S+$/;

const register = asyncHandler(async (req, res) => {
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

  const normalizedRole = role ? String(role).toUpperCase() : 'STAFF';
  if (!VALID_ROLES.includes(normalizedRole)) {
    return res.status(400).json({ success: false, message: 'Role must be OWNER or STAFF.' });
  }

  const normalizedEmail = String(email).toLowerCase().trim();
  const existing = await User.findOne({ email: normalizedEmail });
  if (existing) {
    return res.status(409).json({ success: false, message: 'Email is already registered.' });
  }

  const user = await User.create({
    name: String(name).trim(),
    email: normalizedEmail,
    password,
    role: normalizedRole,
  });

  const token = signToken(user);

  return res.status(201).json({
    success: true,
    message: 'User registered successfully.',
    data: { token, user: user.toSafeJSON() },
  });
});

const login = asyncHandler(async (req, res) => {
  const { email, password } = req.body || {};

  if (!email || !password) {
    return res.status(400).json({ success: false, message: 'Email and password are required.' });
  }

  // Generic error on purpose — do not reveal whether the email exists.
  const invalidCredentials = () =>
    res.status(401).json({ success: false, message: 'Invalid email or password.' });

  const user = await User.findOne({ email: String(email).toLowerCase().trim() }).select('+password');
  if (!user) return invalidCredentials();

  const matches = await user.comparePassword(password);
  if (!matches) return invalidCredentials();

  if (!user.isActive) {
    return res.status(403).json({ success: false, message: 'Account is deactivated. Contact the owner.' });
  }

  const token = signToken(user);

  return res.status(200).json({
    success: true,
    message: 'Login successful.',
    data: { token, user: user.toSafeJSON() },
  });
});

const me = asyncHandler(async (req, res) => {
  const user = await User.findById(req.user.id);
  if (!user || !user.isActive) {
    return res.status(401).json({ success: false, message: 'User not found or deactivated.' });
  }
  return res.status(200).json({ success: true, data: { user: user.toSafeJSON() } });
});

module.exports = { register, login, me };
