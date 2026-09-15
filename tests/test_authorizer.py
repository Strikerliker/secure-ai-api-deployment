import os
import sys
import unittest

sys.path.insert(0, os.path.abspath("src"))

import authorizer


class AuthorizerTests(unittest.TestCase):
    def test_extracts_bearer_token_case_insensitive(self):
        token = authorizer.extract_bearer_token({"Authorization": "Bearer abc123"})
        self.assertEqual(token, "abc123")

    def test_rejects_missing_bearer_scheme(self):
        token = authorizer.extract_bearer_token({"authorization": "abc123"})
        self.assertEqual(token, "")

    def test_constant_time_token_check(self):
        self.assertTrue(authorizer.is_token_authorized("same-token", "same-token"))
        self.assertFalse(authorizer.is_token_authorized("wrong", "same-token"))
        self.assertFalse(authorizer.is_token_authorized("", "same-token"))


if __name__ == "__main__":
    unittest.main()
