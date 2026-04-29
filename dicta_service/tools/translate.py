"""תרגום עברית↔אנגלית דרך Dicta Cloud."""
from __future__ import annotations
import logging
import requests

from dicta_service.config import DICTA_CLOUD, ALLOW_CLOUD

log = logging.getLogger("tools.translate")


def translate(text: str, *, source: str = "he", target: str = "en") -> str:
    if not ALLOW_CLOUD:
        raise RuntimeError("translate requires cloud access")
    payload = {"text": text, "source": source, "target": target}
    r = requests.post(DICTA_CLOUD["translate"], json=payload, timeout=60)
    r.raise_for_status()
    body = r.json()
    if isinstance(body, dict):
        return body.get("translation") or body.get("text") or ""
    return str(body)
