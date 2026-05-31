# ![RealWorld Example App](logo.png)

# RealWorld (Conduit) — Jac/Jaseci Backend

A fully functional [RealWorld](https://github.com/gothinkster/realworld) Conduit backend API implementation built with [Jac / Jaseci](https://jaseci.org).

## Stack

- **Language**: [Jac](https://jaseci.org) — graph-oriented programming language
- **Runtime**: `jac start` local API server with graph persistence
- **Adapter**: Lightweight Python reverse proxy for RealWorld route compatibility
- **Auth**: Application-level tokens (SHA256 + UUID)
- **Data model**: Graph nodes (User, Article, Comment, Tag) connected by typed edges

## Quick start

```bash
# 1) Install Jac
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash

# 2) Install project deps
jac install

# 3) Start the full API
bash run.sh
```

The API will be available at `http://localhost:3000/api`.

## Architecture

```
RealWorld Client
       │
       ▼
  Adapter (port 3000)     ← Python HTTP proxy
   - /api/* route mapping
   - Request envelope unwrapping
   - Authorization header extraction
   - Response format + status codes
       │
       ▼
  Jac Server (port 8000)  ← Graph-based backend
   - /function/* endpoints
   - Node/edge data model
   - Business logic in main.jac
   - Graph persistence (SQLite)
```

### Why two layers?

Jac serves functions at `/function/<name>` with POST JSON bodies. RealWorld expects RESTful routes like `GET /api/articles?tag=foo`. The thin adapter bridges this gap without modifying the Jac runtime.

## Project structure

```
main.jac                          # All endpoint logic + data model
adapter.py                        # RealWorld API route adapter
run.sh                            # Start both servers
jac.toml                          # Jac project config
tests/
  test_realworld.jac              # 28 Jac unit tests (all passing)
  test_integration.py             # 22 HTTP integration tests (all passing)
docs/
  REALWORLD_IMPLEMENTATION_CHECKLIST.md
  REALWORLD_ENDPOINT_MAPPING.md
```

## What's implemented

| Feature | Endpoints |
|---------|-----------|
| **Auth** | Register, Login, Get/Update current user |
| **Profiles** | Get profile, Follow, Unfollow |
| **Articles** | CRUD, List (filters + pagination), Feed |
| **Favorites** | Favorite, Unfavorite |
| **Comments** | List, Create, Delete |
| **Tags** | List all tags |

All endpoints return RealWorld-compatible JSON with correct camelCase field names and error formats.

## Running tests

### Unit tests (Jac)
```bash
jac test -d tests
```

### Integration tests (HTTP)
```bash
# Start servers first
bash run.sh

# Run in another terminal
python3 tests/test_integration.py
```

### Type check
```bash
jac check main.jac
```

## API Examples

```bash
# Register
curl -X POST http://localhost:3000/api/users \
  -H "Content-Type: application/json" \
  -d '{"user":{"username":"alice","email":"alice@example.com","password":"password123"}}'

# Login
curl -X POST http://localhost:3000/api/users/login \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"alice@example.com","password":"password123"}}'

# Create article (with token from login)
curl -X POST http://localhost:3000/api/articles \
  -H "Content-Type: application/json" \
  -H "Authorization: Token YOUR_TOKEN" \
  -d '{"article":{"title":"My Article","description":"Desc","body":"Content","tagList":["tag1"]}}'

# List articles
curl http://localhost:3000/api/articles?limit=10&offset=0

# Get tags
curl http://localhost:3000/api/tags
```

## RealWorld Spec Compliance

- ✅ Correct request/response JSON envelopes
- ✅ camelCase field names (`createdAt`, `favoritesCount`, `tagList`, `articlesCount`)
- ✅ Error format: `{"errors": {"field": ["message"]}}`
- ✅ `Authorization: Token <jwt>` header
- ✅ Correct HTTP status codes (200, 201, 401, 404, 422)
- ✅ Slug-based article URLs
- ✅ Pagination with `limit`/`offset`
- ✅ Filtering by tag, author, favorited
- ✅ Authenticated feed endpoint
