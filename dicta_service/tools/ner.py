"""זיהוי שמות (NER) - אישים, מקומות, תאריכים, יצירות."""
from __future__ import annotations
import torch

from dicta_service.registry import REGISTRY


@torch.inference_mode()
def extract_entities(sentences: list[str]) -> list[list[dict]]:
    """לכל משפט מוחזרת רשימה של {text, label, start, end}."""
    bundle = REGISTRY.get("ner")
    model = bundle["model"]
    tok = bundle["tokenizer"]
    raw = model.predict(sentences, tok, output_style="json")
    out: list[list[dict]] = []
    for item in raw:
        ents = []
        for ent in item.get("ner_entities", []) or item.get("entities", []) or []:
            ents.append(
                {
                    "text": ent.get("phrase") or ent.get("text"),
                    "label": ent.get("label") or ent.get("type"),
                    "start": ent.get("start"),
                    "end": ent.get("end"),
                }
            )
        out.append(ents)
    return out
