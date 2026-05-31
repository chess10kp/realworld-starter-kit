# Tests

28 Jac unit tests covering all RealWorld feature areas.

```bash
jac test -d tests
```

## Test coverage

| Area | Tests |
|------|-------|
| Health | health returns ok |
| Auth | registration succeeds, duplicate username/email rejected, empty fields rejected, login succeeds, wrong password rejected, unknown email rejected |
| Users | get current user, bad token rejected, update user, update password + re-login |
| Profiles | get profile, follow + unfollow, follow requires auth |
| Articles | create article, get by slug, update article, delete article, list with pagination, filter by tag, filter by author |
| Favorites | favorite + unfavorite article |
| Comments | create + list comments, delete comment |
| Tags | list tags |
| Feed | feed shows followed users' articles, feed requires auth |
