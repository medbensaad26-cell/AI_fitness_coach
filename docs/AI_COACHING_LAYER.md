# AI Coaching Layer — Technical Documentation

**Project:** AI Fitness Coach  
**Scope:** Backend generative AI, RAG knowledge retrieval, and live coaching services  
**Package:** `backend/app/ai/`  
**Status:** Person A deliverables complete (pending final Docker smoke verification after disk remediation)  
**Document version:** 1.0  
**Last updated:** 2026-07-22

---

## 1. Executive summary

AI Fitness Coach is designed as a **full digital coach**, not a chatbot that only answers questions or dumps a static workout list. The system learns who the user is, proposes relevant training programs, guides them while they train, records what actually happened, and adapts future programs from that feedback.

This document describes the **AI / RAG coaching layer** delivered under `backend/app/ai/`. That layer is implemented as **callable Python services**. Person B exposes them through FastAPI HTTP routes; the Flutter client (Person C) consumes those routes. Voice (speech-to-text / text-to-speech) remains outside this package: AI functions are **text in / text out**.

**What was delivered**

| Capability | Purpose |
|------------|---------|
| RAG foundation | Embed and retrieve trusted fitness knowledge via pgvector |
| Exercise catalog | Structured exercise library used for safer program generation |
| Program generation | Profile + knowledge (+ optional history) → saveable `ProgramCreate` |
| Session history memory | Index completed sessions for personalized continuity |
| Suggest next | Adapt the next session from recent and similar history |
| Live coach | Start / after-exercise / mid-session / end-session coaching turns |
| Integration contract | Clear API surface for Person B (`CONTRACT.md`) |

---

## 2. Product vision

### 2.1 Long-term product

| Phase | Behavior |
|-------|----------|
| Before training | Understand profile (level, goal, equipment, limitations) and propose a relevant program |
| During training | Act like a coach: ask how the user feels, how hard work feels, give practical cues, flag safety concerns |
| After training | Record completed work, feeling, fatigue, skips, and notes |
| Over time | Retrieve personal history and adapt future sessions (volume, regressions, alternatives) |

### 2.2 Client and stack

| Layer | Technology |
|-------|------------|
| Mobile client (planned) | Flutter |
| API | FastAPI (Python 3.12) |
| Database | PostgreSQL 16 + **pgvector** |
| Orchestration | Docker Compose (`api`, `db`) |
| Chat LLM | Groq API — `llama-3.3-70b-versatile` |
| Embeddings | Local `fastembed` — `BAAI/bge-small-en-v1.5` (384 dimensions) |

---

## 3. Team responsibilities

Work was split so ownership stays clear and teams do not collide.

| Role | Ownership |
|------|-----------|
| **Person A (AI / RAG)** | Everything under `backend/app/ai/`: models for knowledge/history/exercises (schema), ingest, retrieval, generation, live coach, smoke scripts, this documentation |
| **Person B (API / data)** | FastAPI routers, auth persistence wiring, applying Alembic migrations, calling AI functions from routes, reviewing DB ownership |
| **Person C (mobile)** | Flutter UI, optional voice STT/TTS around text APIs |

**Boundary rule:** no FastAPI routes inside `app/ai/`. AI code returns structured Pydantic objects (or existing program schemas) that B can persist and expose.

---

## 4. Starting point (foundation already in place)

Before the AI layer, the backend already provided:

- User registration / login (JWT)
- User fitness profiles
- Planned programs with ordered exercises
- Completed workout sessions linked to programs
- Session fields suitable for coaching feedback (feeling, fatigue, difficulty, skipped, notes)

The AI layer **builds on** that foundation: it generates payloads compatible with existing program/session schemas and indexes session snapshots into vector memory for later adaptation.

---

## 5. Architecture overview

```text
┌─────────────────────┐
│  Flutter (Person C) │  text / optional voice→text
└──────────┬──────────┘
           │ HTTP
┌──────────▼──────────┐
│ FastAPI (Person B)  │  auth, CRUD, orchestration
└──────────┬──────────┘
           │ Python calls
┌──────────▼──────────────────────────────────────────┐
│ backend/app/ai/ (Person A)                          │
│  generate_program / suggest_next / live_coach       │
│  retrieval / history / catalog / ingest             │
│  chat (Groq)  ·  embeddings (fastembed)             │
└──────────┬───────────────────────────┬──────────────┘
           │                           │
           ▼                           ▼
   PostgreSQL + pgvector         Groq chat API
   knowledge_chunks              llama-3.3-70b-versatile
   user_history_chunks
   exercises
```

### 5.1 Design principles

1. **Structured outputs** — LLM responses are constrained to JSON and validated with Pydantic before handoff to B.  
2. **Retrieval-augmented coaching** — generation and coaching inject retrieved knowledge (and history when available), reducing hallucination and improving safety.  
3. **Catalog preference** — programs prefer real exercise IDs/names from the `exercises` table.  
4. **Trusted sources only** — noisy social/forum raw texts are not ingested; science PDFs are allowlisted.  
5. **Docker-first** — all run/ingest/smoke commands are intended for `docker compose exec api ...`.

---

## 6. Delivery milestones (what we implemented)

### Milestone 1 — RAG foundation

**What:** OpenAI-compatible chat client (Groq), local embeddings, `knowledge_chunks` table, seed/ingest + similarity retrieval.  
**Why:** Coaching answers and program choices must be grounded in fitness knowledge, not model memory alone.  
**How:**

- `client.py` / `chat.py` — Groq chat completions  
- `embeddings.py` — `fastembed` vectors (384-d)  
- `models/knowledge.py` — `KnowledgeChunk` + pgvector column  
- `retrieval.py` — top-k cosine similarity search  
- Alembic: `b4c5d6e7f8a9_add_knowledge_chunks.py`

### Milestone 2 — Knowledge ingest (docs + exercises)

**What:** Load curated markdown guidelines and structured exercise JSON into the database.  
**Why:** Separate *trusted coaching knowledge* (RAG) from *canonical exercise catalog* (selection + form metadata).  
**How:**

- `knowledge_docs/documents/**` → `doc_loader.py` → `ingest_docs.py` → `knowledge_chunks`  
- `knowledge_docs/exercises/**/*.json` → `exercise_loader.py` → `ingest_exercises.py` → `exercises` table (+ optional RAG snippets)  
- Alembic: `c5d6e7f8a9b0_add_exercises_and_knowledge_source.py` (exercises + `source` on chunks)

### Milestone 3 — Program generation

**What:** `generate_program(db, profile, user_id=None) -> ProgramCreate`.  
**Why:** Turn profile + retrieved tips (+ optional history) into a payload B can save with existing program APIs.  
**How:** Build prompt → Groq JSON → validate → map to `ProgramCreate` (ordered exercises, sets/reps/rest/notes).

### Milestone 4 — Personal history memory

**What:** After a session is saved, summarize/index it into `user_history_chunks` with embeddings.  
**Why:** Continuity (“last time knees hurt on goblet squat”) requires searchable personal memory, not only global knowledge.  
**How:**

- `history.py` — `index_session_history`, `get_recent_user_history`, `retrieve_user_history`  
- Alembic: `d6e7f8a9b0c1_add_user_history_chunks.py`

### Milestone 5 — Suggest next / adaptation

**What:** `suggest_next_program(db, profile, user_id)` returns a next program plus rationale and adaptation bullets.  
**Why:** Close the loop: completed work should change the next session (fatigue ↓ volume, pain → regression, success → progress).  
**How:** Combine profile, catalog, global RAG, recent history, and similar history in one structured generation call.

### Milestone 6 — Live coach loop

**What:** In-session coaching turns as structured messages + UI prompts.  
**Why:** The product differentiator is coaching *during* training, not only plan generation.  
**How (`live_coach.py`):**

| Function | When | Returns |
|----------|------|---------|
| `start_session_check_in` | Workout start | Coach message + prompts (e.g. readiness scale) |
| `after_exercise_feedback` | After each exercise | Message, normalized feedback row, `safety_flag` |
| `mid_session_coach` | Free-form mid-session question | Message, `safety_flag`, `suggested_action` |
| `end_session_coach` | Workout end | Closing message + `SessionSnapshot` for persistence |

`suggested_action` values: `continue` | `regress_exercise` | `skip_exercise` | `rest` | `end_session`.

### Milestone 7 — Polishes

| Polish | Outcome |
|--------|---------|
| Catalog-aware generation | `catalog.py` filters exercises by level/equipment/limitations; outputs prefer `exercise_id` + canonical names |
| Allowlisted PDF ingest | `pdf_loader.py` + `ingest_pdfs.py` embed selected science PDFs only (`pypdf`) |
| Richer mid-session dialogue | `mid_session_coach` beyond fixed numeric scales |
| B handoff doc | `backend/app/ai/CONTRACT.md` |

### Ops note (environment)

Docker Desktop data was moved from a full **C:** volume to **D:\DockerData** (junction from the original Docker WSL path) so image builds and ingest could resume.

---

## 7. Package layout

```text
backend/app/ai/
├── __init__.py              # Public lazy exports
├── CONTRACT.md              # Short integration contract for Person B
├── client.py                # Groq / OpenAI-compatible client
├── chat.py                  # chat_completion helper
├── embeddings.py            # fastembed encode
├── retrieval.py             # knowledge similarity search
├── catalog.py               # Exercise catalog selection + name resolution
├── generate_program.py      # Profile → ProgramCreate
├── suggest_next.py          # History-aware next session
├── history.py               # Index + retrieve personal session memory
├── live_coach.py            # In-session coaching turns
├── schemas.py               # ProfileContext, snapshots, live-coach I/O
├── doc_loader.py            # Trusted markdown → chunks
├── exercise_loader.py       # Exercise JSON → rows / chunks
├── pdf_loader.py            # Allowlisted PDFs → chunks
├── ingest.py / ingest_docs.py / ingest_exercises.py / ingest_pdfs.py
├── knowledge_seed.py        # Optional seed content
├── smoke_*.py               # Docker verification scripts
└── knowledge_docs/          # Source corpus (documents, exercises, raw PDFs)
```

Related models (Person A schema / Person B migrations):

- `backend/app/models/knowledge.py` — `KnowledgeChunk`  
- `backend/app/models/exercise.py` — `Exercise`  
- `backend/app/models/` — user history chunk model (via history migration)

---

## 8. Data model (AI-related)

### 8.1 `knowledge_chunks`

| Column | Role |
|--------|------|
| `id` | UUID primary key |
| `category` | Filter/debug label (e.g. form, programming, `pdf_guideline`) |
| `topic` | Optional topic tag |
| `content` | Text injected into LLM context after retrieval |
| `source` | Provenance path or seed id |
| `embedding` | `vector(384)` for similarity search |
| `created_at` | Timestamp |

### 8.2 `exercises`

Canonical catalog keyed by stable slug (`id`, e.g. `romanian_deadlift`), including pattern, equipment, difficulty, instructions, form cues, contraindications, regressions/progressions, and safety notes.

### 8.3 `user_history_chunks`

Per-user embedded summaries of completed sessions (feeling, fatigue, exercise outcomes) used by `suggest_next` and history-aware generation.

---

## 9. Knowledge base strategy

Corpus lives under `backend/app/ai/knowledge_docs/`.

| Path | Use |
|------|-----|
| `documents/curated/` | Short trusted coaching notes (ingest) |
| `documents/external_sources/` | Guideline-style markdown (ingest) |
| `exercises/**/*.json` | Exercise catalog (DB + optional RAG) |
| `raw documents/pdfs/` | Science PDFs — **allowlisted only** via `pdf_loader.py` |
| `raw documents/texts/`, noisy CSV, social posts | **Not ingested** (low trust / high noise) |

**PDF allowlist** (representative): resistance training primers, DOMS, HIIT safety, physical activity guidelines, pre-exercise stretching, sleep & performance, hydration, protein supplementation.

Ingest commands (Docker):

```bash
docker compose exec api python -m app.ai.ingest_docs
docker compose exec api python -m app.ai.ingest_exercises
docker compose exec api python -m app.ai.ingest_pdfs
```

---

## 10. Public service API (for Person B)

Full quick-reference: [`backend/app/ai/CONTRACT.md`](../backend/app/ai/CONTRACT.md).

### 10.1 Function catalog

| Function | Module | Call when | Returns |
|----------|--------|-----------|---------|
| `generate_program(db, profile, user_id=None)` | `generate_program` | New plan / onboarding | `ProgramCreate` |
| `suggest_next_program(db, profile, user_id)` | `suggest_next` | “What’s next?” | program + `rationale` + `adaptations` |
| `index_session_history(...)` | `history` | After session saved | history chunk row |
| `retrieve_knowledge(db, query)` | `retrieval` | Debug / optional | knowledge chunks |
| `start_session_check_in(...)` | `live_coach` | Workout start | `message`, `prompts` |
| `after_exercise_feedback(...)` | `live_coach` | After each exercise | `message`, `feedback`, `safety_flag` |
| `mid_session_coach(...)` | `live_coach` | Free-form mid-session Q | `message`, `suggested_action`, `safety_flag` |
| `end_session_coach(...)` | `live_coach` | Workout end | `message`, `snapshot` |

Input/output models: `backend/app/ai/schemas.py` (`ProfileContext`, `SessionSnapshot`, live-coach types, etc.).

### 10.2 Recommended session flow

```text
1. start_session_check_in
2. User trains
3. after_exercise_feedback  (per exercise) → persist exercise row
4. mid_session_coach        (optional free-form / voice→text)
5. end_session_coach        → persist session from snapshot
6. index_session_history
7. Later: suggest_next_program
```

### 10.3 Example import pattern

```python
from app.ai.generate_program import generate_program
from app.ai.suggest_next import suggest_next_program
from app.ai.history import index_session_history
from app.ai.live_coach import (
    start_session_check_in,
    after_exercise_feedback,
    mid_session_coach,
    end_session_coach,
)
from app.ai.schemas import ProfileContext
```

---

## 11. Configuration

Environment variables (see `.env.example`):

| Variable | Default / notes |
|----------|-----------------|
| `GROQ_API_KEY` | Required for chat |
| `GROQ_BASE_URL` | `https://api.groq.com/openai/v1` |
| `CHAT_MODEL` | `llama-3.3-70b-versatile` |
| `EMBEDDING_MODEL` | `BAAI/bge-small-en-v1.5` |
| `EMBEDDING_DIMENSIONS` | `384` (must match DB vector column) |
| `DATABASE_URL` | Async SQLAlchemy URL (`postgresql+asyncpg://...`) |

Python extras (AI): `openai`, `fastembed`, `pypdf` (in `backend/requirements.txt`).

---

## 12. Verification

Smoke scripts (run inside the API container):

```bash
docker compose up -d --build

docker compose exec api python -m app.ai.ingest_docs
docker compose exec api python -m app.ai.ingest_exercises
docker compose exec api python -m app.ai.ingest_pdfs

docker compose exec api python -m app.ai.smoke_retrieval
docker compose exec api python -m app.ai.smoke_generate_program
docker compose exec api python -m app.ai.smoke_history
docker compose exec api python -m app.ai.smoke_suggest_next
docker compose exec api python -m app.ai.smoke_live_coach
```

These scripts exercise Groq + DB + retrieval without requiring HTTP routes.

---

## 13. Current status and next steps

### Completed (Person A)

- [x] RAG client, embeddings, knowledge storage & retrieval  
- [x] Trusted document + exercise catalog ingest  
- [x] Program generation aligned with existing program schema  
- [x] User session history indexing & retrieval  
- [x] Suggest-next adaptation  
- [x] Live coach (start / after exercise / mid-session / end)  
- [x] Catalog preference + PDF allowlist + B contract documentation  
- [x] Docker data relocated to `D:\DockerData` (host disk remediation)

### Remaining (product)

| Owner | Next work |
|-------|-----------|
| Person A (optional) | Re-run full Docker rebuild + smoke suite now that disk space is available |
| **Person B** | Add HTTP routes that call AI functions; review/apply AI-related Alembic migrations; wire save flows to `index_session_history` |
| **Person C** | Flutter screens for profile, program, live session prompts; optional voice around text APIs |

---

## 14. Related documents

| Document | Audience |
|----------|----------|
| [`backend/app/ai/CONTRACT.md`](../backend/app/ai/CONTRACT.md) | Person B — concise call contract |
| [`.env.example`](../.env.example) | Environment template |
| [`README.md`](../README.md) | Project entry point |

---

## 15. Glossary

| Term | Meaning |
|------|---------|
| **RAG** | Retrieval-Augmented Generation — retrieve relevant chunks, then ask the LLM |
| **pgvector** | PostgreSQL extension for vector similarity search |
| **Catalog** | Canonical `exercises` table used to constrain program generation |
| **Live coach** | In-session dialogue and check-ins during a workout |
| **ProgramCreate** | Existing backend schema used to persist a planned program |
