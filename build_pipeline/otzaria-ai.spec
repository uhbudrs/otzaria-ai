# -*- mode: python ; coding: utf-8 -*-
"""PyInstaller spec ל-sidecar.

הספק הזה מוקפד יותר מ-CLI של PyInstaller:
- כולל את הקבצים של trust_remote_code (קבצי .py של dicta-il)
- מוציא חבילות שלא צריך (CUDA, sympy, scipy.io, וכו') - חוסך 600MB
- bundles את הכל בתיקייה (`onedir`) - אנטי-וירוס לא חוסם זה
- שם הפלט: dist/otzaria-ai/otzaria-ai.exe

הרצה:
    pyinstaller otzaria-ai.spec --noconfirm --clean
"""
from PyInstaller.utils.hooks import (
    collect_all,
    collect_data_files,
    collect_submodules,
)

# transformers + tokenizers - חובה כל הקבצים, יש המון
tr_d, tr_b, tr_h = collect_all("transformers")
tk_d, tk_b, tk_h = collect_all("tokenizers")
hf_d, hf_b, hf_h = collect_all("huggingface_hub")
# torch CPU - לא הכל, רק את הליבה
to_d = collect_data_files("torch", excludes=["**/test/**", "**/_export/**"])

# חבילות שלא נדרשות - לחסוך נפח
EXCLUDES = [
    "matplotlib",
    "PIL",
    "PyQt5", "PyQt6",
    "tkinter",
    "IPython",
    "jupyter",
    "notebook",
    "pandas",
    "scipy",
    "sklearn",
    "torch.distributed",
    "torch.utils.tensorboard",
    "tensorboard",
    "torchvision",
    "torchaudio",
    "cv2",
]

a = Analysis(
    ["..\\dicta_service\\main.py"],
    pathex=[".."],
    binaries=tr_b + tk_b + hf_b,
    datas=tr_d + tk_d + hf_d + to_d,
    hiddenimports=[
        "uvicorn.logging",
        "uvicorn.loops",
        "uvicorn.loops.auto",
        "uvicorn.loops.asyncio",
        "uvicorn.protocols",
        "uvicorn.protocols.http",
        "uvicorn.protocols.http.auto",
        "uvicorn.protocols.http.h11_impl",
        "uvicorn.protocols.websockets",
        "uvicorn.protocols.websockets.auto",
        "uvicorn.lifespan",
        "uvicorn.lifespan.on",
        "uvicorn.lifespan.off",
        "uvicorn.middleware",
        "uvicorn.middleware.proxy_headers",
        "anyio._backends._asyncio",
    ] + collect_submodules("dicta_service"),
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=EXCLUDES,
    noarchive=False,
    optimize=2,
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name="otzaria-ai",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,  # UPX לפעמים מתעמת עם Defender
    console=False,  # רץ ברקע, אין שורת פקודה לוצצת
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=None,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=False,
    upx_exclude=[],
    name="otzaria-ai",
)
