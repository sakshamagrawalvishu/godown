/**
 * Ownership helpers — multi-owner data isolation.
 *
 * - OWNER: effective owner id is req.user.id.
 * - STAFF: effective owner id is the linked User.owner.
 *   Legacy STAFF records with owner=null are denied (403) — deny-by-default.
 *
 * Controllers must scope every query through the effective owner id and
 * return 404 (not 403) for cross-owner object access to avoid enumeration.
 */

const User = require('../models/User');

async function resolveOwnerId(req) {
  if (!req.user) return null;
  const role = String(req.user.role || '').toUpperCase();
  if (role === 'OWNER') return String(req.user.id);
  if (role === 'STAFF') {
    const staff = await User.findById(req.user.id).select('owner isActive');
    if (!staff || !staff.isActive) return null;
    return staff.owner ? String(staff.owner) : null;
  }
  return null;
}

/**
 * Sends 403 when the caller has no effective owner (e.g. legacy STAFF
 * with owner=null). Returns the ownerId string otherwise, or null when
 * a response was already sent.
 */
async function requireOwnerScope(req, res) {
  const ownerId = await resolveOwnerId(req);
  if (!ownerId) {
    res.status(403).json({
      success: false,
      message: 'Forbidden. Staff account is not assigned to an owner.',
    });
    return null;
  }
  return ownerId;
}

module.exports = { resolveOwnerId, requireOwnerScope };
