import json
import os
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, os.path.abspath("src"))

import app


class Context:
    aws_request_id = "req-123"


class AppTests(unittest.TestCase):
    def test_health_route(self):
        event = {"rawPath": "/health", "requestContext": {"http": {"method": "GET"}}}
        result = app.lambda_handler(event, Context())
        self.assertEqual(result["statusCode"], 200)
        self.assertEqual(json.loads(result["body"])["status"], "ok")

    def test_rejects_invalid_json(self):
        event = {
            "rawPath": "/v1/generate",
            "requestContext": {"http": {"method": "POST"}},
            "body": "{not-json",
        }
        result = app.lambda_handler(event, Context())
        self.assertEqual(result["statusCode"], 400)

    def test_rejects_empty_prompt(self):
        event = {
            "rawPath": "/v1/generate",
            "requestContext": {"http": {"method": "POST"}},
            "body": json.dumps({"prompt": "   "}),
        }
        result = app.lambda_handler(event, Context())
        self.assertEqual(result["statusCode"], 400)

    @patch("app.invoke_model", return_value="Short-lived credentials reduce exposure.")
    def test_generate_route(self, invoke_model):
        event = {
            "rawPath": "/v1/generate",
            "requestContext": {"http": {"method": "POST"}},
            "body": json.dumps({"prompt": "Why use short-lived credentials?"}),
        }
        result = app.lambda_handler(event, Context())
        payload = json.loads(result["body"])
        self.assertEqual(result["statusCode"], 200)
        self.assertIn("answer", payload)
        invoke_model.assert_called_once()


if __name__ == "__main__":
    unittest.main()
