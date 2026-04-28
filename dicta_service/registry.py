"""מנהל מודלים - טעינה עצלה + פריקה אוטומטית.

המטרה: על i3 עם RAM מוגבל לא לטעון מודל לפני שצריך אותו, ולפרוק
מודלים שלא בשימוש כדי לפנות זיכרון. שום מקום אחר בקוד לא טוען מודל
ישירות - הכל עובר דרך הרישום הזה.
"""
from __future__ import annotations
import gc
import logging
import threading
import time
from typing import Any, Callable

import torch

from .config import CFG

log = logging.getLogger("registry")


class ModelHandle:
    __slots__ = ("name", "obj", "loaded_at", "last_used", "size_mb")

    def __init__(self, name: str, obj: Any, size_mb: float):
        self.name = name
        self.obj = obj
        self.loaded_at = time.time()
        self.last_used = time.time()
        self.size_mb = size_mb


class ModelRegistry:
    """singleton לכל המודלים שטעונים בתהליך."""

    def __init__(self):
        self._models: dict[str, ModelHandle] = {}
        self._loaders: dict[str, Callable[[], tuple[Any, float]]] = {}
        self._lock = threading.RLock()
        self._stop_janitor = threading.Event()
        torch.set_num_threads(CFG["torch_threads"])

    def register_loader(self, name: str, loader: Callable[[], tuple[Any, float]]) -> None:
        """הרשמת פונקציית loader. הפונקציה מחזירה (model, ~size_in_mb)."""
        self._loaders[name] = loader

    def get(self, name: str) -> Any:
        with self._lock:
            handle = self._models.get(name)
            if handle is not None:
                handle.last_used = time.time()
                return handle.obj

            if name not in self._loaders:
                raise KeyError(f"no loader registered for model '{name}'")

            self._evict_if_needed()
            log.info("loading model %s ...", name)
            t0 = time.time()
            obj, size = self._loaders[name]()
            log.info("loaded %s in %.1fs (~%.0f MB)", name, time.time() - t0, size)
            self._models[name] = ModelHandle(name, obj, size)
            return obj

    def _evict_if_needed(self) -> None:
        max_loaded = CFG["max_loaded_models"]
        while len(self._models) >= max_loaded:
            oldest = min(self._models.values(), key=lambda h: h.last_used)
            log.info("evicting %s (idle %ds)", oldest.name, int(time.time() - oldest.last_used))
            self._unload(oldest.name)

    def _unload(self, name: str) -> None:
        h = self._models.pop(name, None)
        if h is None:
            return
        del h.obj
        gc.collect()
        if torch.cuda.is_available():
            torch.cuda.empty_cache()

    def loaded_models(self) -> list[dict]:
        with self._lock:
            return [
                {
                    "name": h.name,
                    "size_mb": round(h.size_mb, 1),
                    "loaded_seconds_ago": int(time.time() - h.loaded_at),
                    "idle_seconds": int(time.time() - h.last_used),
                }
                for h in self._models.values()
            ]

    def start_janitor(self) -> None:
        """thread רקע שפורק מודלים שלא היה בהם שימוש."""
        def loop():
            timeout = CFG["idle_timeout_s"]
            while not self._stop_janitor.wait(60):
                with self._lock:
                    now = time.time()
                    stale = [n for n, h in self._models.items() if now - h.last_used > timeout]
                    for n in stale:
                        log.info("janitor evicting idle model %s", n)
                        self._unload(n)

        t = threading.Thread(target=loop, daemon=True, name="model-janitor")
        t.start()

    def shutdown(self) -> None:
        self._stop_janitor.set()
        with self._lock:
            for name in list(self._models):
                self._unload(name)


REGISTRY = ModelRegistry()
