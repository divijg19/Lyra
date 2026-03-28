from fastapi import FastAPI

from routers import auth


def create_app() -> FastAPI:
    app = FastAPI(title="Lyra API")
    app.include_router(auth.router)

    @app.get("/health")
    async def health() -> dict[str, str]:
        return {"status": "ok"}

    return app


app = create_app()
