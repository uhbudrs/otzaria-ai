"""מוריד את מודלי דיקטה לפי הפרופיל לפני הפעלה ראשונה.

הרצה:
    python scripts/download_models.py            # ברירת מחדל: standard
    python scripts/download_models.py --profile low
    python scripts/download_models.py --profile high

הסיבה לרוץ את זה לפני: ההורדה הראשונית של HuggingFace יכולה לקחת
דקות-עשרות-דקות תלוי במהירות אינטרנט. עדיף לעשות זאת פעם אחת בנוחות
ולא להפתיע משתמש שמחכה לחיפוש הראשון שלו.
"""
from __future__ import annotations
import argparse
import os
import sys
from pathlib import Path

# אפשר להריץ את הסקריפט בלי להתקין את ה-package
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from dicta_service.config import PROFILES, MODELS_DIR  # noqa: E402

os.environ.setdefault("HF_HOME", str(MODELS_DIR))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--profile", choices=list(PROFILES), default="standard")
    args = ap.parse_args()

    cfg = PROFILES[args.profile]
    targets = []
    for key in ("embed_model", "morph_model", "ner_model", "qa_model", "msbert_model"):
        name = cfg.get(key)
        if name and name not in targets:
            targets.append(name)

    if not targets:
        print("nothing to download for this profile.")
        return

    from huggingface_hub import snapshot_download

    print(f"target dir: {MODELS_DIR}")
    for name in targets:
        print(f"\n→ {name}")
        snapshot_download(repo_id=name, cache_dir=str(MODELS_DIR))
        print(f"  ✓ {name}")

    print("\nאל הצלחה. עכשיו אפשר להפעיל את השרת.")


if __name__ == "__main__":
    main()
