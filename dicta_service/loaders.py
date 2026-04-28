"""פונקציות טעינה לכל מודל. כל פונקציה מחזירה (object, size_mb).

ההפרדה הזו מאפשרת לדחות את ה-import הכבד של transformers/torch לעד
שבאמת מבקשים את המודל הראשון - מקצרת את זמן ה-startup של ה-API."""
from __future__ import annotations
import logging
import os
from pathlib import Path

from .config import CFG, MODELS_DIR

log = logging.getLogger("loaders")
os.environ.setdefault("HF_HOME", str(MODELS_DIR))
os.environ.setdefault("TRANSFORMERS_CACHE", str(MODELS_DIR))


def _size_of_model(model) -> float:
    total = 0
    for p in model.parameters():
        total += p.numel() * p.element_size()
    return total / (1024 * 1024)


def _load_hf_with_trust(name: str):
    from transformers import AutoModel, AutoTokenizer
    tok = AutoTokenizer.from_pretrained(name)
    model = AutoModel.from_pretrained(name, trust_remote_code=True)
    model.eval()
    return tok, model


def load_embedding():
    """מודל בסיסי לחישוב vector embeddings."""
    name = CFG["embed_model"]
    from transformers import AutoModel, AutoTokenizer
    tok = AutoTokenizer.from_pretrained(name)
    model = AutoModel.from_pretrained(name)
    model.eval()
    return ({"tokenizer": tok, "model": model, "name": name}, _size_of_model(model))


def load_joint():
    """dictabert-joint - 5 משימות (prefix/morph/lemma/syntax/NER) במודל אחד."""
    name = CFG["morph_model"]
    tok, model = _load_hf_with_trust(name)
    return ({"tokenizer": tok, "model": model, "name": name}, _size_of_model(model))


def load_ner():
    """אם ner_model זהה ל-joint, נשתמש שוב באותו handle."""
    name = CFG["ner_model"]
    if name == CFG["morph_model"]:
        return load_joint()
    tok, model = _load_hf_with_trust(name)
    return ({"tokenizer": tok, "model": model, "name": name}, _size_of_model(model))


def load_qa():
    name = CFG["qa_model"]
    if name is None:
        raise RuntimeError("qa_model not configured for current profile")
    from transformers import AutoModelForQuestionAnswering, AutoTokenizer
    tok = AutoTokenizer.from_pretrained(name)
    model = AutoModelForQuestionAnswering.from_pretrained(name)
    model.eval()
    return ({"tokenizer": tok, "model": model, "name": name}, _size_of_model(model))


def load_msbert():
    """MsBERT - מיוחד לטקסטים רבניים."""
    name = CFG["msbert_model"]
    if name is None:
        raise RuntimeError("msbert_model not configured for current profile")
    from transformers import AutoModel, AutoTokenizer
    tok = AutoTokenizer.from_pretrained(name)
    model = AutoModel.from_pretrained(name, trust_remote_code=True)
    model.eval()
    return ({"tokenizer": tok, "model": model, "name": name}, _size_of_model(model))


def register_all(registry):
    registry.register_loader("embedding", load_embedding)
    registry.register_loader("joint", load_joint)
    registry.register_loader("ner", load_ner)
    if CFG["qa_model"]:
        registry.register_loader("qa", load_qa)
    if CFG["msbert_model"]:
        registry.register_loader("msbert", load_msbert)
