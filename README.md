# AI Fitness Coach

AI-powered fitness coaching platform: a FastAPI backend with PostgreSQL/pgvector, RAG knowledge retrieval, and LLM-driven program generation and live coaching. A Flutter mobile client is planned.

The product goal is a **full digital coach** — not a chatbot that only answers questions. The system learns the user, proposes training programs, guides them during workouts, records what happened, and adapts future sessions from that feedback.

## Stack

| Component | Choice |
|-----------|--------|
| API | FastAPI (Python 3.12) |
| Database | PostgreSQL 16 + pgvector |
| Chat model | Groq — `llama-3.3-70b-versatile` |
| Embeddings | fastembed — `BAAI/bge-small-en-v1.5` (384-d) |
| Runtime | Docker Compose |
| Mobile (planned) | Flutter |

## Repository layout

```text
backend/          FastAPI app, Alembic, AI package (app/ai/)
docs/             Project documentation
frontend/         Flutter client (planned)
docker-compose.yml
.env.example
```

## Documentation

| Document | Description |
|----------|-------------|
| **[docs/AI_COACHING_LAYER.md](docs/AI_COACHING_LAYER.md)** | Full technical documentation of the AI/RAG coaching layer (architecture, milestones, data model, ops) |
| **[backend/app/ai/CONTRACT.md](backend/app/ai/CONTRACT.md)** | Short Person A → Person B integration contract |

## Quick start (Docker)

1. Copy `.env.example` to `.env` and set `GROQ_API_KEY` (and other secrets as needed).
2. Start services:

```bash
docker compose up -d --build
```

3. Ingest knowledge (after migrations have been applied):

```bash
docker compose exec api python -m app.ai.ingest_docs
docker compose exec api python -m app.ai.ingest_exercises
docker compose exec api python -m app.ai.ingest_pdfs
```

API default: `http://localhost:8000`

## Team ownership (summary)

| Role | Focus |
|------|--------|
| Person A | AI / RAG services under `backend/app/ai/` |
| Person B | HTTP routes, persistence wiring, migrations |
| Person C | Flutter UI (+ optional voice) |

## Current status

- **Foundation:** auth, profiles, programs, sessions — in place  
- **AI coaching layer:** implemented as Python services (see docs above)  
- **Next:** Person B HTTP integration, then Flutter client  
