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

```bash
# Register (role: OWNER or STAFF, defaults to STAFF)
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

## Connecting MongoDB Atlas later

1. Create a free Atlas cluster and database user.
2. Copy your connection string (it looks like
   `mongodb+srv://<user>:<password>@<cluster-host>/<db>?retryWrites=true&w=majority`).
3. Paste it as `MONGODB_URI` in your local `backend/.env` (never commit it).
4. Set a long random `JWT_SECRET` in the same `.env`.
5. Restart the server — you should see `MongoDB connected: ...`.

## Full API route list

Auth:

- `POST /api/auth/register` — public, creates OWNER or STAFF, returns JWT
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
