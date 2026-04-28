"""הגדרות מרכזיות לשרת.

כל הקבועים נמצאים כאן כדי שיהיה קל לכוון למחשב חלש/חזק.
"""
from __future__ import annotations
import os
from pathlib import Path

HOST = os.environ.get("OTZARIA_AI_HOST", "127.0.0.1")
PORT = int(os.environ.get("OTZARIA_AI_PORT", "7821"))

DATA_DIR = Path(os.environ.get("OTZARIA_AI_DATA", Path.home() / ".otzaria_ai"))
MODELS_DIR = DATA_DIR / "models"
CACHE_DIR = DATA_DIR / "cache"
DATA_DIR.mkdir(parents=True, exist_ok=True)
MODELS_DIR.mkdir(parents=True, exist_ok=True)
CACHE_DIR.mkdir(parents=True, exist_ok=True)

# פרופיל ביצועים. ניתן לעקוף ב-env: OTZARIA_AI_PROFILE=low|standard|high
PROFILE = os.environ.get("OTZARIA_AI_PROFILE", "standard").lower()

# טווח מודלים לכל פרופיל - מה נטען מקומית מול מה הולך לענן
PROFILES: dict[str, dict] = {
    # i3 ישן עם 4GB RAM. הכל קטן, או ענן.
    "low": {
        "embed_model": "dicta-il/dictabert-tiny",
        "morph_model": "dicta-il/dictabert-tiny-joint",
        "ner_model": "dicta-il/dictabert-tiny-joint",  # joint עושה גם NER
        "qa_model": None,  # רק ענן
        "msbert_model": None,
        "nakdan_model": None,
        "translate_model": None,
        "max_loaded_models": 1,
        "idle_timeout_s": 300,
        "torch_threads": 2,
    },
    # i3 דור 8+ עם 8GB RAM, או i5
    "standard": {
        "embed_model": "dicta-il/dictabert-tiny",
        "morph_model": "dicta-il/dictabert-tiny-joint",
        "ner_model": "dicta-il/dictabert-tiny-joint",
        "qa_model": None,
        "msbert_model": None,
        "nakdan_model": None,
        "translate_model": None,
        "max_loaded_models": 2,
        "idle_timeout_s": 600,
        "torch_threads": 4,
    },
    # i7 עם 16GB+ RAM. אפשר לטעון הכל
    "high": {
        "embed_model": "dicta-il/dictabert",
        "morph_model": "dicta-il/dictabert-joint",
        "ner_model": "dicta-il/dictabert-ner",
        "qa_model": "dicta-il/dictabert-heq",
        "msbert_model": "dicta-il/MsBERT",
        "nakdan_model": "dicta-il/dictabert",  # placeholder
        "translate_model": None,  # תרגום עדיין רץ בענן
        "max_loaded_models": 4,
        "idle_timeout_s": 1800,
        "torch_threads": 6,
    },
}

CFG = PROFILES.get(PROFILE, PROFILES["standard"])

# כתובות API של דיקטה לשירותי ענן (כשמודל לא טעון מקומית)
DICTA_CLOUD = {
    "nakdan": "https://nakdan-5-0.loadbalancer.dicta.org.il/api",
    "translate": "https://translate.loadbalancer.dicta.org.il/api/translate",
    "morph": "https://nakdan-5-0.loadbalancer.dicta.org.il/api",
    # ניתן להרחיב כשנמצאים endpoints מדויקים
}

ALLOW_CLOUD = os.environ.get("OTZARIA_AI_CLOUD", "1") == "1"
