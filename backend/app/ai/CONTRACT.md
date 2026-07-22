# Person A → Person B AI service contract

> Full technical documentation: [`docs/AI_COACHING_LAYER.md`](../../../docs/AI_COACHING_LAYER.md)

Call these Python functions from FastAPI routers. Do **not** put HTTP routes inside `app/ai/`.

## Setup (Docker)

```bash
docker compose up -d --build
docker compose exec api python -m app.ai.ingest_docs
docker compose exec api python -m app.ai.ingest_exercises
docker compose exec api python -m app.ai.ingest_pdfs   # allowlisted science PDFs only
```

Env (via `.env` / compose): `GROQ_API_KEY`, `CHAT_MODEL`, `EMBEDDING_MODEL`, `EMBEDDING_DIMENSIONS`.

## Public functions

| Function | Module | When to call | Returns |
|----------|--------|--------------|---------|
| `generate_program(db, profile, user_id=None)` | `app.ai.generate_program` | New plan / onboarding | `ProgramCreate` |
| `suggest_next_program(db, profile, user_id)` | `app.ai.suggest_next` | “What’s next?” | `program`, `rationale`, `adaptations` |
| `index_session_history(db, user_id=, session_id=, snapshot=)` | `app.ai.history` | After session saved | `UserHistoryChunk` |
| `retrieve_knowledge(db, query)` | `app.ai.retrieval` | Optional debugging | chunks |
| `start_session_check_in(db, profile, ...)` | `app.ai.live_coach` | Workout start | `message`, `prompts` |
| `after_exercise_feedback(db, profile, payload)` | `app.ai.live_coach` | After each exercise | `message`, `feedback`, `safety_flag` |
| `mid_session_coach(db, profile, payload)` | `app.ai.live_coach` | Free-form mid-session Q | `message`, `suggested_action` |
| `end_session_coach(profile, payload)` | `app.ai.live_coach` | Workout end | `message`, `snapshot` |

Schemas live in `app.ai.schemas` (`ProfileContext`, `SessionSnapshot`, live-coach inputs, etc.).

## Typical session flow

1. `start_session_check_in` → show prompts  
2. User trains; after each move `after_exercise_feedback` → save exercise row  
3. Optional: `mid_session_coach` for voice/text questions  
4. `end_session_coach` → save session from `snapshot`  
5. `index_session_history(...)`  
6. Later: `suggest_next_program(...)`

## Notes for B

- Migrations under `alembic/versions/` (`knowledge_chunks`, `exercises`, `user_history_chunks`, `source` column) — review/own them.  
- Catalog-backed generation prefers `exercises` table names; `notes` may include `[id:slug]` when resolved.  
- Do **not** ingest `raw documents/texts` noise; PDFs are allowlisted in `pdf_loader.py`.  
- Voice (STT/TTS) stays in Flutter/C or B glue; AI functions are text in / text out.
