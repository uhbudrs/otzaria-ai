# -*- mode: python ; coding: utf-8 -*-
"""PyInstaller spec ל-sidecar - גרסה ממוטבת.

המוטיבציה: collect_all('transformers') מעתיק 1.5GB+ של קבצים מיותרים.
פותר ע"י:
  - collect_data רק לקבצי tokenizer/model templates של transformers
  - hidden imports סלקטיביים (רק מה ש-DictaBERT צריך)
  - excludes אגרסיביים: tensorflow, jax, flax, sklearn וכו'
  - onedir במקום onefile - מהיר פי 3-5 ולא נחסם ע"י Defender

הזמן הצפוי בריצה: 4-6 דק' במקום 20.
"""
from PyInstaller.utils.hooks import (
    collect_data_files,
    collect_dynamic_libs,
    collect_submodules,
)

# transformers - רק קבצי data חיוניים, בלי כל ה-modeling files של מאות מודלים
tr_data = collect_data_files(
    "transformers",
    excludes=[
        "**/*.md",
        "**/test/**",
        "**/tests/**",
        "**/onnx/**",
        "**/utils/dummy_*",  # placeholder modules
    ],
)

# tokenizers - חבילה קטנה, צריכים את ה-Rust binaries
tk_bins = collect_dynamic_libs("tokenizers")
tk_data = collect_data_files("tokenizers")

# huggingface_hub
hf_data = collect_data_files("huggingface_hub")

# torch - DLLs חיוניים בלבד
torch_bins = collect_dynamic_libs("torch")
torch_data = collect_data_files(
    "torch",
    excludes=[
        "**/test/**",
        "**/tests/**",
        "**/_export/**",
        "**/distributions/**",
        "**/onnx/**",
        "**/_torch_docs.py",
        "**/profiler/**",
    ],
)

# חבילות שלא נדרשות
EXCLUDES = [
    # ML frameworks אחרים
    "tensorflow", "tensorflow_cpu", "tensorflow_gpu",
    "jax", "jaxlib", "flax",
    "sklearn", "scikit-learn",
    "pandas", "scipy",
    # GPU support - excludes חכמים:
    # - לא להחריג torch.cuda ולא torch.distributed (ליבה - קריטי לimport)
    # - אפשר להחריג submodules שלא בשימוש ע"י תפיסה ספציפית
    "torchvision", "torchaudio",
    # excludes ספציפיים שלא נטעמים אוטומטית עם torch:
    "torch.distributed.fsdp",
    "torch.distributed.tensor",
    "torch.distributed.checkpoint",
    "torch.distributed.elastic",
    "torch.distributed.pipelining",
    "torch.distributed.rpc",
    "torch.testing._internal",
    "torch._inductor",
    "torch._dynamo",
    "torch.utils.tensorboard",
    "torch.utils.bottleneck",
    "torch.profiler",
    "torch.jit._state",
    "torch.onnx",
    "torch.fx",
    "torch.export",
    "torch.compiler",
    "torch.distributions",  # 100+ classes שלא בשימוש
    # UI
    "matplotlib", "PIL", "PyQt5", "PyQt6", "PySide2", "PySide6",
    "tkinter", "_tkinter",
    # Notebooks
    "IPython", "jupyter", "notebook", "jupyterlab",
    # Vision
    "cv2", "opencv-python",
    # Less-used transformers tasks
    "transformers.models.musicgen",
    "transformers.models.wav2vec2",
    "transformers.models.whisper",
    "transformers.models.speech_to_text",
    "transformers.models.clap",
    "transformers.models.clip",
    "transformers.models.blip",
    "transformers.models.vit",
    "transformers.models.detr",
    "transformers.models.t5",
    "transformers.models.bart",
    "transformers.models.gpt2",
    "transformers.models.llama",
    "transformers.models.mistral",
    # Tests
    "pytest", "unittest",
]

# רק ה-models של transformers שאנחנו צריכים בפועל
HIDDEN_IMPORTS = [
    # uvicorn internals
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
    # anyio backends
    "anyio._backends._asyncio",
    # transformers - רק BERT (מה ש-DictaBERT משתמש)
    "transformers.models.bert",
    "transformers.models.bert.modeling_bert",
    "transformers.models.bert.tokenization_bert",
    "transformers.models.bert.tokenization_bert_fast",
    "transformers.models.bert.configuration_bert",
    "transformers.models.auto",
    "transformers.models.auto.modeling_auto",
    "transformers.models.auto.tokenization_auto",
    "transformers.models.auto.configuration_auto",
    # Common transformer utils
    "transformers.modeling_utils",
    "transformers.tokenization_utils",
    "transformers.tokenization_utils_base",
    "transformers.tokenization_utils_fast",
    "transformers.configuration_utils",
    "transformers.feature_extraction_utils",
    # שלנו
] + collect_submodules("dicta_service")


a = Analysis(
    ["..\\dicta_service\\main.py"],
    pathex=[".."],
    binaries=tk_bins + torch_bins,
    datas=tr_data + tk_data + hf_data + torch_data,
    hiddenimports=HIDDEN_IMPORTS,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=EXCLUDES,
    noarchive=False,
    # optimize=0 חובה - numpy.add_docstring נופל אם docstrings מוסרים
    optimize=0,
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
    upx=False,
    console=False,
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
