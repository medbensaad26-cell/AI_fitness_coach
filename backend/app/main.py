from fastapi import FastAPI

from app.routers import auth, programs, sessions, users

app = FastAPI(title="AI Fitness Coach API")

app.include_router(auth.router, prefix="/api")
app.include_router(users.router, prefix="/api")
app.include_router(sessions.router, prefix="/api")
app.include_router(programs.router, prefix="/api")


@app.get("/health")
def health_check():
    return {"status": "ok"}
