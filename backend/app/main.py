from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import auth, coach, programs, sessions, users

app = FastAPI(title="AI Fitness Coach API")

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
