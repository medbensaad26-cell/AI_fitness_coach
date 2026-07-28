from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import auth, coach, programs, sessions, users


@asynccontextmanager
async def lifespan(_app: FastAPI):
    # First RAG call otherwise downloads HF embedding weights (minutes) and
    # can look like a hung coach reply — especially under --reload.
    try:
        from app.ai.embeddings import embed_text

        await embed_text("warmup")
    except Exception:
        # Coach can still run later; warmup is best-effort.
        pass
    yield


app = FastAPI(title="AI Fitness Coach API", lifespan=lifespan)

# Allow local Flutter web / desktop tooling to call the API during development.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/api")
app.include_router(users.router, prefix="/api")
app.include_router(sessions.router, prefix="/api")
app.include_router(programs.router, prefix="/api")
app.include_router(coach.router, prefix="/api")


@app.get("/health")
def health_check():
    return {"status": "ok"}
