"""Load text from selected science PDFs under knowledge_docs (not noisy raw texts)."""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

from pypdf import PdfReader

from app.ai.doc_loader import _pack

PDF_ROOT = (
    Path(__file__).resolve().parent / "knowledge_docs" / "raw documents" / "pdfs"
)

# Explicit allowlist — only these PDFs are trusted enough for production RAG.
ALLOWED_PDF_STEMS = {
    "Resistance Training for Health",
    "resistance_training_primer",
    "Delayed Onset Muscle Soreness (DOMS)",
    "HIIT benefits and safety",
    "Physical_Activity_Guidelines",
    "physical_activity_sedentary_behaviour",
    "pre‑exercise stretching",
    "pre-exercise stretching",
    "Sleep & Athletic Performance",
    "Hydration & Exercise",
    "Protein Supplementation and Resistance Training",
}


@dataclass(frozen=True)
class PdfChunk:
    category: str
    topic: str
    content: str
    source: str


def _normalize_stem(name: str) -> str:
    return name.replace("‑", "-").strip()


def _is_allowed(path: Path) -> bool:
    stem = path.stem
    if stem in ALLOWED_PDF_STEMS:
        return True
    normalized = {_normalize_stem(s) for s in ALLOWED_PDF_STEMS}
    return _normalize_stem(stem) in normalized


def _extract_pdf_text(path: Path) -> str:
    reader = PdfReader(str(path))
    parts: list[str] = []
    for page in reader.pages:
        text = page.extract_text() or ""
        text = re.sub(r"[ \t]+", " ", text)
        text = re.sub(r"\n{3,}", "\n\n", text)
        if text.strip():
            parts.append(text.strip())
    return "\n\n".join(parts)


def load_allowed_pdf_chunks() -> list[PdfChunk]:
    """Extract and chunk allowlisted PDFs only."""
    if not PDF_ROOT.exists():
        return []

    chunks: list[PdfChunk] = []
    for path in sorted(PDF_ROOT.glob("*.pdf")):
        if not _is_allowed(path):
            continue
        try:
            text = _extract_pdf_text(path)
        except Exception as exc:  # noqa: BLE001
            raise RuntimeError(f"Failed reading PDF {path.name}: {exc}") from exc
        if len(text) < 200:
            continue
        # Split on blank lines / loose sections
        sections = [p.strip() for p in re.split(r"\n\s*\n", text) if p.strip()]
        packed = _pack(sections) if sections else []
        rel = f"raw documents/pdfs/{path.name}"
        topic = path.stem[:128]
        for piece in packed:
            chunks.append(
                PdfChunk(
                    category="pdf_guideline",
                    topic=topic,
                    content=f"{path.stem}\n\n{piece}",
                    source=rel,
                )
            )
    return chunks
