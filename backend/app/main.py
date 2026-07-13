from fastapi import FastAPI

from app.routers import auth

app = FastAPI(title="AI Fitness Coach API")

app.include_router(auth.router, prefix="/api")


@app.get("/health")
def health_check():
    return {"status": "ok"}
