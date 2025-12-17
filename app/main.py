from fastapi import FastAPI
from app.models.user import User

app = FastAPI(title="User Management API")

@app.get("/health")
def health():
    return {"status": "ok"}
