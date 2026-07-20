from __future__ import annotations

import sys
import types
from collections.abc import AsyncIterator
from pathlib import Path
from uuid import uuid4

import pytest_asyncio
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

API_DIR = Path(__file__).resolve().parents[1]
if str(API_DIR) not in sys.path:
    sys.path.insert(0, str(API_DIR))


class _DummyEmbedding(list[float]):
    def tolist(self) -> list[float]:
        return list(self)


class _DummySentenceTransformer:
    def __init__(self, *_args, **_kwargs) -> None:
        pass

    def encode(self, _value: object) -> _DummyEmbedding:
        vector = [0.0] * 384
        vector[0] = 1.0
        return _DummyEmbedding(vector)


fake_sentence_transformers = types.ModuleType("sentence_transformers")
fake_sentence_transformers.SentenceTransformer = _DummySentenceTransformer
sys.modules.setdefault("sentence_transformers", fake_sentence_transformers)

from core.config.settings import settings
from core.db.session import get_db, get_db_session
from core.models import Base
from core.models.user import User
from modules.auth.service import create_access_token
from routers import auth, library, playlists


@pytest_asyncio.fixture(scope="session")
async def test_schema() -> AsyncIterator[str]:
    schema_name = f"test_{uuid4().hex}"
    engine = create_async_engine(settings.sqlalchemy_database_url, future=True)

    async with engine.begin() as conn:
        await conn.execute(text("CREATE EXTENSION IF NOT EXISTS vector"))
        await conn.execute(text(f'CREATE SCHEMA "{schema_name}"'))
        translated_conn = conn.execution_options(
            schema_translate_map={None: schema_name}
        )
        await translated_conn.run_sync(Base.metadata.create_all)

    try:
        yield schema_name
    finally:
        async with engine.begin() as conn:
            await conn.execute(text(f'DROP SCHEMA IF EXISTS "{schema_name}" CASCADE'))
        await engine.dispose()


@pytest_asyncio.fixture
async def session_maker(test_schema: str) -> AsyncIterator[async_sessionmaker[AsyncSession]]:
    engine = create_async_engine(settings.sqlalchemy_database_url, future=True)

    async with engine.connect() as connection:
        transaction = await connection.begin()
        translated_connection = connection.execution_options(
            schema_translate_map={None: test_schema}
        )

        maker = async_sessionmaker(
            bind=translated_connection,
            expire_on_commit=False,
            class_=AsyncSession,
            join_transaction_mode="create_savepoint",
        )

        try:
            yield maker
        finally:
            await transaction.rollback()

    await engine.dispose()


@pytest_asyncio.fixture
async def db_session(
    session_maker: async_sessionmaker[AsyncSession],
) -> AsyncIterator[AsyncSession]:
    async with session_maker() as session:
        yield session


@pytest_asyncio.fixture
async def app():
    test_app = FastAPI(title="Lyra API Test")
    localhost_origin_regex = r"https?://(localhost|127\.0\.0\.1)(:\d+)?$"
    test_app.add_middleware(
        CORSMiddleware,
        allow_origins=[],
        allow_origin_regex=localhost_origin_regex,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    test_app.include_router(auth.router)
    test_app.include_router(library.router)
    test_app.include_router(playlists.router)

    @test_app.get("/health")
    async def health() -> dict[str, str]:
        return {"status": "ok"}

    return test_app


@pytest_asyncio.fixture
async def async_client(
    app,
    session_maker: async_sessionmaker[AsyncSession],
) -> AsyncIterator[AsyncClient]:
    async def _get_test_db() -> AsyncIterator[AsyncSession]:
        async with session_maker() as session:
            yield session

    app.dependency_overrides[get_db] = _get_test_db
    app.dependency_overrides[get_db_session] = _get_test_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client

    app.dependency_overrides.clear()


@pytest_asyncio.fixture
async def authenticated_user(db_session: AsyncSession) -> User:
    user = User(spotify_id=f"spotify-{uuid4().hex}")
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest_asyncio.fixture
async def authenticated_client(
    async_client: AsyncClient,
    authenticated_user: User,
) -> AsyncIterator[AsyncClient]:
    token = create_access_token({"sub": str(authenticated_user.id)})
    async_client.headers["Authorization"] = f"Bearer {token}"
    yield async_client
