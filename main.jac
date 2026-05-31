"""RealWorld Conduit backend — full implementation in Jac.

All endpoints are def:pub and run in a shared graph (GUEST root).
Authentication uses application-level tokens stored on User nodes.
Token is passed as a function parameter (the route adapter extracts
it from the Authorization header for RealWorld compliance).

RealWorld route adapter:
  /api/*  →  /function/*   (body unwrapped, response extracted from envelope)
"""

import hashlib;
import datetime;
import re;


# ============================================================================
# Data Model
# ============================================================================

node User {
    has username: str = "";
    has email: str = "";
    has bio: str = "";
    has image: str = "";
    has password_hash: str = "";
    has token: str = "";
}

node Article {
    has slug: str = "";
    has title: str = "";
    has description: str = "";
    has body: str = "";
    has created_at: str = "";
    has updated_at: str = "";
}

node Comment {
    has body: str = "";
    has created_at: str = "";
    has updated_at: str = "";
}

node Tag {
    has name: str = "";
}

edge Authored {}
edge HasComment {}
edge HasTag {}
edge Favorited {}
edge Follows {}


# ============================================================================
# Internal Helpers
# ============================================================================

def _hash_password(password: str) -> str {
    return hashlib.sha256(("rw__" + password).encode()).hexdigest();
}

def _check_password(password: str, password_hash: str) -> bool {
    return _hash_password(password) == password_hash;
}

def _generate_token() -> str {
    import uuid;
    return uuid.uuid4().hex + uuid.uuid4().hex;
}

def _slugify(title: str) -> str {
    slug = re.sub(r'[^a-zA-Z0-9]+', '-', title.lower().strip());
    return slug.strip('-');
}

def _now_iso() -> str {
    return datetime.datetime.now(datetime.timezone.utc).isoformat();
}

def _find_user_by_username(username: str) -> (User | None) {
    for u in [root-->][?:User] {
        if u.username == username {
            return u;
        }
    }
    return None;
}

def _find_user_by_email(email: str) -> (User | None) {
    for u in [root-->][?:User] {
        if u.email == email {
            return u;
        }
    }
    return None;
}

def _find_user_by_token(token: str) -> (User | None) {
    if not token {
        return None;
    }
    for u in [root-->][?:User] {
        if u.token == token {
            return u;
        }
    }
    return None;
}

def _find_article_by_slug(slug: str) -> (Article | None) {
    for u in [root-->][?:User] {
        for a in [u-->][?:Article] {
            if a.slug == slug {
                return a;
            }
        }
    }
    return None;
}

def _article_author(article: Article) -> (User | None) {
    authors = [article<--[?:User]];
    if authors {
        return authors[0];
    }
    return None;
}

def _is_following(current_user: User, target_user: User) -> bool {
    edges = [edge current_user->:Follows:->target_user];
    return len(edges) > 0;
}

def _is_favorited(user: User, article: Article) -> bool {
    edges = [edge user->:Favorited:->article];
    return len(edges) > 0;
}

def _favorites_count(article: Article) -> int {
    count = 0;
    for u in [root-->][?:User] {
        if _is_favorited(u, article) {
            count += 1;
        }
    }
    return count;
}

def _sort_articles_desc(articles: list[Article]) -> list[Article] {
    n = len(articles);
    result: list[Article] = list(articles);
    for i in range(n) {
        for j in range(0, n - i - 1) {
            if result[j].created_at < result[j + 1].created_at {
                tmp = result[j];
                result[j] = result[j + 1];
                result[j + 1] = tmp;
            }
        }
    }
    return result;
}

def _sort_comments_asc(comments: list[dict]) -> list[dict] {
    n = len(comments);
    result: list[dict] = list(comments);
    for i in range(n) {
        for j in range(0, n - i - 1) {
            if result[j]["created_at"] > result[j + 1]["created_at"] {
                tmp = result[j];
                result[j] = result[j + 1];
                result[j + 1] = tmp;
            }
        }
    }
    return result;
}

def _user_json(user: User, token: str = "") -> dict[str, any] {
    return {
        "user": {
            "email": user.email,
            "token": token if token else user.token,
            "username": user.username,
            "bio": user.bio,
            "image": user.image
        }
    };
}

def _profile_json(user: User, current_user: (User | None) = None) -> dict[str, any] {
    following = False;
    if current_user is not None {
        following = _is_following(current_user, user);
    }
    return {
        "profile": {
            "username": user.username,
            "bio": user.bio,
            "image": user.image,
            "following": following
        }
    };
}

def _article_json(article: Article, current_user: (User | None) = None) -> dict[str, any] {
    author = _article_author(article);
    favorited = _is_favorited(current_user, article) if current_user is not None else False;
    fav_count = _favorites_count(article);

    tag_names: list[str] = [];
    for t in [article-->][?:Tag] {
        tag_names.append(t.name);
    }

    return {
        "article": {
            "slug": article.slug,
            "title": article.title,
            "description": article.description,
            "body": article.body,
            "created_at": article.created_at,
            "updated_at": article.updated_at,
            "favorited": favorited,
            "favorites_count": fav_count,
            "author": _profile_json(author, current_user)["profile"] if author is not None else {},
            "tag_list": tag_names
        }
    };
}

def _comment_json(comment: Comment, current_user: (User | None) = None) -> dict[str, any] {
    author_edges = [comment<--[?:User]];
    author = author_edges[0] if author_edges else None;
    return {
        "comment": {
            "id": str(jid(comment)),
            "created_at": comment.created_at,
            "updated_at": comment.updated_at,
            "body": comment.body,
            "author": _profile_json(author, current_user)["profile"] if author is not None else {}
        }
    };
}

def _error(field: str, message: str) -> dict[str, any] {
    return {
        "errors": {
            field: [message]
        }
    };
}

def _error_unauthorized() -> dict[str, any] {
    return _error("token", "is invalid or missing");
}


# ============================================================================
# Health
# ============================================================================

def:pub health() -> dict[str, any] {
    return {
        "ok": True,
        "service": "jac-realworld-api",
        "status": "ready"
    };
}


# ============================================================================
# Users / Auth
# ============================================================================

def:pub user_register(username: str, email: str, password: str) -> dict[str, any] {
    if not username {
        return _error("username", "can't be empty");
    }
    if not email {
        return _error("email", "can't be empty");
    }
    if not password {
        return _error("password", "can't be empty");
    }

    existing_username = _find_user_by_username(username);
    if existing_username is not None {
        return _error("username", "has already been taken");
    }

    existing_email = _find_user_by_email(email);
    if existing_email is not None {
        return _error("email", "has already been taken");
    }

    user = User(
        username=username,
        email=email,
        password_hash=_hash_password(password),
        bio="",
        image=""
    );
    token = _generate_token();
    user.token = token;
    root ++> user;

    return _user_json(user, token);
}

def:pub user_login(email: str, password: str) -> dict[str, any] {
    if not email {
        return _error("email", "can't be empty");
    }
    if not password {
        return _error("password", "can't be empty");
    }

    user = _find_user_by_email(email);
    if user is None {
        return _error("email", "not found");
    }

    if not _check_password(password, user.password_hash) {
        return _error("password", "is invalid");
    }

    token = _generate_token();
    user.token = token;

    return _user_json(user, token);
}

def:pub user_current(token: str) -> dict[str, any] {
    user = _find_user_by_token(token);
    if user is None {
        return _error_unauthorized();
    }
    return _user_json(user, token);
}

def:pub user_update(
    token: str,
    email: str = "",
    username: str = "",
    bio: str = "",
    image: str = "",
    password: str = ""
) -> dict[str, any] {
    user = _find_user_by_token(token);
    if user is None {
        return _error_unauthorized();
    }

    if email and email != user.email {
        existing = _find_user_by_email(email);
        if existing is not None {
            return _error("email", "has already been taken");
        }
        user.email = email;
    }

    if username and username != user.username {
        existing = _find_user_by_username(username);
        if existing is not None {
            return _error("username", "has already been taken");
        }
        user.username = username;
    }

    if bio {
        user.bio = bio;
    }
    if image {
        user.image = image;
    }
    if password {
        user.password_hash = _hash_password(password);
    }

    return _user_json(user, token);
}


# ============================================================================
# Profiles
# ============================================================================

def:pub profile_get(token: str, username: str) -> dict[str, any] {
    target = _find_user_by_username(username);
    if target is None {
        return _error("username", "not found");
    }
    current_user = _find_user_by_token(token);
    return _profile_json(target, current_user);
}

def:pub profile_follow(token: str, username: str) -> dict[str, any] {
    current_user = _find_user_by_token(token);
    if current_user is None {
        return _error_unauthorized();
    }

    target = _find_user_by_username(username);
    if target is None {
        return _error("username", "not found");
    }

    if not _is_following(current_user, target) {
        current_user +>: Follows() :+> target;
    }

    return _profile_json(target, current_user);
}

def:pub profile_unfollow(token: str, username: str) -> dict[str, any] {
    current_user = _find_user_by_token(token);
    if current_user is None {
        return _error_unauthorized();
    }

    target = _find_user_by_username(username);
    if target is None {
        return _error("username", "not found");
    }

    edges = [edge current_user->:Follows:->target];
    for e in edges {
        del e;
    }

    return _profile_json(target, current_user);
}


# ============================================================================
# Articles
# ============================================================================

def:pub article_list(
    token: str = "",
    tag: str = "",
    author: str = "",
    favorited: str = "",
    limit: int = 20,
    offset: int = 0
) -> dict[str, any] {
    current_user = _find_user_by_token(token);

    all_articles: list[Article] = [];
    for u in [root-->][?:User] {
        for a in [u-->][?:Article] {
            all_articles.append(a);
        }
    }

    # Filter by tag
    if tag {
        filtered: list[Article] = [];
        for a in all_articles {
            has_tag = False;
            for t in [a-->][?:Tag] {
                if t.name == tag {
                    has_tag = True;
                    break;
                }
            }
            if has_tag {
                filtered.append(a);
            }
        }
        all_articles = filtered;
    }

    # Filter by author
    if author {
        filtered2: list[Article] = [];
        for a in all_articles {
            a_author = _article_author(a);
            if a_author is not None and a_author.username == author {
                filtered2.append(a);
            }
        }
        all_articles = filtered2;
    }

    # Filter by favorited by username
    if favorited {
        fav_user = _find_user_by_username(favorited);
        if fav_user is None {
            return {"articles": [], "articles_count": 0};
        }
        filtered3: list[Article] = [];
        for a in all_articles {
            if _is_favorited(fav_user, a) {
                filtered3.append(a);
            }
        }
        all_articles = filtered3;
    }

    # Sort by created_at descending
    all_articles = _sort_articles_desc(all_articles);

    # Paginate
    total = len(all_articles);
    page = all_articles[offset:offset + limit];

    articles_json: list = [];
    for a in page {
        articles_json.append(_article_json(a, current_user)["article"]);
    }

    return {
        "articles": articles_json,
        "articles_count": total
    };
}

def:pub article_feed(token: str, limit: int = 20, offset: int = 0) -> dict[str, any] {
    current_user = _find_user_by_token(token);
    if current_user is None {
        return _error_unauthorized();
    }

    feed_articles: list[Article] = [];

    # Get followed users
    followed: list = [current_user->:Follows:->];
    for fu in followed {
        for a in [fu-->][?:Article] {
            feed_articles.append(a);
        }
    }

    # Sort by created_at descending
    feed_articles = _sort_articles_desc(feed_articles);

    total = len(feed_articles);
    page = feed_articles[offset:offset + limit];

    articles_json: list = [];
    for a in page {
        articles_json.append(_article_json(a, current_user)["article"]);
    }

    return {
        "articles": articles_json,
        "articles_count": total
    };
}

def:pub article_get(token: str, slug: str) -> dict[str, any] {
    article = _find_article_by_slug(slug);
    if article is None {
        return _error("slug", "not found");
    }
    current_user = _find_user_by_token(token);
    return _article_json(article, current_user);
}

def:pub article_create(
    token: str,
    title: str,
    description: str,
    body: str,
    tag_list: (list[str] | None) = None
) -> dict[str, any] {
    current_user = _find_user_by_token(token);
    if current_user is None {
        return _error_unauthorized();
    }

    if not title {
        return _error("title", "can't be empty");
    }

    now = _now_iso();
    slug = _slugify(title);

    # Handle slug collisions
    existing = _find_article_by_slug(slug);
    if existing is not None {
        slug = slug + "-" + hashlib.sha256(now.encode()).hexdigest()[:6];
    }

    article = Article(
        slug=slug,
        title=title,
        description=description,
        body=body,
        created_at=now,
        updated_at=now
    );
    current_user ++> article;

    # Create/connect tags
    tags_to_add = tag_list if tag_list is not None else [];
    for tag_name in tags_to_add {
        # Find existing tag or create a new one
        found = False;
        for t in [root-->][?:Tag] {
            if t.name == tag_name {
                article ++> t;
                found = True;
                break;
            }
        }
        if not found {
            new_tag = Tag(name=tag_name);
            root ++> new_tag;
            article ++> new_tag;
        }
    }

    return _article_json(article, current_user);
}

def:pub article_update(
    token: str,
    slug: str,
    title: str = "",
    description: str = "",
    body: str = ""
) -> dict[str, any] {
    current_user = _find_user_by_token(token);
    if current_user is None {
        return _error_unauthorized();
    }

    article = _find_article_by_slug(slug);
    if article is None {
        return _error("slug", "not found");
    }

    # Check ownership
    author = _article_author(article);
    if author is None or author.username != current_user.username {
        return _error("article", "you can only edit your own articles");
    }

    if title {
        article.title = title;
        article.slug = _slugify(title);
    }
    if description {
        article.description = description;
    }
    if body {
        article.body = body;
    }
    article.updated_at = _now_iso();

    return _article_json(article, current_user);
}

def:pub article_delete(token: str, slug: str) -> dict[str, any] {
    current_user = _find_user_by_token(token);
    if current_user is None {
        return _error_unauthorized();
    }

    article = _find_article_by_slug(slug);
    if article is None {
        return _error("slug", "not found");
    }

    author = _article_author(article);
    if author is None or author.username != current_user.username {
        return _error("article", "you can only delete your own articles");
    }

    # Remove comments
    for c in [article<--[?:Comment]] {
        del c;
    }
    # Remove tag edges
    tag_edges = [edge article->:HasTag:->];
    for te in tag_edges {
        del te;
    }
    # Remove favorite edges from all users
    for u in [root-->][?:User] {
        fav_edges = [edge u->:Favorited:->article];
        for fe in fav_edges {
            del fe;
        }
    }
    # Remove authored edge
    auth_edges = [edge author->:Authored:->article];
    for ae in auth_edges {
        del ae;
    }

    del article;

    return {"ok": True};
}


# ============================================================================
# Favorites
# ============================================================================

def:pub article_favorite(token: str, slug: str) -> dict[str, any] {
    current_user = _find_user_by_token(token);
    if current_user is None {
        return _error_unauthorized();
    }

    article = _find_article_by_slug(slug);
    if article is None {
        return _error("slug", "not found");
    }

    if not _is_favorited(current_user, article) {
        current_user +>: Favorited() :+> article;
    }

    return _article_json(article, current_user);
}

def:pub article_unfavorite(token: str, slug: str) -> dict[str, any] {
    current_user = _find_user_by_token(token);
    if current_user is None {
        return _error_unauthorized();
    }

    article = _find_article_by_slug(slug);
    if article is None {
        return _error("slug", "not found");
    }

    edges = [edge current_user->:Favorited:->article];
    for e in edges {
        del e;
    }

    return _article_json(article, current_user);
}


# ============================================================================
# Comments
# ============================================================================

def:pub comment_list(token: str, slug: str) -> dict[str, any] {
    article = _find_article_by_slug(slug);
    if article is None {
        return _error("slug", "not found");
    }

    current_user = _find_user_by_token(token);

    comments_json: list = [];
    for c in [article<--[?:Comment]] {
        comments_json.append(_comment_json(c, current_user)["comment"]);
    }

    comments_json = _sort_comments_asc(comments_json);

    return {"comments": comments_json};
}

def:pub comment_create(token: str, slug: str, body: str) -> dict[str, any] {
    current_user = _find_user_by_token(token);
    if current_user is None {
        return _error_unauthorized();
    }

    article = _find_article_by_slug(slug);
    if article is None {
        return _error("slug", "not found");
    }

    if not body {
        return _error("body", "can't be empty");
    }

    now = _now_iso();
    comment = Comment(body=body, created_at=now, updated_at=now);
    current_user ++> comment;
    comment ++> article;

    return _comment_json(comment, current_user);
}

def:pub comment_delete(token: str, slug: str, comment_id: str) -> dict[str, any] {
    current_user = _find_user_by_token(token);
    if current_user is None {
        return _error_unauthorized();
    }

    article = _find_article_by_slug(slug);
    if article is None {
        return _error("slug", "not found");
    }

    # Find the comment by its jid
    target_comment: (Comment | None) = None;
    for c in [article<--[?:Comment]] {
        if str(jid(c)) == comment_id {
            target_comment = c;
            break;
        }
    }

    if target_comment is None {
        return _error("comment", "not found");
    }

    # Check ownership
    comment_authors = [target_comment<--[?:User]];
    if not comment_authors or comment_authors[0].username != current_user.username {
        return _error("comment", "you can only delete your own comments");
    }

    del target_comment;

    return {"ok": True};
}


# ============================================================================
# Tags
# ============================================================================

def:pub tag_list() -> dict[str, any] {
    tags: list[str] = [];
    for t in [root-->][?:Tag] {
        tags.append(t.name);
    }
    tags.sort();
    return {"tags": tags};
}


# ============================================================================
# Entry
# ============================================================================

with entry {
    print("RealWorld Conduit API loaded. Start server: jac start main.jac --dev --no_client");
    print("Endpoints: /function/<name>  (POST with JSON body)");
    print("Auth: pass 'token' parameter from login/register response");
}
