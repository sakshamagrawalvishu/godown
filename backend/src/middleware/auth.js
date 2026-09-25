/**
 * Authentication + role-based authorization middleware.
 *
 * Usage:
 *   const { authenticate, authorize } = require('./auth');
 *   router.get('/me', authenticate, handler);
 *   router.get('/owner-only', authenticate, authorize('OWNER'), handler);
 *   router.get('/shared', authenticate, authorize('OWNER', 'STAFF'), handler);
 */

const { verifyToken } = require('../utils/jwt');

function authenticate(req, res, next) {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');

  if (scheme !== 'Bearer' || !token) {
    return res.status(401).json({
      success: false,
      message: 'Authentication required. Provide a Bearer token.',
    });
  }

  try {
    const decoded = verifyToken(token);
    req.user = { id: decoded.id, role: decoded.role };
    return next();
  } catch (err) {
    if (err && err.name === 'TokenExpiredError') {
      return res.status(401).json({ success: false, message: 'Token expired. Please log in again.' });
    }
    return res.status(401).json({ success: false, message: 'Invalid token.' });
  }
}

function authorize(...allowedRoles) {
  const allowed = allowedRoles.map((r) => String(r).toUpperCase());
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Authentication required.' });
    }
    if (!allowed.includes(String(req.user.role).toUpperCase())) {
      return res.status(403).json({ success: false, message: 'Forbidden. Insufficient permissions.' });
    }
    return next();
  };
}

module.exports = { authenticate, authorize };
