from __future__ import annotations

import hmac
import os
from typing import Any

SECRET_ARN = os.getenv("API_TOKEN_SECRET_ARN", "")


def extract_bearer_token(headers: dict[str, Any] | None) -> str:
    if not headers:
        return ""
    value = ""
    for key, candidate in headers.items():
        if str(key).lower() == "authorization":
            value = str(candidate or "").strip()
            break
    if not value.lower().startswith("bearer "):
        return ""
    return value[7:].strip()


def get_secrets_client() -> Any:
    import boto3

    return boto3.client("secretsmanager")


def load_expected_token() -> str:
    if not SECRET_ARN:
        return ""
    result = get_secrets_client().get_secret_value(SecretId=SECRET_ARN)
    return str(result.get("SecretString") or "")


def is_token_authorized(provided: str, expected: str) -> bool:
    if not provided or not expected:
        return False
    return hmac.compare_digest(provided.encode("utf-8"), expected.encode("utf-8"))


def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    provided = extract_bearer_token(event.get("headers"))
    try:
        expected = load_expected_token()
        allowed = is_token_authorized(provided, expected)
    except Exception:
        allowed = False

    return {
        "isAuthorized": allowed,
        "context": {"principalId": "api-client" if allowed else "anonymous"},
    }
