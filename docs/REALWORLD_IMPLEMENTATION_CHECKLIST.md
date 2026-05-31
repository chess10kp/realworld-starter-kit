# RealWorld Jac Implementation Checklist

## 1) Foundation
- [x] Jac project scaffold created
- [x] Conduit domain model skeleton added
- [x] Endpoint surface defined
- [x] All endpoint logic implemented (def:pub functions)
- [x] Graph-based data model with proper node/edge types
- [x] RealWorld camelCase response format

## 2) Auth + users
- [x] Register (`POST /api/users`)
- [x] Login (`POST /api/users/login`)
- [x] Get current user (`GET /api/user`)
- [x] Update user (`PUT /api/user`)
- [x] Application-level token auth (sha256 password hashing, uuid tokens)
- [x] Duplicate username/email validation
- [x] Empty field validation

## 3) Profiles
- [x] Get profile (`GET /api/profiles/:username`)
- [x] Follow user (`POST /api/profiles/:username/follow`)
- [x] Unfollow user (`DELETE /api/profiles/:username/follow`)

## 4) Articles
- [x] List articles with query filters/pagination
- [x] Feed endpoint for authenticated user
- [x] Get article by slug
- [x] Create article
- [x] Update article
- [x] Delete article
- [x] Favorite/unfavorite article (with count tracking)

## 5) Comments + tags
- [x] List article comments
- [x] Add comment
- [x] Delete comment
- [x] List tags

## 6) Response contract compliance
- [x] RealWorld JSON envelope/field names match exactly
- [x] camelCase field names (createdAt, updatedAt, favoritesCount, tagList, articlesCount)
- [x] Error payload formats match spec (`{"errors": {"field": ["message"]}}`)
- [x] HTTP status codes match spec (200, 201, 401, 404, 422)
- [x] Slug behavior matches spec
- [x] Pagination with limit/offset
- [x] Filtering by tag, author, favorited
- [x] Route adapter for `/api/*` compatibility

## 7) Quality
- [x] Jac unit tests for service logic (28 tests, all passing)
- [x] HTTP integration tests (22 tests, all passing)
- [x] `jac check main.jac` passes (warnings only)
- [x] CI workflow (GitHub Actions)

## 8) Submission readiness
- [x] README final (commands, architecture, examples)
- [x] Route adapter for RealWorld URL/path compatibility
- [x] Clean project structure
- [ ] Public repo with live demo API URL
- [ ] Submit implementation to RealWorld
