"""RealWorld Conduit — Jac test suite.

Tests exercise all endpoint functions directly (no HTTP layer).
The jac server wraps responses in {"result": ..., "reports": []};
these tests call the functions directly and check the raw return values.
"""

import from main {
    health,
    user_register, user_login, user_current, user_update,
    profile_get, profile_follow, profile_unfollow,
    article_list, article_feed, article_get,
    article_create, article_update, article_delete,
    article_favorite, article_unfavorite,
    comment_list, comment_create, comment_delete,
    tag_list
}


# ============================================================================
# Helpers
# ============================================================================

def _register(username: str = "testuser", email: str = "test@example.com", password: str = "password123") -> dict {
    return user_register(username=username, email=email, password=password);
}

def _login(email: str = "test@example.com", password: str = "password123") -> dict {
    return user_login(email=email, password=password);
}

def _token(reg_result: dict) -> str {
    return reg_result["user"]["token"];
}


# ============================================================================
# Health
# ============================================================================

test "health returns ok" {
    result = health();
    assert result["ok"] == True;
    assert result["service"] == "jac-realworld-api";
}


# ============================================================================
# Auth / Users
# ============================================================================

test "user registration succeeds" {
    result = _register("alice", "alice@example.com", "pass123");
    assert "user" in result;
    assert result["user"]["username"] == "alice";
    assert result["user"]["email"] == "alice@example.com";
    assert len(result["user"]["token"]) > 0;
}

test "user registration rejects duplicate username" {
    _register("bob", "bob@example.com", "pass");
    result = _register("bob", "bob2@example.com", "pass");
    assert "errors" in result;
    assert "username" in result["errors"];
}

test "user registration rejects duplicate email" {
    _register("carol", "carol@example.com", "pass");
    result = _register("carol2", "carol@example.com", "pass");
    assert "errors" in result;
    assert "email" in result["errors"];
}

test "user registration rejects empty fields" {
    result = user_register(username="", email="e@e.com", password="p");
    assert "errors" in result;

    result = user_register(username="x", email="", password="p");
    assert "errors" in result;

    result = user_register(username="x", email="e@e.com", password="");
    assert "errors" in result;
}

test "user login succeeds" {
    _register("dave", "dave@example.com", "secret");
    result = _login("dave@example.com", "secret");
    assert "user" in result;
    assert result["user"]["username"] == "dave";
    assert len(result["user"]["token"]) > 0;
}

test "user login rejects wrong password" {
    _register("eve", "eve@example.com", "right");
    result = _login("eve@example.com", "wrong");
    assert "errors" in result;
}

test "user login rejects unknown email" {
    result = _login("nonexistent@example.com", "pass");
    assert "errors" in result;
}

test "get current user" {
    reg = _register("frank", "frank@example.com", "pass");
    tok = _token(reg);
    result = user_current(token=tok);
    assert "user" in result;
    assert result["user"]["username"] == "frank";
}

test "get current user rejects bad token" {
    result = user_current(token="invalid-token");
    assert "errors" in result;
}

test "update user" {
    reg = _register("grace", "grace@example.com", "pass");
    tok = _token(reg);
    result = user_update(token=tok, bio="Hello world", image="https://img.png");
    assert result["user"]["bio"] == "Hello world";
    assert result["user"]["image"] == "https://img.png";
}

test "update user password and re-login" {
    reg = _register("heidi", "heidi@example.com", "oldpass");
    tok = _token(reg);
    user_update(token=tok, password="newpass");
    login = _login("heidi@example.com", "newpass");
    assert "user" in login;
}


# ============================================================================
# Profiles
# ============================================================================

test "get profile" {
    _register("ivan", "ivan@example.com", "pass");
    reg2 = _register("judy", "judy@example.com", "pass");
    tok = _token(reg2);
    result = profile_get(token=tok, username="ivan");
    assert "profile" in result;
    assert result["profile"]["username"] == "ivan";
    assert result["profile"]["following"] == False;
}

test "follow and unfollow" {
    reg1 = _register("karl", "karl@example.com", "pass");
    tok = _token(reg1);
    _register("lena", "lena@example.com", "pass");

    # Follow
    result = profile_follow(token=tok, username="lena");
    assert result["profile"]["following"] == True;

    # Unfollow
    result = profile_unfollow(token=tok, username="lena");
    assert result["profile"]["following"] == False;
}

test "follow requires auth" {
    _register("mike", "mike@example.com", "pass");
    result = profile_follow(token="", username="mike");
    assert "errors" in result;
}


# ============================================================================
# Articles
# ============================================================================

test "create article" {
    reg = _register("nancy", "nancy@example.com", "pass");
    tok = _token(reg);
    result = article_create(
        token=tok,
        title="My First Article",
        description="A test article",
        body="This is the body.",
        tag_list=["testing", "jac"]
    );
    assert "article" in result;
    assert result["article"]["title"] == "My First Article";
    assert result["article"]["slug"] == "my-first-article";
    assert len(result["article"]["tagList"]) == 2;
}

test "get article by slug" {
    reg = _register("oscar", "oscar@example.com", "pass");
    tok = _token(reg);
    article_create(token=tok, title="Unique Slug", description="d", body="b");
    result = article_get(token=tok, slug="unique-slug");
    assert "article" in result;
    assert result["article"]["title"] == "Unique Slug";
}

test "update article" {
    reg = _register("pat", "pat@example.com", "pass");
    tok = _token(reg);
    article_create(token=tok, title="Old Title", description="d", body="b");
    result = article_update(token=tok, slug="old-title", title="New Title");
    assert result["article"]["title"] == "New Title";
}

test "delete article" {
    reg = _register("quinn", "quinn@example.com", "pass");
    tok = _token(reg);
    article_create(token=tok, title="To Delete", description="d", body="b");
    result = article_delete(token=tok, slug="to-delete");
    assert result["ok"] == True;

    # Verify it's gone
    gone = article_get(token=tok, slug="to-delete");
    assert "errors" in gone;
}

test "list articles with pagination" {
    reg = _register("rita_p", "rita_p@example.com", "pass");
    tok = _token(reg);
    # Count before
    before = article_list(token=tok);
    count_before = before["articlesCount"];
    for i in range(5) {
        article_create(token=tok, title=f"Rita Article {i}", description="d", body="b");
    }
    result = article_list(token=tok, limit=2, offset=0);
    assert len(result["articles"]) == 2;
    assert result["articlesCount"] == count_before + 5;
}

test "list articles filter by tag" {
    reg = _register("sam", "sam@example.com", "pass");
    tok = _token(reg);
    article_create(token=tok, title="Tagged", description="d", body="b", tag_list=["special"]);
    article_create(token=tok, title="Untagged", description="d", body="b");
    result = article_list(token=tok, tag="special");
    assert result["articlesCount"] == 1;
    assert result["articles"][0]["title"] == "Tagged";
}

test "list articles filter by author" {
    _register("tina", "tina@example.com", "pass");
    reg2 = _register("uma", "uma@example.com", "pass");
    tok2 = _token(reg2);
    article_create(token=tok2, title="Uma Article", description="d", body="b");
    result = article_list(token="", author="uma");
    assert result["articlesCount"] == 1;
}


# ============================================================================
# Favorites
# ============================================================================

test "favorite and unfavorite article" {
    _register("vera", "vera@example.com", "pass");
    reg2 = _register("will", "will@example.com", "pass");
    tok1 = _token(_register("vera2", "vera2@example.com", "pass"));

    # Will creates article
    tok_will = _token(reg2);
    article_create(token=tok_will, title="Fav Me", description="d", body="b");

    # Vera favorites it
    result = article_favorite(token=tok1, slug="fav-me");
    assert result["article"]["favorited"] == True;
    assert result["article"]["favoritesCount"] >= 1;

    # Unfavorite
    result = article_unfavorite(token=tok1, slug="fav-me");
    assert result["article"]["favorited"] == False;
}


# ============================================================================
# Comments
# ============================================================================

test "create and list comments" {
    reg = _register("xena", "xena@example.com", "pass");
    tok = _token(reg);
    article_create(token=tok, title="Commentable", description="d", body="b");

    comment_create(token=tok, slug="commentable", body="Great article!");
    comment_create(token=tok, slug="commentable", body="Thanks!");

    result = comment_list(token=tok, slug="commentable");
    assert len(result["comments"]) == 2;
    assert result["comments"][0]["body"] in ["Great article!", "Thanks!"];
}

test "delete comment" {
    reg = _register("yara", "yara@example.com", "pass");
    tok = _token(reg);
    article_create(token=tok, title="Comment Delete", description="d", body="b");

    c = comment_create(token=tok, slug="comment-delete", body="To delete");
    cid = c["comment"]["id"];

    result = comment_delete(token=tok, slug="comment-delete", comment_id=cid);
    assert result["ok"] == True;

    remaining = comment_list(token=tok, slug="comment-delete");
    assert len(remaining["comments"]) == 0;
}


# ============================================================================
# Tags
# ============================================================================

test "list tags" {
    reg = _register("zara", "zara@example.com", "pass");
    tok = _token(reg);
    article_create(token=tok, title="Tagged Article", description="d", body="b", tag_list=["python", "jac"]);

    result = tag_list();
    assert "tags" in result;
    assert "python" in result["tags"];
    assert "jac" in result["tags"];
}


# ============================================================================
# Feed
# ============================================================================

test "feed shows followed users articles" {
    reg1 = _register("feed1", "feed1@example.com", "pass");
    tok1 = _token(reg1);
    reg2 = _register("feed2", "feed2@example.com", "pass");
    tok2 = _token(reg2);

    # feed2 creates an article
    article_create(token=tok2, title="Feed Article", description="d", body="b");

    # feed1 follows feed2
    profile_follow(token=tok1, username="feed2");

    # Check feed
    result = article_feed(token=tok1);
    assert result["articlesCount"] >= 1;
    titles = [a["title"] for a in result["articles"]];
    assert "Feed Article" in titles;
}

test "feed requires auth" {
    result = article_feed(token="invalid");
    assert "errors" in result;
}
