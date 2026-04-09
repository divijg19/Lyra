from collections.abc import AsyncIterator

from pgvector.psycopg import register_vector_async
from sqlalchemy import event
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from core.config.settings import settings


engine: AsyncEngine = create_async_engine(
    settings.sqlalchemy_database_url,
    echo=settings.is_development,
)


@event.listens_for(engine.sync_engine, "connect")
def _register_pgvector(dbapi_connection, _) -> None:
    dbapi_connection.run_async(register_vector_async)


AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


async def get_db_session() -> AsyncIterator[AsyncSession]:
    async with AsyncSessionLocal() as session:
        yield session


async def get_db() -> AsyncIterator[AsyncSession]:
    async with AsyncSessionLocal() as session:
        yield session
