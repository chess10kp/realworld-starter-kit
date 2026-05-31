# ![RealWorld Example App](logo.png)

# RealWorld (Conduit) - Jac/Jaseci Backend (WIP)

This repository is a **Jac/Jaseci implementation scaffold** for the [RealWorld](https://github.com/gothinkster/realworld) Conduit spec.

Current status: **project skeleton + endpoint stubs** (not feature-complete yet).

## Stack

- [Jac / Jaseci](https://jaseci.org)
- `jac start` local API server
- Graph persistence (default SQLite via Jac runtime)

## Quick start

```bash
# 1) Install Jac (if needed)
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash

# 2) Install project deps
jac install

# 3) Type check scaffold
jac check main.jac

# 4) Start local API server
jac start main.jac --dev --no_client
```

Server defaults to `http://localhost:8000`.

## Project structure

- `main.jac` - RealWorld domain model + endpoint stubs
- `docs/REALWORLD_IMPLEMENTATION_CHECKLIST.md` - build checklist
- `docs/REALWORLD_ENDPOINT_MAPPING.md` - Conduit API mapping plan
- `tests/` - test suite (to be implemented)

## What's implemented now

- ✅ Full Jac project setup (`jac.toml`, `main.jac`)
- ✅ Data model: `User`, `Article`, `Comment`, `Tag` nodes with `Authored`, `HasComment`, `HasTag`, `Favorited`, `Follows` edges
- ✅ Auth: register, login, get/update current user (application-level tokens)
- ✅ Profiles: get profile, follow, unfollow
- ✅ Articles: create, get, update, delete, list (with tag/author/favorited filters + pagination), feed
- ✅ Favorites: favorite/unfavorite articles
- ✅ Comments: list, create, delete
- ✅ Tags: list
- ✅ Health endpoint
- ✅ 28 passing Jac unit tests covering all feature areas

## Route adapter needed

Jac serves endpoints at `/function/<name>` (POST, JSON body). RealWorld expects `/api/*` routes.
A thin adapter is needed for full RealWorld compliance:
- Map routes: `/api/users` → `/function/user_register`
- Unwrap bodies: `{"user":{...}}` → `{...}`
- Extract from envelope: `{"result":{...}}` → `{...}`
