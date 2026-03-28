from uuid import UUID

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import RedirectResponse
from sqlalchemy.ext.asyncio import AsyncSession

from core.db.session import get_db_session
from integrations.spotify.auth import (
    exchange_spotify_code_for_token,
    generate_spotify_authorization_url,
)
from modules.auth.service import upsert_spotify_auth

router = APIRouter(prefix="/auth/spotify", tags=["auth"])


@router.get("/login")
async def spotify_login() -> RedirectResponse:
    return RedirectResponse(url=generate_spotify_authorization_url())


@router.get("/callback")
async def spotify_callback(
    code: str = Query(..., min_length=1),
    state: str | None = Query(None),
    session: AsyncSession = Depends(get_db_session),
) -> RedirectResponse:
    try:
        tokens = await exchange_spotify_code_for_token(code)
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to exchange Spotify authorization code.",
        ) from exc

    user_id: UUID | None = None
    if state:
        try:
            user_id = UUID(state)
        except ValueError:
            user_id = None

    user = await upsert_spotify_auth(session=session, token_data=tokens, user_id=user_id)

    return RedirectResponse(url=f"lyra://callback?token={user.id}")
