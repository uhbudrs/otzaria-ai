"""ניתוח מורפולוגי + הרחבה לפי שורש.

המודל joint מוציא JSON עם token, lemma, prefix, morph, syntax, ner.
אנחנו עוטפים את זה בממשק נוח, ומוסיפים פונקציה שמחלצת את כל
הצורות האפשריות לפי שורש (לחיפוש מורחב באוצריא).
"""
from __future__ import annotations
import logging
from functools import lru_cache
from typing import Any

import torch

from dicta_service.registry import REGISTRY

log = logging.getLogger("tools.morph")


@torch.inference_mode()
def analyze(sentences: list[str]) -> list[dict]:
    """מחזיר את ניתוח dictabert-joint עבור כל משפט (פורמט json)."""
    bundle = REGISTRY.get("joint")
    model = bundle["model"]
    tok = bundle["tokenizer"]
    return model.predict(sentences, tok, output_style="json")


def lemmas(sentence: str) -> list[str]:
    out = analyze([sentence])
    if not out:
        return []
    tokens = out[0].get("tokens", [])
    return [t.get("lex") or t.get("lemma") or t["token"] for t in tokens]


# קצת נטיות נפוצות שאנחנו יודעים להוסיף ידנית למילה - מהיר מ-MLM
HEBREW_PREFIXES = ["", "ה", "ו", "וה", "ב", "כ", "ל", "מ", "ש", "שה", "ול", "מה", "כש"]


@lru_cache(maxsize=4096)
def expand_query_term(word: str) -> tuple[str, ...]:
    """מקבל מילה ומחזיר את כל הוריאציות שלה לחיפוש regex.

    הרעיון: שורש זהה + תחיליות נפוצות. זה מורחב יותר מהוריאציות
    הסטטיות שכבר יש באוצריא. אם רוצים להיות מדויקים יותר, אפשר
    לקרוא ל-MLM להשלמה - אבל זה יקר על i3.
    """
    out: set[str] = {word}

    try:
        ana = analyze([word])
        if ana:
            tokens = ana[0].get("tokens", [])
            for t in tokens:
                lemma = t.get("lex") or t.get("lemma")
                if lemma and lemma != word:
                    out.add(lemma)
    except Exception as e:
        log.warning("morph analyze failed for %r: %s", word, e)

    base_set = list(out)
    for base in base_set:
        for p in HEBREW_PREFIXES:
            out.add(p + base)
    return tuple(sorted(out))
