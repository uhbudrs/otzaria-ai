"""smoke test של ה-API ללא torch.
מאפשר לבדוק את ה-FastAPI עצמו בלי להוריד 2GB של PyTorch."""
from __future__ import annotations
import logging
import sys

logging.basicConfig(level=logging.INFO)

# stub torch לפני שמשהו אחר מייבא
import types
torch_stub = types.ModuleType("torch")
torch_stub.set_num_threads = lambda n: None
torch_stub.cuda = types.SimpleNamespace(
    is_available=lambda: False, empty_cache=lambda: None
)
torch_stub.inference_mode = lambda: (lambda f: f)
torch_stub.nn = types.SimpleNamespace(
    functional=types.SimpleNamespace(normalize=lambda *a, **kw: None)
)
sys.modules["torch"] = torch_stub

from dicta_service import __version__  # noqa: E402
from dicta_service.config import HOST, PORT, PROFILE, ALLOW_CLOUD  # noqa: E402

from fastapi import FastAPI  # noqa: E402

app = FastAPI(title="Otzaria AI smoke", version=__version__)


@app.get("/health")
def health():
    return {
        "status": "smoke-ok",
        "version": __version__,
        "profile": PROFILE,
        "cloud_enabled": ALLOW_CLOUD,
        "loaded_models": [],
    }


def main():
    import uvicorn
    uvicorn.run(app, host=HOST, port=PORT, log_level="info")


if __name__ == "__main__":
    main()
