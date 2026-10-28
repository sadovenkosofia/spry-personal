"""agenda-parser Lambda (outside the VPC: it needs no database).

Function URL -> verify the Cognito id token -> parse_agenda -> JSON.
It never writes anything. Saving goes through the normal API.
"""

import base64
import json
import logging
import os
import time
from datetime import date
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

import jwt
from botocore.exceptions import ClientError

from app.ai import agenda as ag

log = logging.getLogger()
log.setLevel(logging.INFO)

AUTH_REGION = os.environ["AUTH_REGION"]
USER_POOL_ID = os.environ["USER_POOL_ID"]
CLIENT_ID = os.environ["USER_POOL_CLIENT_ID"]
ISSUER = f"https://cognito-idp.{AUTH_REGION}.amazonaws.com/{USER_POOL_ID}"
_jwks = jwt.PyJWKClient(f"{ISSUER}/.well-known/jwks.json")  # keys are cached between calls

MAX_CHARS = 10_000


class Unauthorized(Exception):
    pass


def verify_token(header: str) -> dict:
    scheme, _, token = header.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise Unauthorized("missing bearer token")
    try:
        key = _jwks.get_signing_key_from_jwt(token).key
        claims = jwt.decode(
            token, key, algorithms=["RS256"], audience=CLIENT_ID, issuer=ISSUER
        )
    except jwt.PyJWTError as e:
        raise Unauthorized(str(e)) from e
    if claims.get("token_use") != "id":
        raise Unauthorized("not an id token")
    return claims


def resp(status: int, body: dict) -> dict:
    return {
        "statusCode": status,
        "headers": {"content-type": "application/json"},
        "body": json.dumps(body, ensure_ascii=False),
    }


def handler(event, context):
    headers = event.get("headers") or {}
    try:
        claims = verify_token(headers.get("authorization", ""))
    except Unauthorized as e:
        log.info("unauthorized: %s", e)
        return resp(401, {"error": "unauthorized"})

    raw = event.get("body") or ""
    if event.get("isBase64Encoded"):
        raw = base64.b64decode(raw).decode("utf-8")
    try:
        body = json.loads(raw)
        text = body["text"]
        today = date.fromisoformat(body["today"])
        tz = body["tz"]
        ZoneInfo(tz)  # validates the time zone name
        if not isinstance(text, str) or not text.strip():
            raise ValueError("empty text")
    except (ValueError, KeyError, TypeError, ZoneInfoNotFoundError):
        return resp(400, {"error": "send JSON with text, today (YYYY-MM-DD) and tz"})

    if len(text) > MAX_CHARS:
        return resp(413, {"error": f"text is longer than {MAX_CHARS} characters"})

    started = time.monotonic()
    try:
        parsed, usage = ag.parse_agenda(text, today, tz)
    except ag.AgendaParseError as e:
        return resp(422, {"error": str(e)})
    except ClientError as e:
        code = e.response.get("Error", {}).get("Code", "")
        if code in ("ThrottlingException", "TooManyRequestsException"):
            return resp(429, {"error": "the service is busy, try again in a minute"})
        log.exception("bedrock call failed")
        return resp(502, {"error": "the model is unavailable"})

    # This is the line you submit.
    log.info(json.dumps({
        "event": "agenda_parsed",
        "user": claims["sub"],
        "model": ag.MODEL_ID,
        "prompt_version": ag.PROMPT_VERSION,
        **usage,
        "latency_ms": int((time.monotonic() - started) * 1000),
        "cost_usd": ag.cost_usd(ag.MODEL_ID, usage),
    }))
    return resp(200, {
        "agenda": parsed.model_dump(mode="json"),
        "model": ag.MODEL_ID,
        "prompt_version": ag.PROMPT_VERSION,
    })
