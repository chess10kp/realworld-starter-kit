"""RealWorld Conduit API — integration tests.

These tests run against the full HTTP stack (adapter + Jac backend).
Start the servers first:
    bash run.sh

Or manually:
    jac start main.jac --dev --no_client --port 8000
    python3 adapter.py 3000

Then run:
    python3 -m pytest tests/test_integration.py -v
    # or
    python3 tests/test_integration.py
"""

import json
import os
import sys
import time
import urllib.request
import urllib.error

BASE_URL = "http://localhost:3000/api"
ALL_PASSED = True
TEST_COUNT = 0
RUN_ID = str(int(time.time() * 1000))[-8:]


def api_call(method: str, path: str, body: dict | None = None, token: str = "") -> tuple[dict, int]:
    """Make a request to the RealWorld API."""
    url = f"{BASE_URL}{path}"
    data = json.dumps(body).encode("utf-8") if body else b""
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Token {token}"

    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read().decode("utf-8")
            return json.loads(raw) if raw else {}, resp.status
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8")
        try:
            return json.loads(raw), e.code
        except Exception:
            return {"raw": raw}, e.code
    except Exception as e:
        return {"error": str(e)}, 0


def test(name: str):
    """Decorator for integration tests."""
    def decorator(func):
        def wrapper():
            global ALL_PASSED, TEST_COUNT
            TEST_COUNT += 1
            try:
                func()
                print(f"  ✅ {name}")
            except AssertionError as e:
                print(f"  ❌ {name}: {e}")
                ALL_PASSED = False
            except Exception as e:
                print(f"  💥 {name}: {type(e).__name__}: {e}")
                ALL_PASSED = False
        return wrapper
    return decorator


# ============================================================================
# Helpers
# ============================================================================
def unique(suffix: str) -> str:
    return f"{RUN_ID}_{suffix}"


def register_user(suffix: str = "user") -> tuple[str, str]:
    """Register a user and return (token, username)."""
    username = unique(suffix)
    email = f"{username}@test.com"
    data, status = api_call("POST", "/users", {
        "user": {"username": username, "email": email, "password": "password123"}
    })
    assert status == 201, f"Register failed: {status} {data}"
    return data["user"]["token"], data["user"]["username"]


# ============================================================================
# Tests
# ============================================================================

@test("Health check - tags endpoint works")
def t_health():
    data, status = api_call("GET", "/tags")
    assert status == 200, f"Expected 200, got {status}"
    assert "tags" in data, f"Missing 'tags' key: {data}"


@test("Register user")
def t_register():
    username = unique("reg")
    data, status = api_call("POST", "/users", {
        "user": {"username": username, "email": f"{username}@test.com", "password": "pass123"}
    })
    assert status == 201, f"Expected 201, got {status}: {data}"
    assert "user" in data
    assert data["user"]["username"] == username
    assert len(data["user"]["token"]) > 0


@test("Register duplicate username fails")
def t_register_dup():
    username = unique("dup")
    api_call("POST", "/users", {
        "user": {"username": username, "email": f"{username}@test.com", "password": "pass"}
    })
    data, status = api_call("POST", "/users", {
        "user": {"username": username, "email": f"other@test.com", "password": "pass"}
    })
    assert status == 422, f"Expected 422, got {status}: {data}"
    assert "errors" in data


@test("Register with empty fields fails")
def t_register_empty():
    data, status = api_call("POST", "/users", {
        "user": {"username": "", "email": "e@e.com", "password": "p"}
    })
    assert status == 422, f"Expected 422, got {status}"


@test("Login user")
def t_login():
    username = unique("login")
    email = f"{username}@test.com"
    api_call("POST", "/users", {
        "user": {"username": username, "email": email, "password": "mypass"}
    })
    data, status = api_call("POST", "/users/login", {
        "user": {"email": email, "password": "mypass"}
    })
    assert status == 200, f"Expected 200, got {status}: {data}"
    assert "user" in data
    assert data["user"]["username"] == username


@test("Login with wrong password fails")
def t_login_wrong():
    username = unique("loginw")
    email = f"{username}@test.com"
    api_call("POST", "/users", {
        "user": {"username": username, "email": email, "password": "right"}
    })
    data, status = api_call("POST", "/users/login", {
        "user": {"email": email, "password": "wrong"}
    })
    assert status == 422, f"Expected 422, got {status}: {data}"


@test("Get current user")
def t_current_user():
    token, username = register_user("cur")
    data, status = api_call("GET", "/user", token=token)
    assert status == 200, f"Expected 200, got {status}: {data}"
    assert data["user"]["username"] == username


@test("Get current user without token fails")
def t_current_no_token():
    data, status = api_call("GET", "/user")
    assert status == 401, f"Expected 401, got {status}: {data}"


@test("Update user")
def t_update_user():
    token, _ = register_user("upd")
    data, status = api_call("PUT", "/user", {
        "user": {"bio": "Updated bio", "image": "https://pic.png"}
    }, token=token)
    assert status == 200, f"Expected 200, got {status}: {data}"
    assert data["user"]["bio"] == "Updated bio"
    assert data["user"]["image"] == "https://pic.png"


@test("Get profile")
def t_get_profile():
    _, username = register_user("prof_target")
    token2, _ = register_user("prof_viewer")
    data, status = api_call("GET", f"/profiles/{username}", token=token2)
    assert status == 200, f"Expected 200, got {status}: {data}"
    assert data["profile"]["username"] == username
    assert data["profile"]["following"] is False


@test("Follow and unfollow profile")
def t_follow():
    _, target = register_user("ftarget")
    token, _ = register_user("ffollower")

    # Follow
    data, status = api_call("POST", f"/profiles/{target}/follow", token=token)
    assert status == 200, f"Expected 200, got {status}: {data}"
    assert data["profile"]["following"] is True

    # Unfollow
    data, status = api_call("DELETE", f"/profiles/{target}/follow", token=token)
    assert status == 200, f"Expected 200, got {status}: {data}"
    assert data["profile"]["following"] is False


@test("Create article")
def t_create_article():
    token, _ = register_user("art")
    data, status = api_call("POST", "/articles", {
        "article": {
            "title": "Integration Test Article",
            "description": "Testing",
            "body": "Content here",
            "tagList": ["testing", "integration"]
        }
    }, token=token)
    assert status == 201, f"Expected 201, got {status}: {data}"
    assert data["article"]["title"] == "Integration Test Article"
    assert data["article"]["slug"] == "integration-test-article"
    assert "testing" in data["article"]["tagList"]
    assert "integration" in data["article"]["tagList"]


@test("Get article by slug")
def t_get_article():
    token, _ = register_user("getart")
    api_call("POST", "/articles", {
        "article": {"title": "Slug Test Article", "description": "d", "body": "b"}
    }, token=token)
    data, status = api_call("GET", "/articles/slug-test-article", token=token)
    assert status == 200, f"Expected 200, got {status}: {data}"
    assert data["article"]["title"] == "Slug Test Article"


@test("Update article")
def t_update_article():
    token, _ = register_user("updart")
    api_call("POST", "/articles", {
        "article": {"title": "Before Update", "description": "d", "body": "b"}
    }, token=token)
    data, status = api_call("PUT", "/articles/before-update", {
        "article": {"title": "After Update"}
    }, token=token)
    assert status == 200, f"Expected 200, got {status}: {data}"
    assert data["article"]["title"] == "After Update"


@test("Delete article")
def t_delete_article():
    token, _ = register_user("delart")
    api_call("POST", "/articles", {
        "article": {"title": "Delete Me Article", "description": "d", "body": "b"}
    }, token=token)
    data, status = api_call("DELETE", "/articles/delete-me-article", token=token)
    assert status == 200, f"Expected 200, got {status}: {data}"


@test("List articles")
def t_list_articles():
    token, _ = register_user("listart")
    for i in range(3):
        api_call("POST", "/articles", {
            "article": {"title": f"List Article {unique('la')}", "description": "d", "body": "b"}
        }, token=token)
    data, status = api_call("GET", "/articles?limit=2")
    assert status == 200, f"Expected 200, got {status}: {data}"
    assert len(data["articles"]) <= 2
    assert data["articlesCount"] >= 3


@test("List articles filtered by tag")
def t_list_by_tag():
    token, _ = register_user("tagart")
    api_call("POST", "/articles", {
        "article": {"title": f"Tagged {unique('ta')}", "description": "d", "body": "b", "tagList": ["uniquetag123"]}
    }, token=token)
    data, status = api_call("GET", "/articles?tag=uniquetag123")
    assert status == 200, f"Expected 200, got {status}: {data}"
    assert data["articlesCount"] >= 1


@test("Favorite and unfavorite article")
def t_favorite():
    token1, _ = register_user("favcreate")
    api_call("POST", "/articles", {
        "article": {"title": "Favorite This", "description": "d", "body": "b"}
    }, token=token1)

    token2, _ = register_user("faver")
    data, status = api_call("POST", "/articles/favorite-this/favorite", token=token2)
    assert status == 200, f"Expected 200, got {status}: {data}"
    assert data["article"]["favorited"] is True
    assert data["article"]["favoritesCount"] >= 1

    data, status = api_call("DELETE", "/articles/favorite-this/favorite", token=token2)
    assert status == 200, f"Expected 200, got {status}: {data}"
    assert data["article"]["favorited"] is False


@test("Create and list comments")
def t_comments():
    token, _ = register_user("comart")
    data, status = api_call("POST", "/articles", {
        "article": {"title": f"Commentable {unique('ca')}", "description": "d", "body": "b"}
    }, token=token)
    assert status == 201, f"Create article failed: {status} {data}"
    slug = data["article"]["slug"]

    # Create comments
    api_call("POST", f"/articles/{slug}/comments", {"comment": {"body": "First comment"}}, token=token)
    api_call("POST", f"/articles/{slug}/comments", {"comment": {"body": "Second comment"}}, token=token)

    data, status = api_call("GET", f"/articles/{slug}/comments", token=token)
    assert status == 200, f"Expected 200, got {status}: {data}"
    assert len(data["comments"]) >= 2


@test("Feed shows followed users articles")
def t_feed():
    token_target, target_name = register_user("feedtgt")
    api_call("POST", "/articles", {
        "article": {"title": f"Feed Article {unique('fa')}", "description": "d", "body": "b"}
    }, token=token_target)

    token_follower, _ = register_user("feedfoll")
    api_call("POST", f"/profiles/{target_name}/follow", token=token_follower)

    data, status = api_call("GET", "/articles/feed", token=token_follower)
    assert status == 200, f"Expected 200, got {status}: {data}"
    assert data["articlesCount"] >= 1


@test("Feed requires auth")
def t_feed_auth():
    data, status = api_call("GET", "/articles/feed")
    assert status == 401, f"Expected 401, got {status}: {data}"


@test("List tags")
def t_tags():
    data, status = api_call("GET", "/tags")
    assert status == 200, f"Expected 200, got {status}: {data}"
    assert "tags" in data
    assert isinstance(data["tags"], list)


# ============================================================================
# Runner
# ============================================================================

def main():
    global ALL_PASSED, TEST_COUNT

    # Check server is up
    try:
        api_call("GET", "/tags")
    except Exception as e:
        print(f"❌ Cannot connect to {BASE_URL}")
        print(f"   Start servers first: bash run.sh")
        print(f"   Error: {e}")
        sys.exit(1)

    print(f"\n🧪 RealWorld Conduit API — Integration Tests")
    print(f"   Target: {BASE_URL}\n")

    tests = [
        t_health, t_register, t_register_dup, t_register_empty,
        t_login, t_login_wrong,
        t_current_user, t_current_no_token, t_update_user,
        t_get_profile, t_follow,
        t_create_article, t_get_article, t_update_article, t_delete_article,
        t_list_articles, t_list_by_tag,
        t_favorite,
        t_comments,
        t_feed, t_feed_auth, t_tags,
    ]

    for t in tests:
        t()

    print(f"\n{'='*50}")
    if ALL_PASSED:
        print(f"✅ All {TEST_COUNT} integration tests passed!")
    else:
        print(f"❌ Some tests failed!")
    print(f"{'='*50}\n")

    sys.exit(0 if ALL_PASSED else 1)


if __name__ == "__main__":
    main()
