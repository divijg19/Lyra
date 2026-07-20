from __future__ import annotations

from datetime import UTC, datetime, timedelta

import jwt
import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from core.config.settings import settings
from core.security.auth import get_current_user
from core.models.user import User
from modules.auth.service import create_access_token


@pytest.mark.asyncio
async def test_get_current_user_accepts_valid_jwt(db_session: AsyncSession) -> None:
    user = User(spotify_id="spotify-auth-valid")
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    token = create_access_token({"sub": str(user.id)})

    current_user = await get_current_user(token=token, db=db_session)

    assert current_user.id == user.id


@pytest.mark.asyncio
async def test_expired_jwt_returns_unauthorized(
    async_client,
    authenticated_user: User,
) -> None:
    expired_token = jwt.encode(
        {
            "sub": str(authenticated_user.id),
            "exp": datetime.now(tz=UTC) - timedelta(minutes=5),
        },
        settings.SECRET_KEY,
        algorithm=settings.ALGORITHM,
    )

    response = await async_client.get(
        "/auth/session",
        headers={"Authorization": f"Bearer {expired_token}"},
    )

    assert response.status_code == 401
    assert response.json() == {"detail": "Invalid session"}
