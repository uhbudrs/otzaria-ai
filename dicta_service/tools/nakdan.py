"""ניקוד אוטומטי - רץ דרך Dicta Cloud (Nakdan API)."""
from __future__ import annotations
import logging
import requests

from dicta_service.config import DICTA_CLOUD, ALLOW_CLOUD

log = logging.getLogger("tools.nakdan")


def vocalize(text: str, *, genre: str = "modern") -> str:
    """מקבל טקסט עברי לא מנוקד, מחזיר טקסט מנוקד.

    genre: 'modern' (ברירת מחדל) או 'rabbinic' לסגנון רבני.
    """
    if not ALLOW_CLOUD:
        raise RuntimeError("nakdan requires cloud access - enable OTZARIA_AI_CLOUD=1")

    payload = {
        "task": "nakdan",
        "data": text,
        "genre": genre,
        "addmorph": False,
        "matchpartial": True,
        "keepmetagim": False,
    }
    r = requests.post(DICTA_CLOUD["nakdan"], json=payload, timeout=30)
    r.raise_for_status()
    body = r.json()
    if isinstance(body, dict) and "data" in body:
        # פורמט נפוץ של דיקטה - מערך של {word, options[]}
        out = []
        for item in body["data"]:
            options = item.get("options") or []
            chosen = options[0] if options else item.get("word", "")
            if isinstance(chosen, dict):
                chosen = chosen.get("w") or chosen.get("word") or ""
            out.append(chosen + item.get("sep", ""))
        return "".join(out)
    return text
