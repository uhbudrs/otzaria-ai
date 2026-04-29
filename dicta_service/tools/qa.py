"""שאלות ותשובות באמצעות dictabert-heq.

על i3 פרופיל low/standard המודל הזה לא נטען - הקריאה תעבור לענן.
"""
from __future__ import annotations
import torch

from dicta_service.config import CFG
from dicta_service.registry import REGISTRY


@torch.inference_mode()
def answer(question: str, context: str) -> dict:
    if CFG["qa_model"] is None:
        raise RuntimeError("QA model not enabled in current profile - use cloud fallback")
    bundle = REGISTRY.get("qa")
    tok = bundle["tokenizer"]
    model = bundle["model"]

    enc = tok(question, context, truncation="only_second", max_length=512, return_tensors="pt")
    out = model(**enc)
    start_logits = out.start_logits[0]
    end_logits = out.end_logits[0]
    start = int(torch.argmax(start_logits))
    end = int(torch.argmax(end_logits))
    if end < start:
        start, end = end, start
    tokens = enc["input_ids"][0][start : end + 1]
    answer_text = tok.decode(tokens, skip_special_tokens=True).strip()
    score = float(torch.softmax(start_logits, -1).max() * torch.softmax(end_logits, -1).max())
    return {"answer": answer_text, "score": score, "start": start, "end": end}
