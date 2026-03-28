from fastapi import FastAPI


def create_app() -> FastAPI:
    app = FastAPI(title="Lyra API")

    @app.get("/health")
    async def health() -> dict[str, str]:
        return {"status": "ok"}

    return app


app = create_app()
