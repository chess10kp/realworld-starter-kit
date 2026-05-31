"""RealWorld Conduit API adapter for Jac backend.

This adapter sits between RealWorld clients and the Jac function server,
providing exact RealWorld route compatibility:

  - Maps /api/* routes to Jac /function/* calls
  - Unwraps RealWorld request envelopes (e.g. {"user": {...}})
  - Extracts Authorization: Token <jwt> → token parameter
  - Returns RealWorld response envelopes with correct HTTP status codes

Usage:
  1. Start Jac server:   jac start main.jac --dev --no_client
  2. Start adapter:      python3 adapter.py
  3. RealWorld API at:   http://localhost:3000/api/
"""

import json
import sys
import urllib.request
import urllib.error
from http.server import HTTPServer, BaseHTTPRequestHandler


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
JAC_HOST = "localhost"
JAC_PORT = 8000
ADAPTER_PORT = 3000
API_PREFIX = "/api"


# ---------------------------------------------------------------------------
# Jac function call helper
# ---------------------------------------------------------------------------
def jac_call(name: str, body: dict | None = None, method: str = "POST") -> tuple[dict, int]:
    """Call a Jac function via HTTP and return (data, status_code)."""
    url = f"http://{JAC_HOST}:{JAC_PORT}/function/{name}"
    payload = json.dumps(body or {}).encode("utf-8")

    req = urllib.request.Request(
        url, data=payload, method=method,
        headers={"Content-Type": "application/json"}
    )
    try:
        with urllib.request.urlopen(req) as resp:
            raw = json.loads(resp.read().decode("utf-8"))
            # Jac wraps in {"ok": true, "data": {"result": ..., "reports": []}}
            envelope = raw
            if isinstance(envelope, dict) and "data" in envelope:
                inner = envelope["data"]
                if isinstance(inner, dict) and "result" in inner:
                    data = inner["result"]
                else:
                    data = inner
            elif isinstance(envelope, dict) and "result" in envelope:
                data = envelope["result"]
            else:
                data = raw
            if isinstance(data, dict) and "error" in data:
                return {"errors": {"body": [data["error"]]}}, 422
            return data, 200
    except urllib.error.HTTPError as e:
        raw = {}
        try:
            raw = json.loads(e.read().decode("utf-8"))
        except Exception:
            pass
        envelope = raw
        if isinstance(envelope, dict) and "data" in envelope:
            inner = envelope["data"]
            if isinstance(inner, dict) and "result" in inner:
                data = inner["result"]
            else:
                data = inner
        elif isinstance(envelope, dict) and "result" in envelope:
            data = envelope["result"]
        else:
            data = raw
        if isinstance(data, dict) and "error" in data:
            return {"errors": {"body": [data["error"]]}}, e.code
        return data, e.code
    except Exception as e:
        return {"errors": {"body": [str(e)]}}, 500


def extract_token(headers) -> str:
    """Extract token from Authorization: Token <jwt> header."""
    auth = headers.get("Authorization", "")
    if auth.startswith("Token "):
        return auth[6:].strip()
    if auth.startswith("Bearer "):
        return auth[7:].strip()
    return ""


# ---------------------------------------------------------------------------
# Route definitions: (pattern, method, handler)
# ---------------------------------------------------------------------------
ROUTES = []


def route(method: str, path: str):
    """Decorator to register a route handler."""
    def decorator(func):
        ROUTES.append((method, path, func))
        return func
    return decorator


# --- Users ---
@route("POST", "/api/users")
def register(body, headers, path_params):
    data = body.get("user", {})
    result, status = jac_call("user_register", {
        "username": data.get("username", ""),
        "email": data.get("email", ""),
        "password": data.get("password", "")
    })
    if "errors" in result:
        return result, 422
    return result, 201


@route("POST", "/api/users/login")
def login(body, headers, path_params):
    data = body.get("user", {})
    result, status = jac_call("user_login", {
        "email": data.get("email", ""),
        "password": data.get("password", "")
    })
    if "errors" in result:
        return result, 422
    return result, 200


@route("GET", "/api/user")
def current_user(body, headers, path_params):
    token = extract_token(headers)
    if not token:
        return {"errors": {"token": ["is invalid or missing"]}}, 401
    result, status = jac_call("user_current", {"token": token})
    if "errors" in result:
        return result, 401
    return result, 200


@route("PUT", "/api/user")
def update_user(body, headers, path_params):
    token = extract_token(headers)
    if not token:
        return {"errors": {"token": ["is invalid or missing"]}}, 401
    data = body.get("user", {})
    result, status = jac_call("user_update", {
        "token": token,
        "email": data.get("email", ""),
        "username": data.get("username", ""),
        "bio": data.get("bio", ""),
        "image": data.get("image", ""),
        "password": data.get("password", "")
    })
    if "errors" in result:
        return result, 422
    return result, 200


# --- Profiles ---
@route("GET", "/api/profiles/{username}")
def get_profile(body, headers, path_params):
    token = extract_token(headers)
    result, status = jac_call("profile_get", {
        "token": token,
        "username": path_params["username"]
    })
    if "errors" in result:
        return result, 404
    return result, 200


@route("POST", "/api/profiles/{username}/follow")
def follow(body, headers, path_params):
    token = extract_token(headers)
    if not token:
        return {"errors": {"token": ["is invalid or missing"]}}, 401
    result, status = jac_call("profile_follow", {
        "token": token,
        "username": path_params["username"]
    })
    if "errors" in result:
        return result, 422
    return result, 200


@route("DELETE", "/api/profiles/{username}/follow")
def unfollow(body, headers, path_params):
    token = extract_token(headers)
    if not token:
        return {"errors": {"token": ["is invalid or missing"]}}, 401
    result, status = jac_call("profile_unfollow", {
        "token": token,
        "username": path_params["username"]
    })
    if "errors" in result:
        return result, 422
    return result, 200


# --- Articles ---
@route("GET", "/api/articles")
def list_articles(body, headers, path_params):
    token = extract_token(headers)
    # Parse query params from path
    qs = path_params.get("_query", {})
    result, status = jac_call("article_list", {
        "token": token,
        "tag": qs.get("tag", ""),
        "author": qs.get("author", ""),
        "favorited": qs.get("favorited", ""),
        "limit": int(qs.get("limit", "20")),
        "offset": int(qs.get("offset", "0"))
    })
    return result, 200


@route("GET", "/api/articles/feed")
def feed(body, headers, path_params):
    token = extract_token(headers)
    if not token:
        return {"errors": {"token": ["is invalid or missing"]}}, 401
    qs = path_params.get("_query", {})
    result, status = jac_call("article_feed", {
        "token": token,
        "limit": int(qs.get("limit", "20")),
        "offset": int(qs.get("offset", "0"))
    })
    if "errors" in result:
        return result, 401
    return result, 200


@route("GET", "/api/articles/{slug}")
def get_article(body, headers, path_params):
    token = extract_token(headers)
    result, status = jac_call("article_get", {
        "token": token,
        "slug": path_params["slug"]
    })
    if "errors" in result:
        return result, 404
    return result, 200


@route("POST", "/api/articles")
def create_article(body, headers, path_params):
    token = extract_token(headers)
    if not token:
        return {"errors": {"token": ["is invalid or missing"]}}, 401
    data = body.get("article", {})
    result, status = jac_call("article_create", {
        "token": token,
        "title": data.get("title", ""),
        "description": data.get("description", ""),
        "body": data.get("body", ""),
        "tag_list": data.get("tagList", [])
    })
    if "errors" in result:
        return result, 422
    return result, 201


@route("PUT", "/api/articles/{slug}")
def update_article(body, headers, path_params):
    token = extract_token(headers)
    if not token:
        return {"errors": {"token": ["is invalid or missing"]}}, 401
    data = body.get("article", {})
    result, status = jac_call("article_update", {
        "token": token,
        "slug": path_params["slug"],
        "title": data.get("title", ""),
        "description": data.get("description", ""),
        "body": data.get("body", "")
    })
    if "errors" in result:
        return result, 422
    return result, 200


@route("DELETE", "/api/articles/{slug}")
def delete_article(body, headers, path_params):
    token = extract_token(headers)
    if not token:
        return {"errors": {"token": ["is invalid or missing"]}}, 401
    result, status = jac_call("article_delete", {
        "token": token,
        "slug": path_params["slug"]
    })
    if "errors" in result:
        return result, 422
    return result, 200


# --- Favorites ---
@route("POST", "/api/articles/{slug}/favorite")
def favorite(body, headers, path_params):
    token = extract_token(headers)
    if not token:
        return {"errors": {"token": ["is invalid or missing"]}}, 401
    result, status = jac_call("article_favorite", {
        "token": token,
        "slug": path_params["slug"]
    })
    if "errors" in result:
        return result, 422
    return result, 200


@route("DELETE", "/api/articles/{slug}/favorite")
def unfavorite(body, headers, path_params):
    token = extract_token(headers)
    if not token:
        return {"errors": {"token": ["is invalid or missing"]}}, 401
    result, status = jac_call("article_unfavorite", {
        "token": token,
        "slug": path_params["slug"]
    })
    if "errors" in result:
        return result, 422
    return result, 200


# --- Comments ---
@route("GET", "/api/articles/{slug}/comments")
def list_comments(body, headers, path_params):
    token = extract_token(headers)
    result, status = jac_call("comment_list", {
        "token": token,
        "slug": path_params["slug"]
    })
    if "errors" in result:
        return result, 404
    return result, 200


@route("POST", "/api/articles/{slug}/comments")
def create_comment(body, headers, path_params):
    token = extract_token(headers)
    if not token:
        return {"errors": {"token": ["is invalid or missing"]}}, 401
    data = body.get("comment", {})
    result, status = jac_call("comment_create", {
        "token": token,
        "slug": path_params["slug"],
        "body": data.get("body", "")
    })
    if "errors" in result:
        return result, 422
    return result, 201


@route("DELETE", "/api/articles/{slug}/comments/{id}")
def delete_comment(body, headers, path_params):
    token = extract_token(headers)
    if not token:
        return {"errors": {"token": ["is invalid or missing"]}}, 401
    result, status = jac_call("comment_delete", {
        "token": token,
        "slug": path_params["slug"],
        "comment_id": path_params["id"]
    })
    if "errors" in result:
        return result, 422
    return result, 200


# --- Tags ---
@route("GET", "/api/tags")
def tags(body, headers, path_params):
    result, status = jac_call("tag_list")
    return result, 200


# ---------------------------------------------------------------------------
# URL matching
# ---------------------------------------------------------------------------
def match_route(method: str, path: str):
    """Match a request to a registered route, returning (handler, params)."""
    for rmethod, rpath, handler in ROUTES:
        if rmethod != method:
            continue

        # Split path and pattern
        path_parts = path.split("?")[0].strip("/").split("/")
        pat_parts = rpath.strip("/").split("/")

        if len(path_parts) != len(pat_parts):
            # Check for feed special case
            continue

        params = {}
        match = True
        for pp, rp in zip(path_parts, pat_parts):
            if rp.startswith("{") and rp.endswith("}"):
                params[rp[1:-1]] = pp
            elif pp != rp:
                match = False
                break

        if match:
            # Parse query string
            if "?" in path:
                qs_part = path.split("?", 1)[1]
                query = {}
                for pair in qs_part.split("&"):
                    if "=" in pair:
                        k, v = pair.split("=", 1)
                        query[urllib.parse.unquote(k)] = urllib.parse.unquote(v)
                params["_query"] = query
            else:
                params["_query"] = {}
            return handler, params

    return None, {}


# ---------------------------------------------------------------------------
# HTTP Handler
# ---------------------------------------------------------------------------
class RealWorldAdapter(BaseHTTPRequestHandler):
    def _handle(self, method: str):
        # Read body
        content_length = int(self.headers.get("Content-Length", 0))
        body = {}
        if content_length > 0:
            raw = self.rfile.read(content_length)
            try:
                body = json.loads(raw.decode("utf-8"))
            except json.JSONDecodeError:
                self._send(400, {"errors": {"body": ["Invalid JSON"]}})
                return

        path = self.path
        handler, params = match_route(method, path)

        if handler is None:
            self._send(404, {"errors": {"path": ["Not found"]}})
            return

        try:
            result, status = handler(body, self.headers, params)
            self._send(status, result)
        except Exception as e:
            self._send(500, {"errors": {"body": [str(e)]}})

    def do_GET(self):
        self._handle("GET")

    def do_POST(self):
        self._handle("POST")

    def do_PUT(self):
        self._handle("PUT")

    def do_DELETE(self):
        self._handle("DELETE")

    def do_OPTIONS(self):
        self.send_response(200)
        self._cors_headers()
        self.end_headers()

    def _send(self, status: int, data: dict):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self._cors_headers()
        self.end_headers()
        self.wfile.write(json.dumps(data).encode("utf-8"))

    def _cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")

    def log_message(self, format, *args):
        # Quiet logging
        pass


import urllib.parse


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    host = "0.0.0.0"
    port = ADAPTER_PORT

    if len(sys.argv) > 1:
        port = int(sys.argv[1])

    server = HTTPServer((host, port), RealWorldAdapter)
    print(f"🚀 RealWorld Conduit API adapter")
    print(f"   Adapter:  http://{host}:{port}")
    print(f"   Jac backend: http://{JAC_HOST}:{JAC_PORT}")
    print(f"   Routes: {len(ROUTES)} registered")
    print(f"   Ready for RealWorld clients!")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")
        server.server_close()


if __name__ == "__main__":
    main()
