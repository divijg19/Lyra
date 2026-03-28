from datetime import UTC, datetime, timedelta
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from core.models.spotify import SpotifyAuth
from core.models.user import User
from integrations.spotify.auth import SpotifyTokenResponse


async def upsert_spotify_auth(
    session: AsyncSession,
    token_data: SpotifyTokenResponse,
    user_id: UUID | None = None,
) -> User:
    if user_id is None:
        user = User()
        session.add(user)
        await session.flush()
    else:
        user = await session.get(User, user_id)
        if user is None:
            user = User(id=user_id)
            session.add(user)
            await session.flush()

    auth_record = await session.scalar(
        select(SpotifyAuth).where(SpotifyAuth.user_id == user.id)
    )
    expires_at = datetime.now(tz=UTC) + timedelta(seconds=token_data.expires_in)

    if auth_record is None:
        auth_record = SpotifyAuth(
            user_id=user.id,
            access_token=token_data.access_token,
            refresh_token=token_data.refresh_token,
            expires_at=expires_at,
        )
        session.add(auth_record)
    else:
        auth_record.access_token = token_data.access_token
        auth_record.refresh_token = token_data.refresh_token
        auth_record.expires_at = expires_at

    await session.commit()
    await session.refresh(user)
    return user
