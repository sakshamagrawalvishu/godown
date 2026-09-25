# Godown Backend (Auth + MongoDB foundation)

Isolated Node.js + Express API. The existing `index.html` demo is untouched.

## Setup

```bash
cd backend
cp .env.example .env   # then fill in your own local values (never commit .env)
npm install
npm run dev   # or: npm start
```

Without a real `MONGODB_URI` the server still starts (health check works);
MongoDB connection is skipped until you configure Atlas (see below).

## Health check

```bash
curl http://localhost:5000/health
curl http://localhost:5000/api/v1/health
```

Expected: `200 { "success": true, "message": "Godown backend is running", ... }`

Unknown routes return `404 { "success": false, "message": "Route not found: ..." }`.

## Auth APIs

Public registration NEVER creates OWNER accounts. It creates STAFF accounts
only; an explicit `"role":"OWNER"` is rejected with `403`.

```bash
# Register (creates STAFF; role may be omitted or "STAFF")
curl -X POST http://localhost:5000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Staff One","email":"staff@example.com","password":"password123"}'

# Rejected: public callers cannot choose OWNER (403)
curl -X POST http://localhost:5000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Owner One","email":"owner@example.com","password":"password123","role":"OWNER"}'

# Login
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"owner@example.com","password":"password123"}'

# Current user (protected)
curl http://localhost:5000/api/auth/me \
  -H "Authorization: Bearer <JWT_TOKEN>"
```

## Creating the initial OWNER

OWNER accounts are provisioned out-of-band with the seed script (never via
the public API). Credentials come only from environment variables and are
never printed or committed. Safe to re-run: if the owner already exists,
nothing is created.

```bash
ADMIN_EMAIL=owner@example.com ADMIN_PASSWORD=<secret> npm run seed:owner
```

Day-to-day staff provisioning stays OWNER-only through the authenticated
endpoint (see "Owner creates staff" below) — that flow is unchanged.

## Connecting MongoDB Atlas later

1. Create a free Atlas cluster and database user.
2. Copy your connection string (it looks like
   `mongodb+srv://<user>:<password>@<cluster-host>/<db>?retryWrites=true&w=majority`).
3. Paste it as `MONGODB_URI` in your local `backend/.env` (never commit it).
4. Set a long random `JWT_SECRET` in the same `.env`.
5. Restart the server — you should see `MongoDB connected: ...`.

## Full API route list

Auth:

- `POST /api/auth/register` — public, creates STAFF only (explicit `"role":"OWNER"` is rejected with 403), returns JWT
- `POST /api/auth/login` — public, returns JWT + safe user
- `GET /api/auth/me` — protected, returns own safe profile

Staff management (OWNER only):

- `POST /api/users` — owner creates a STAFF account (OWNER role rejected here)
- `GET /api/users` — owner lists users (`?role=STAFF` or `?role=OWNER` filter)

Godowns (writes OWNER only, reads OWNER + STAFF):

- `POST /api/godowns`
- `GET /api/godowns`
- `GET /api/godowns/:id`
- `PUT /api/godowns/:id`
- `DELETE /api/godowns/:id` — blocked (409) while inventory items reference it

Inventory (writes OWNER only, reads OWNER + STAFF):

- `POST /api/inventory` — body: `itemName, quantity (>= 0), unit, godown (must exist)`
- `GET /api/inventory` — optional `?godown=<id>` filter, populates godown + creator
- `GET /api/inventory/:id`
- `PUT /api/inventory/:id` — partial update, same validations
- `DELETE /api/inventory/:id`

Example (owner token required for writes):

```bash
TOKEN=<JWT_FROM_LOGIN>

# Create godown (OWNER)
curl -X POST http://localhost:5000/api/godowns \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"name":"Godown A","location":"Katghora","capacity":500}'

# List godowns (OWNER or STAFF token)
curl http://localhost:5000/api/godowns \
  -H "Authorization: Bearer $TOKEN"

# Add inventory item (OWNER)
curl -X POST http://localhost:5000/api/inventory \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"itemName":"Cement","quantity":500,"unit":"bags","godown":"<GODOWN_ID>"}'

# Owner creates staff
curl -X POST http://localhost:5000/api/users \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"name":"Staff One","email":"staff@example.com","password":"password123"}'
```

## CORS

- Development: with `CORS_ORIGINS` empty (the default), CORS is open and
  the server logs a warning. This keeps local emulator/device testing easy.
- Production: set `CORS_ORIGINS` to a comma-separated allowlist of your real
  frontend origin(s), e.g. `CORS_ORIGINS=https://app.example.com`.
  Browser clients from other origins are then blocked. Native mobile apps
  and curl are unaffected by CORS either way.
- Never commit real domains or secrets to source control — configure them
  through environment variables on the host.

## Authentication rate limiting

- `POST /api/auth/login` and `POST /api/auth/register` are rate limited
  per IP via `express-rate-limit` (see `src/middleware/rateLimit.js`).
- Configured with `AUTH_RATE_LIMIT_WINDOW_MS` (default 900000 = 15 min)
  and `AUTH_RATE_LIMIT_MAX` (default 100). In production use a lower
  limit such as 10–20 requests per 15 minutes.
- Authenticated routes (`GET /api/auth/me`, users, godowns, inventory)
  and health checks are NOT rate limited.
- Exceeding the limit returns HTTP `429` in the standard envelope:
  `{ "success": false, "message": "Too many authentication attempts. Please try again later." }`
- The app trusts the first hosting proxy (`trust proxy`) so client IPs
  are detected correctly behind Render/Heroku-style proxies.
- The default in-memory store is per-process and suits a single instance.
  When running multiple backend instances, switch to an external store
  (e.g. Redis) so limits are shared.
