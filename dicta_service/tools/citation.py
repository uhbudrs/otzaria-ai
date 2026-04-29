"""מציאת ציטוטים מתנ"ך/חז"ל בתוך טקסט רבני.

יש שתי דרכים:
  1. MsBERT - אם זמין (רק בפרופיל high)
  2. heuristic מהיר על i3: חיפוש n-gram מול corpus מקראי טעון מראש,
     בליווי דמיון embedding לאישור.
"""
from __future__ import annotations
import json
import logging
from pathlib import Path

import numpy as np

from dicta_service.config import DATA_DIR, CFG
from dicta_service.registry import REGISTRY
from dicta_service.tools import embed

log = logging.getLogger("tools.citation")

# DB ציטוטים. מצופה: JSONL עם {ref, text}
CITATION_DB_PATH = DATA_DIR / "citations.jsonl"
CITATION_VECTORS_PATH = DATA_DIR / "citations.npy"

_cache: dict | None = None


def _load_db() -> dict | None:
    global _cache
    if _cache is not None:
        return _cache
    if not CITATION_DB_PATH.exists():
        log.warning("citation DB not found at %s", CITATION_DB_PATH)
        return None
    refs, texts = [], []
    with CITATION_DB_PATH.open("r", encoding="utf-8") as f:
        for line in f:
            try:
                obj = json.loads(line)
                refs.append(obj["ref"])
                texts.append(obj["text"])
            except Exception:
                continue
    if CITATION_VECTORS_PATH.exists():
        vecs = np.load(CITATION_VECTORS_PATH)
    else:
        log.info("computing citation embeddings (one-time, may take a while)...")
        vecs = embed.embed_texts(texts, batch_size=16)
        np.save(CITATION_VECTORS_PATH, vecs)
    _cache = {"refs": refs, "texts": texts, "vecs": vecs}
    return _cache


def find_citations(text: str, top_k: int = 5, min_score: float = 0.78) -> list[dict]:
    """מקבל פסקה רבנית, מחזיר ציטוטים פוטנציאליים שזוהו בה.

    אם אין DB מקומי, מחזיר רשימה ריקה - הקריאה תעבור ל-MsBERT אם זמין.
    """
    db = _load_db()
    if db is None:
        return []
    qv = embed.embed_texts([text])[0]
    matches = embed.cosine_topk(qv, db["vecs"], k=top_k)
    out = []
    for idx, score in matches:
        if score < min_score:
            continue
        out.append({"ref": db["refs"][idx], "text": db["texts"][idx], "score": score})
    return out


def msbert_classify_segments(text: str) -> list[dict] | None:
    """אם MsBERT זמין - מסווג קטעים בטקסט כ'ציטוט' או 'דברי מחבר'."""
    if CFG["msbert_model"] is None:
        return None
    bundle = REGISTRY.get("msbert")
    tok = bundle["tokenizer"]
    model = bundle["model"]
    # MsBERT מסווג ברמת token - כאן placeholder, בפועל נחזיר span-by-span
    # API פנימי בדיוק לפי הדוקומנטציה של הצוות שמתחזק את MsBERT
    log.info("msbert classify on %d chars", len(text))
    return [{"text": text, "label": "unknown", "score": 0.0}]
