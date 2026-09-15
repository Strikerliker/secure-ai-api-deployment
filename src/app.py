from __future__ import annotations

import json
import os
from typing import Any

SERVICE_NAME = "secure-ai-api"
MODEL_ID = os.getenv("MODEL_ID", "amazon.nova-lite-v1:0")
MAX_PROMPT_CHARS = int(os.getenv("MAX_PROMPT_CHARS", "4000"))


def response(status_code: int, body: dict[str, Any]) -> dict[str, Any]:
    return {
        "statusCode": status_code,
        "headers": {
            "content-type": "application/json",
            "cache-control": "no-store",
            "x-content-type-options": "nosniff",
        },
        "body": json.dumps(body),
    }


def parse_json_body(event: dict[str, Any]) -> dict[str, Any]:
    raw = event.get("body")
    if raw is None:
        return {}
    if isinstance(raw, dict):
        return raw
    try:
        parsed = json.loads(raw)
    except (TypeError, json.JSONDecodeError) as exc:
        raise ValueError("Request body must be valid JSON.") from exc
    if not isinstance(parsed, dict):
        raise ValueError("Request body must be a JSON object.")
    return parsed


def validate_prompt(value: Any) -> str:
    if not isinstance(value, str):
        raise ValueError("prompt must be a string.")
    prompt = value.strip()
    if not prompt:
        raise ValueError("prompt is required.")
    if len(prompt) > MAX_PROMPT_CHARS:
        raise ValueError(f"prompt exceeds the {MAX_PROMPT_CHARS}-character limit.")
    return prompt


def get_bedrock_client() -> Any:
    import boto3

    return boto3.client("bedrock-runtime")


def invoke_model(prompt: str) -> str:
    client = get_bedrock_client()
    result = client.converse(
        modelId=MODEL_ID,
        system=[
            {
                "text": (
                    "You are a concise enterprise AI assistant. "
                    "Answer the user's request directly and do not claim access to data "
                    "or systems that are not provided in the conversation."
                )
            }
        ],
        messages=[{"role": "user", "content": [{"text": prompt}]}],
        inferenceConfig={"maxTokens": 800, "temperature": 0.2},
    )
    blocks = result.get("output", {}).get("message", {}).get("content", [])
    text = "".join(block.get("text", "") for block in blocks if isinstance(block, dict)).strip()
    if not text:
        raise RuntimeError("The model returned an empty response.")
    return text


def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    request_context = event.get("requestContext", {})
    http = request_context.get("http", {})
    method = str(http.get("method", "")).upper()
    path = str(event.get("rawPath") or http.get("path") or "")

    if method == "GET" and path == "/health":
        return response(200, {"status": "ok", "service": SERVICE_NAME})

    if method != "POST" or path != "/v1/generate":
        return response(404, {"error": "not_found"})

    try:
        payload = parse_json_body(event)
        prompt = validate_prompt(payload.get("prompt"))
        answer = invoke_model(prompt)
    except ValueError as exc:
        return response(400, {"error": "invalid_request", "message": str(exc)})
    except Exception:
        return response(
            502,
            {
                "error": "model_unavailable",
                "message": "The AI service could not complete the request.",
            },
        )

    request_id = getattr(context, "aws_request_id", None) if context else None
    return response(
        200,
        {
            "service": SERVICE_NAME,
            "model": MODEL_ID,
            "request_id": request_id,
            "answer": answer,
        },
    )
