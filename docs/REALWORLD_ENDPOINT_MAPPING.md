# RealWorld API → Jac Endpoint Mapping (Plan)

> Jac exposes callable functions; this file maps Conduit REST endpoints to planned Jac server functions in `main.jac`.

## Users
- `POST /api/users` → `user_register(username, email, password)`
- `POST /api/users/login` → `user_login(email, password)`
- `GET /api/user` → `user_current()`
- `PUT /api/user` → `user_update(...)`

## Profiles
- `GET /api/profiles/:username` → `profile_get(username)`
- `POST /api/profiles/:username/follow` → `profile_follow(username)`
- `DELETE /api/profiles/:username/follow` → `profile_unfollow(username)`

## Articles
- `GET /api/articles` → `article_list(tag, author, favorited, limit, offset)`
- `GET /api/articles/feed` → `article_feed(limit, offset)`
- `GET /api/articles/:slug` → `article_get(slug)`
- `POST /api/articles` → `article_create(title, description, body, tag_list)`
- `PUT /api/articles/:slug` → `article_update(slug, ...)`
- `DELETE /api/articles/:slug` → `article_delete(slug)`

## Favorites
- `POST /api/articles/:slug/favorite` → `article_favorite(slug)`
- `DELETE /api/articles/:slug/favorite` → `article_unfavorite(slug)`

## Comments
- `GET /api/articles/:slug/comments` → `comment_list(slug)`
- `POST /api/articles/:slug/comments` → `comment_create(slug, body)`
- `DELETE /api/articles/:slug/comments/:id` → `comment_delete(slug, comment_id)`

## Tags
- `GET /api/tags` → `tag_list()`

---

## Important implementation note
RealWorld requires exact REST routes and payloads. If Jac's default generated function endpoints do not match spec routes directly, add a route adapter layer to preserve Conduit compatibility.
