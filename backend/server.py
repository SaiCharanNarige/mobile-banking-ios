"""Loopback-only fictional banking REST API. Python 3.10+, no dependencies."""
import json
import secrets
import time
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer

SESSIONS = {}
TOKEN_TTL_SECONDS = 900


def iso(timestamp):
    return datetime.fromtimestamp(timestamp, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass  # Do not log credentials, tokens, or request bodies.

    def reply(self, status, body):
        payload = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def authorized_token(self):
        header = self.headers.get("Authorization", "")
        token = header.removeprefix("Bearer ") if header.startswith("Bearer ") else ""
        if SESSIONS.get(token, 0) <= time.time():
            SESSIONS.pop(token, None)
            self.reply(401, {"error": "Session expired or invalid"})
            return None
        return token

    def do_POST(self):
        if self.path == "/auth/login":
            try:
                length = int(self.headers.get("Content-Length", "0"))
                if not 0 < length <= 4096:
                    raise ValueError("Invalid body size")
                body = json.loads(self.rfile.read(length))
                if not isinstance(body, dict):
                    raise ValueError("Expected object")
                email, password = body.get("email"), body.get("password")
                if not isinstance(email, str) or not isinstance(password, str):
                    raise ValueError("Expected string credentials")
            except (ValueError, UnicodeDecodeError):
                self.reply(400, {"error": "Provide a JSON email and password"})
                return
            if email.lower() != "demo@example.com" or password != "Demo123!":
                self.reply(401, {"error": "Invalid demo credentials"})
                return
            # Remove old sessions so repeated demo logins don't retain expired entries.
            for old_token, expiry in list(SESSIONS.items()):
                if expiry <= time.time():
                    SESSIONS.pop(old_token, None)
            token = secrets.token_urlsafe(32)
            expiry = int(time.time()) + TOKEN_TTL_SECONDS
            SESSIONS[token] = expiry
            self.reply(200, {"accessToken": token, "expiresAt": iso(expiry)})
        elif self.path == "/auth/logout":
            token = self.authorized_token()
            if token:
                SESSIONS.pop(token, None)
                self.reply(200, {"ok": True})
        else:
            self.reply(404, {"error": "Endpoint not found"})

    def do_GET(self):
        if self.path == "/health":
            self.reply(200, {"ok": True})
            return
        if self.path not in ("/account", "/transactions"):
            self.reply(404, {"error": "Endpoint not found"})
            return
        if not self.authorized_token():
            return
        if self.path == "/account":
            self.reply(200, {"owner": "Alex Morgan", "name": "Everyday Checking",
                             "maskedNumber": "•••• 4821", "balanceCents": 428075, "currency": "USD"})
        else:
            entries = [("Monthly payroll", 325000, "Income"),
                       ("Neighborhood Market", -6842, "Groceries"),
                       ("Morning Coffee", -575, "Dining"),
                       ("Internet bill", -6500, "Utilities")]
            self.reply(200, [{"id": str(i), "merchant": merchant,
                              "date": iso(time.time() - (i * 86400)),
                              "amountCents": cents, "currency": "USD", "category": category}
                             for i, (merchant, cents, category) in enumerate(entries, 1)])


if __name__ == "__main__":
    print("Fictional demo API: http://localhost:8000 (loopback only)", flush=True)
    print("Demo credentials: demo@example.com / Demo123!", flush=True)
    with HTTPServer(("127.0.0.1", 8000), Handler) as server:
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass
