"""חישוב embeddings + חיפוש סמנטי.

ה-embedding נעשה ע"י mean-pooling של hidden states - שיטה סטנדרטית
שעובדת היטב על BERT עברי. הוקטור ב-768 ממדים (384 ב-tiny).
"""
from __future__ import annotations
import logging
from typing import Iterable

import numpy as np
import torch

from dicta_service.registry import REGISTRY

log = logging.getLogger("tools.embed")


def _mean_pool(last_hidden_state: torch.Tensor, attention_mask: torch.Tensor) -> torch.Tensor:
    mask = attention_mask.unsqueeze(-1).float()
    summed = (last_hidden_state * mask).sum(dim=1)
    counts = mask.sum(dim=1).clamp(min=1e-9)
    return summed / counts


@torch.inference_mode()
def embed_texts(texts: list[str], batch_size: int = 8, normalize: bool = True) -> np.ndarray:
    """מחזיר מטריצה (N, D) של embeddings."""
    if not texts:
        return np.zeros((0, 0), dtype=np.float32)

    bundle = REGISTRY.get("embedding")
    tok = bundle["tokenizer"]
    model = bundle["model"]

    out_chunks: list[np.ndarray] = []
    for start in range(0, len(texts), batch_size):
        chunk = texts[start : start + batch_size]
        enc = tok(chunk, padding=True, truncation=True, max_length=256, return_tensors="pt")
        out = model(**enc)
        pooled = _mean_pool(out.last_hidden_state, enc["attention_mask"])
        if normalize:
            pooled = torch.nn.functional.normalize(pooled, p=2, dim=1)
        out_chunks.append(pooled.cpu().numpy().astype(np.float32))
    return np.concatenate(out_chunks, axis=0)


def cosine_topk(query_vec: np.ndarray, corpus: np.ndarray, k: int = 10) -> list[tuple[int, float]]:
    """top-k דמיון cosine. מניח שכל הוקטורים כבר מנורמלים L2."""
    if corpus.size == 0:
        return []
    scores = corpus @ query_vec
    if k >= len(scores):
        idx = np.argsort(-scores)
    else:
        idx = np.argpartition(-scores, k)[:k]
        idx = idx[np.argsort(-scores[idx])]
    return [(int(i), float(scores[i])) for i in idx]
