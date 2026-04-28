"""נקודת הכניסה - שרת FastAPI.

הפעלה:
    python -m dicta_service.main
או:
    uvicorn dicta_service.main:app --host 127.0.0.1 --port 7821

משתני סביבה רלוונטיים:
    OTZARIA_AI_PROFILE = low | standard | high
    OTZARIA_AI_PORT    = 7821 (ברירת מחדל)
    OTZARIA_AI_CLOUD   = 1/0  (לאפשר fallback לדיקטה בענן)
"""
from __future__ import annotations
import logging
import time
from contextlib import asynccontextmanager
from typing import Optional

import numpy as np
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from . import __version__
from .config import CFG, HOST, PORT, PROFILE, ALLOW_CLOUD
from .registry import REGISTRY
from .loaders import register_all
from .tools import embed as embed_tool
from .tools import morph as morph_tool
from .tools import ner as ner_tool
from .tools import qa as qa_tool
from .tools import citation as citation_tool
from .tools import nakdan as nakdan_tool
from .tools import translate as translate_tool

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
log = logging.getLogger("main")


@asynccontextmanager
async def lifespan(app: FastAPI):
    log.info("starting otzaria-ai v%s, profile=%s", __version__, PROFILE)
    register_all(REGISTRY)
    REGISTRY.start_janitor()
    yield
    log.info("shutting down")
    REGISTRY.shutdown()


app = FastAPI(
    title="Otzaria AI",
    version=__version__,
    description="Dicta NLP tools sidecar for Otzaria",
    lifespan=lifespan,
)

# סביבה מקומית בלבד - אין צורך לחסום, אבל נגדיר ברורות
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)


# ──────────────────────────── Models ────────────────────────────


class Health(BaseModel):
    status: str
    version: str
    profile: str
    cloud_enabled: bool
    loaded_models: list[dict]


class TextIn(BaseModel):
    text: str


class TextsIn(BaseModel):
    texts: list[str] = Field(..., min_length=1)


class EmbedOut(BaseModel):
    dim: int
    vectors: list[list[float]]
    elapsed_ms: int


class SemanticSearchIn(BaseModel):
    query: str
    corpus: list[str] = Field(..., min_length=1)
    top_k: int = Field(default=10, ge=1, le=100)


class SemanticSearchHit(BaseModel):
    index: int
    score: float
    text: str


class ExpandQueryIn(BaseModel):
    word: str


class QAIn(BaseModel):
    question: str
    context: str


class CitationIn(BaseModel):
    text: str
    top_k: int = 5


class NakdanIn(BaseModel):
    text: str
    genre: str = "modern"


class TranslateIn(BaseModel):
    text: str
    source: str = "he"
    target: str = "en"


# ──────────────────────────── Endpoints ────────────────────────────


@app.get("/health", response_model=Health)
def health():
    return Health(
        status="ok",
        version=__version__,
        profile=PROFILE,
        cloud_enabled=ALLOW_CLOUD,
        loaded_models=REGISTRY.loaded_models(),
    )


@app.post("/embed", response_model=EmbedOut)
def embed_endpoint(payload: TextsIn):
    t0 = time.time()
    vecs = embed_tool.embed_texts(payload.texts)
    return EmbedOut(
        dim=int(vecs.shape[1]) if vecs.size else 0,
        vectors=vecs.tolist(),
        elapsed_ms=int((time.time() - t0) * 1000),
    )


@app.post("/semantic_search")
def semantic_search(payload: SemanticSearchIn):
    """חיפוש סמנטי one-shot - מחשב embeddings לקורפוס + שאילתה ומחזיר top-k.

    שימושי ל-prototype, אבל לא יעיל לשימוש חוזר. ייצור אמיתי - שמור את
    הוקטורים מצד הלקוח (Isar) וקרא ל-/embed פעם אחת."""
    t0 = time.time()
    qv = embed_tool.embed_texts([payload.query])[0]
    cv = embed_tool.embed_texts(payload.corpus)
    matches = embed_tool.cosine_topk(qv, cv, k=payload.top_k)
    hits = [
        SemanticSearchHit(index=i, score=s, text=payload.corpus[i]).model_dump()
        for i, s in matches
    ]
    return {"hits": hits, "elapsed_ms": int((time.time() - t0) * 1000)}


@app.post("/morph/analyze")
def morph_analyze(payload: TextsIn):
    return {"results": morph_tool.analyze(payload.texts)}


@app.post("/morph/lemmas")
def morph_lemmas(payload: TextIn):
    return {"lemmas": morph_tool.lemmas(payload.text)}


@app.post("/morph/expand")
def morph_expand(payload: ExpandQueryIn):
    """מקבל מילה ומחזיר את כל הוריאציות שלה לחיפוש regex.
    שימושי ישירות מ-Otzaria search bar - מעטף לשאילתה."""
    variants = morph_tool.expand_query_term(payload.word)
    return {"word": payload.word, "variants": list(variants)}


@app.post("/ner")
def ner_endpoint(payload: TextsIn):
    return {"results": ner_tool.extract_entities(payload.texts)}


@app.post("/qa")
def qa_endpoint(payload: QAIn):
    if CFG["qa_model"] is None:
        raise HTTPException(
            status_code=501,
            detail="QA model not loaded in current profile. Use Dicta Cloud or upgrade profile=high.",
        )
    return qa_tool.answer(payload.question, payload.context)


@app.post("/citations/find")
def citations_find(payload: CitationIn):
    """מחזיר רשימת ציטוטים מקראיים שזוהו בטקסט."""
    hits = citation_tool.find_citations(payload.text, top_k=payload.top_k)
    return {"hits": hits}


@app.post("/citations/classify")
def citations_classify(payload: TextIn):
    """משתמש ב-MsBERT (אם זמין) להבחין בין 'דברי המחבר' ל'ציטוט'."""
    out = citation_tool.msbert_classify_segments(payload.text)
    if out is None:
        raise HTTPException(
            status_code=501, detail="MsBERT not loaded. Requires profile=high."
        )
    return {"segments": out}


@app.post("/nakdan")
def nakdan_endpoint(payload: NakdanIn):
    try:
        return {"vocalized": nakdan_tool.vocalize(payload.text, genre=payload.genre)}
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))


@app.post("/translate")
def translate_endpoint(payload: TranslateIn):
    try:
        return {
            "translation": translate_tool.translate(
                payload.text, source=payload.source, target=payload.target
            )
        }
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))


def main():
    import uvicorn

    uvicorn.run(
        "dicta_service.main:app",
        host=HOST,
        port=PORT,
        log_level="info",
        reload=False,
        workers=1,
    )


if __name__ == "__main__":
    main()
