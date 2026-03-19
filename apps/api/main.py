from fastapi import FastAPI
from dotenv import load_dotenv

app = FastAPI()

@app.get("/health")
def health():
    return {"status": "ok"}


load_dotenv()