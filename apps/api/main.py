import sys
from pathlib import Path

# Ensure package-local imports (e.g. `from core...`) resolve when running
# the app from the repository root (uvicorn run from project root).
sys.path.insert(0, str(Path(__file__).resolve().parent))

from fastapi import FastAPI

from .routers import auth, library


def create_app() -> FastAPI:
    app = FastAPI(title="Lyra API")
    app.include_router(auth.router)
    app.include_router(library.router)

    @app.get("/health")
    async def health() -> dict[str, str]:
        return {"status": "ok"}

    return app


app = create_app()
