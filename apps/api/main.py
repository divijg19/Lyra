import sys
from pathlib import Path

# Ensure package-local imports (e.g. `from core...`) resolve when running
# the app from the repository root (uvicorn run from project root).
sys.path.insert(0, str(Path(__file__).resolve().parent))

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .routers import auth, library, playlists


def create_app() -> FastAPI:
    app = FastAPI(title="Lyra API")
    localhost_origin_regex = r"https?://(localhost|127\.0\.0\.1)(:\d+)?$"
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[],
        allow_origin_regex=localhost_origin_regex,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.include_router(auth.router)
    app.include_router(library.router)
    app.include_router(playlists.router)

    @app.get("/health")
    async def health() -> dict[str, str]:
        return {"status": "ok"}

    return app


app = create_app()
