from fastapi import FastAPI

app = FastAPI(title="AI Fitness Coach API")


@app.get("/health")
def health_check():
    return {"status": "ok"}
