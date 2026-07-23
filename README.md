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
| **[docs/api-contracts.md](docs/api-contracts.md)** | HTTP API contracts (auth, profile, programs, sessions) |
| **[backend/app/ai/CONTRACT.md](backend/app/ai/CONTRACT.md)** | Short Person A → Person B integration contract |

## Environment setup

1. Copy the example env file (never commit `.env`):

```bash
cp .env.example .env
```

2. Edit `.env` and set at least:

| Variable | Purpose |
|----------|---------|
| `GROQ_API_KEY` | Groq API key for chat / coaching (required for AI routes) |
| `SECRET_KEY` | JWT signing secret |
| `POSTGRES_USER` | Postgres user (Compose `db` + `DATABASE_URL`) |
| `POSTGRES_PASSWORD` | Postgres password |
| `POSTGRES_DB` | Postgres database name |
| `DATABASE_URL` | Used for non-Docker local runs; **overridden inside Compose** to use host `db` |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | JWT lifetime (optional, default 60) |
| `GROQ_BASE_URL` | Optional Groq OpenAI-compatible base URL |
| `CHAT_MODEL` | Optional chat model id |
| `EMBEDDING_MODEL` | Optional embedding model id |
| `EMBEDDING_DIMENSIONS` | Must stay `384` unless migrations/models change |

`OPENAI_API_KEY` is **not** used by this repository (chat uses `GROQ_API_KEY`).

The API process **requires** `SECRET_KEY` and `DATABASE_URL` to be set (via `.env` / Compose). It will refuse to start if either is missing.

## Quick start (Docker)

```bash
cp .env.example .env
# set GROQ_API_KEY, SECRET_KEY, POSTGRES_PASSWORD (and other values) in .env

docker compose up -d --build
```

- API: `http://localhost:8000`
- OpenAPI: `http://localhost:8000/docs`
- On `api` container start, `entrypoint.sh` waits for Postgres then runs **`alembic upgrade head`**, then starts uvicorn.

### Migrations

Migrations run automatically on API container startup. To run them manually:

```bash
docker compose exec api alembic upgrade head
```

### Optional knowledge ingest (AI)

After the stack is healthy:

```bash
docker compose exec api python -m app.ai.ingest_docs
docker compose exec api python -m app.ai.ingest_exercises
docker compose exec api python -m app.ai.ingest_pdfs
```

### Useful commands

```bash
docker compose ps
docker compose logs -f api
docker compose down
```

**Note:** This Compose file is a **local development** layout (bind-mounted backend, uvicorn `--reload`, Postgres published on `5432`). It does not by itself define a locked-down production deployment.

## Team ownership (summary)

| Role | Focus |
|------|--------|
| Person A | AI / RAG services under `backend/app/ai/` |
| Person B | HTTP routes, persistence wiring, migrations |
| Person C | Flutter UI (+ optional voice) |

## Current status

- **Foundation:** auth, profiles, programs, sessions — in place  
- **AI coaching layer:** implemented as Python services (see docs above)  
- **HTTP API:** profile PATCH, program generate / suggest-next, sessions (see `docs/api-contracts.md`)  
