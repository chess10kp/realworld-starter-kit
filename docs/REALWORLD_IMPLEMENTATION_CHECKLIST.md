# RealWorld Jac Implementation Checklist

## 1) Foundation
- [x] Jac project scaffold created
- [x] Conduit domain model skeleton added
- [x] Endpoint stub surface defined
- [x] All endpoint logic implemented (def:pub functions)
- [x] Graph-based data model with proper node/edge types

## 2) Auth + users
- [x] Register (`POST /api/users`) → `user_register`
- [x] Login (`POST /api/users/login`) → `user_login`
- [x] Get current user (`GET /api/user`) → `user_current`
- [x] Update user (`PUT /api/user`) → `user_update`
- [x] Application-level token auth (sha256 password hashing, uuid tokens)

## 3) Profiles
- [x] Get profile (`GET /api/profiles/:username`) → `profile_get`
- [x] Follow user (`POST /api/profiles/:username/follow`) → `profile_follow`
- [x] Unfollow user (`DELETE /api/profiles/:username/follow`) → `profile_unfollow`

## 4) Articles
- [x] List articles with query filters/pagination → `article_list`
- [x] Feed endpoint for authenticated user → `article_feed`
- [x] Get article by slug → `article_get`
- [x] Create article → `article_create`
- [x] Update article → `article_update`
- [x] Delete article → `article_delete`
- [x] Favorite/unfavorite article → `article_favorite`, `article_unfavorite`

## 5) Comments + tags
- [x] List article comments → `comment_list`
- [x] Add comment → `comment_create`
- [x] Delete comment → `comment_delete`
- [x] List tags → `tag_list`

## 6) Response contract compliance
- [x] RealWorld JSON envelope/field names match exactly
- [x] Error payload formats match spec (`{"errors": {"field": ["message"]}}`)
- [x] Slug behavior matches spec
- [ ] HTTP status codes match spec (requires route adapter)
- [ ] Route adapter for `/api/*` → `/function/*` mapping

## 7) Quality
- [x] Jac tests for service logic (28 tests, all passing)
- [x] `jac check main.jac` passes (warnings only)
- [x] `jac test -d tests` passes
- [ ] API contract/integration tests against HTTP server
- [ ] CI checks (check + tests)

## 8) Submission readiness
- [ ] Route adapter for RealWorld URL/path compatibility
- [ ] README final (commands, env, architecture)
- [ ] Public repo clean and runnable
- [ ] Live demo API URL
- [ ] Submit implementation to RealWorld
