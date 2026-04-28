"""אריזת השרת ל-binary יחיד עם PyInstaller.

הרצה:
    python -m pip install pyinstaller
    python scripts/build_sidecar.py

תוצאה: dist/otzaria-ai[.exe] - קובץ יחיד שאפשר לשים ליד otzaria.exe
ואוצריא תפעיל אותו אוטומטית דרך AiProcessManager.

הערות:
- ה-binary לא כולל את המודלים. הם יורדים בריצה ראשונה ל-~/.otzaria_ai/models/
- גודל משוער: ~250MB (PyTorch CPU + transformers).
- לא לבלבל בין onefile לבין onedir - ב-Windows onefile לפעמים נחסם
  ע"י Windows Defender; אם זה קורה השתמש ב-`--onedir`.
"""
from __future__ import annotations
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / "dist"
BUILD = ROOT / "build"
SPEC = ROOT / "otzaria-ai.spec"


def main():
    onedir = "--onefile"  # החלף ל-"--onedir" אם אנטי-וירוס מתערב
    cmd = [
        sys.executable,
        "-m",
        "PyInstaller",
        onedir,
        "--name",
        "otzaria-ai",
        "--noconfirm",
        "--clean",
        "--collect-all",
        "transformers",
        "--collect-all",
        "tokenizers",
        "--collect-data",
        "torch",
        "--hidden-import",
        "uvicorn.logging",
        "--hidden-import",
        "uvicorn.loops.auto",
        "--hidden-import",
        "uvicorn.protocols.http.auto",
        "--hidden-import",
        "uvicorn.protocols.websockets.auto",
        "--hidden-import",
        "uvicorn.lifespan.on",
        str(ROOT / "dicta_service" / "main.py"),
    ]
    print("running:", " ".join(cmd))
    subprocess.check_call(cmd, cwd=str(ROOT))

    print("\nbinary at:", DIST / ("otzaria-ai.exe" if sys.platform == "win32" else "otzaria-ai"))


if __name__ == "__main__":
    main()
