import json
import threading
import time
import unittest
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from http.server import HTTPServer
import server


class BankAPITests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.httpd = HTTPServer(("127.0.0.1", 0), server.Handler)
        cls.base = f"http://127.0.0.1:{cls.httpd.server_port}"
        cls.thread = threading.Thread(target=cls.httpd.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.httpd.shutdown()
        cls.httpd.server_close()
        cls.thread.join()

    def setUp(self):
        server.SESSIONS.clear()

    def request(self, path, method="GET", body=None, token=None):
        headers = {"Content-Type": "application/json"}
        if token:
            headers["Authorization"] = f"Bearer {token}"
        request = Request(self.base + path, method=method, headers=headers,
                          data=json.dumps(body).encode() if body is not None else None)
        try:
            response = urlopen(request, timeout=2)
        except HTTPError as error:
            response = error
        with response:
            return response.status, json.load(response)

    def login(self):
        status, body = self.request("/auth/login", "POST", {"email": "demo@example.com", "password": "Demo123!"})
        self.assertEqual(status, 200)
        return body["accessToken"]

    def test_login_and_account(self):
        token = self.login()
        status, body = self.request("/account", token=token)
        self.assertEqual(status, 200)
        self.assertEqual(body["balanceCents"], 428075)
        self.assertIn("••••", body["maskedNumber"])

    def test_wrong_password(self):
        self.assertEqual(self.request("/auth/login", "POST", {"email": "demo@example.com", "password": "wrong"})[0], 401)

    def test_missing_or_unknown_token(self):
        self.assertEqual(self.request("/account")[0], 401)
        self.assertEqual(self.request("/transactions", token="unknown")[0], 401)

    def test_expired_token(self):
        token = self.login()
        server.SESSIONS[token] = time.time() - 1
        self.assertEqual(self.request("/account", token=token)[0], 401)

    def test_logout_revokes_token(self):
        token = self.login()
        self.assertEqual(self.request("/auth/logout", "POST", token=token)[0], 200)
        self.assertEqual(self.request("/account", token=token)[0], 401)

    def test_transactions_have_integer_amounts_and_iso_dates(self):
        status, body = self.request("/transactions", token=self.login())
        self.assertEqual(status, 200)
        self.assertEqual(len(body), 4)
        self.assertTrue(all(isinstance(row["amountCents"], int) for row in body))
        self.assertTrue(all(row["date"].endswith("Z") for row in body))
        self.assertEqual(len({row["id"] for row in body}), 4)

    def test_invalid_json_shape(self):
        self.assertEqual(self.request("/auth/login", "POST", ["invalid"])[0], 400)
        self.assertEqual(self.request("/auth/login", "POST", {"email": 123, "password": None})[0], 400)

    def test_unknown_route(self):
        self.assertEqual(self.request("/unknown")[0], 404)


if __name__ == "__main__":
    unittest.main()
