"""Load trusted markdown docs from knowledge_docs into RAG-ready text chunks.

Trusted only:
  documents/curated/**
  documents/external_sources/**

Skips raw documents/ (noise) on purpose.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

DOCS_ROOT = Path(__file__).resolve().parent / "knowledge_docs" / "documents"
TRUSTED_SUBDIRS = ("curated", "external_sources")

_MAX_CHARS = 1100
_MIN_CHARS = 120


@dataclass(frozen=True)
class DocChunk:
    category: str
    topic: str | None
    content: str
    source: str


def _parse_frontmatter(text: str) -> tuple[dict[str, str], str]:
    if not text.startswith("---"):
        return {}, text
    end = text.find("\n---", 3)
    if end == -1:
        return {}, text
    block = text[3:end].strip()
    body = text[end + 4 :].lstrip("\n")
    meta: dict[str, str] = {}
    for line in block.splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        meta[key.strip()] = value.strip().strip("\"'")
    return meta, body


def _split_sections(body: str) -> list[str]:
    """Split on markdown ## headings; keep heading with its body."""
    parts = re.split(r"(?m)^(## .+)$", body)
    if len(parts) == 1:
        return [body.strip()] if body.strip() else []

    sections: list[str] = []
    # parts[0] is preface before first ##
    if parts[0].strip():
        sections.append(parts[0].strip())
    for i in range(1, len(parts), 2):
        heading = parts[i].strip()
        content = parts[i + 1].strip() if i + 1 < len(parts) else ""
        chunk = f"{heading}\n\n{content}".strip()
        if chunk:
            sections.append(chunk)
    return sections


def _pack(sections: list[str]) -> list[str]:
    """Merge tiny sections; split oversized ones on paragraphs."""
    packed: list[str] = []
    buf = ""
    for section in sections:
        if len(section) > _MAX_CHARS:
            if buf:
                packed.append(buf)
                buf = ""
            paras = [p.strip() for p in re.split(r"\n\s*\n", section) if p.strip()]
            current = ""
            for para in paras:
                candidate = f"{current}\n\n{para}".strip() if current else para
                if len(candidate) <= _MAX_CHARS:
                    current = candidate
                else:
                    if current:
                        packed.append(current)
                    current = para
            if current:
                packed.append(current)
            continue

        candidate = f"{buf}\n\n{section}".strip() if buf else section
        if len(candidate) <= _MAX_CHARS:
            buf = candidate
        else:
            if buf:
                packed.append(buf)
            buf = section
    if buf:
        packed.append(buf)

    return [c for c in packed if len(c) >= _MIN_CHARS]


def load_trusted_doc_chunks() -> list[DocChunk]:
    """Read curated + external_sources markdown into DocChunk list."""
    chunks: list[DocChunk] = []
    if not DOCS_ROOT.exists():
        return chunks

    for sub in TRUSTED_SUBDIRS:
        root = DOCS_ROOT / sub
        if not root.exists():
            continue
        for path in sorted(root.rglob("*.md")):
            text = path.read_text(encoding="utf-8")
            meta, body = _parse_frontmatter(text)
            category = (meta.get("domain") or sub)[:64]
            topic = (meta.get("topic") or path.stem)[:128]
            rel = str(path.relative_to(DOCS_ROOT.parent)).replace("\\", "/")
            title = next(
                (line[2:].strip() for line in body.splitlines() if line.startswith("# ")),
                path.stem,
            )
            for piece in _pack(_split_sections(body)):
                content = f"{title}\n\n{piece}".strip()
                source_line = meta.get("source")
                if source_line:
                    content = f"{content}\n\n(Source: {source_line})"
                chunks.append(
                    DocChunk(
                        category=category,
                        topic=topic,
                        content=content,
                        source=rel,
                    )
                )
    return chunks
