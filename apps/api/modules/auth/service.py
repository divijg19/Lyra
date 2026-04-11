from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import UUID

import jwt
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from core.config.settings import settings
from core.models.spotify import SpotifyAuth
from core.models.user import User
from integrations.spotify.auth import (
    SpotifyTokenResponse,
    fetch_spotify_profile,
    refresh_spotify_access_token,
)

SESSION_LIFETIME = timedelta(days=30)


async def upsert_spotify_auth(
    session: AsyncSession,
    token_data: SpotifyTokenResponse,
) -> User:
    profile = await fetch_spotify_profile(token_data.access_token)
    spotify_id = profile.get("id")
    if not spotify_id:
        raise ValueError("Spotify profile response did not include an id")

    user = await session.scalar(select(User).where(User.spotify_id == spotify_id))
    if user is None:
        user = User(spotify_id=spotify_id)
        session.add(user)
        await session.flush()
    else:
        user.spotify_id = spotify_id

    auth_record = await session.scalar(
        select(SpotifyAuth).where(SpotifyAuth.user_id == user.id)
    )
    expires_at = datetime.now(tz=UTC) + timedelta(seconds=token_data.expires_in)
    refresh_token = _resolve_refresh_token(token_data, auth_record)

    if auth_record is None:
        auth_record = SpotifyAuth(
            user_id=user.id,
            access_token=token_data.access_token,
            refresh_token=refresh_token,
            expires_at=expires_at,
        )
        session.add(auth_record)
    else:
        auth_record.access_token = token_data.access_token
        auth_record.refresh_token = refresh_token
        auth_record.expires_at = expires_at

    await session.commit()
    await session.refresh(user)
    return user


def create_access_token(data: dict[str, Any]) -> str:
    payload = data.copy()
    now = datetime.now(tz=UTC)
    payload.setdefault("iat", now)
    payload.setdefault("exp", now + SESSION_LIFETIME)
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


async def ensure_valid_spotify_token(user_id: UUID, db: AsyncSession) -> str:
    auth_record = await db.scalar(select(SpotifyAuth).where(SpotifyAuth.user_id == user_id))
    if auth_record is None:
        raise ValueError("Spotify auth not found for user")

    now = datetime.now(tz=UTC)
    expires_at = auth_record.expires_at
    if expires_at > now + timedelta(seconds=30):
        return auth_record.access_token

    refreshed = await refresh_spotify_access_token(auth_record.refresh_token)
    auth_record.access_token = refreshed.access_token
    auth_record.expires_at = now + timedelta(seconds=refreshed.expires_in)
    auth_record.refresh_token = _resolve_refresh_token(refreshed, auth_record)
    await db.commit()
    return auth_record.access_token


def _resolve_refresh_token(
    token_data: SpotifyTokenResponse,
    auth_record: SpotifyAuth | None,
) -> str:
    if token_data.refresh_token:
        return token_data.refresh_token

    if auth_record is not None:
        return auth_record.refresh_token

    return ""
