from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.ext.asyncio import AsyncSession

from core.db.session import get_db_session
from core.models.user import User
from core.security.auth import get_current_user
from modules.playlist.service import (
    add_track_to_playlist,
    create_playlist,
    get_playlist_tracks,
    get_user_playlists,
)

router = APIRouter(prefix="/playlists", tags=["playlists"])


class CreatePlaylistRequest(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    description: str | None = Field(default=None, max_length=1024)


class PlaylistResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    name: str
    description: str | None
    created_at: datetime


class AddTrackRequest(BaseModel):
    track_id: UUID


class PlaylistTrackResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    spotify_id: str
    title: str
    artist: str
    album: str | None
    added_at: datetime | None


@router.post("", response_model=PlaylistResponse, status_code=status.HTTP_201_CREATED)
async def create_user_playlist(
    payload: CreatePlaylistRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> PlaylistResponse:
    playlist = await create_playlist(
        user_id=current_user.id,
        name=payload.name,
        description=payload.description,
        db=db,
    )
    return PlaylistResponse.model_validate(playlist)


@router.get("", response_model=list[PlaylistResponse])
async def list_user_playlists(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> list[PlaylistResponse]:
    playlists = await get_user_playlists(user_id=current_user.id, db=db)
    return [PlaylistResponse.model_validate(playlist) for playlist in playlists]


@router.post("/{playlist_id}/tracks")
async def add_track(
    playlist_id: UUID,
    payload: AddTrackRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> dict[str, str]:
    try:
        inserted = await add_track_to_playlist(
            playlist_id=playlist_id,
            track_id=payload.track_id,
            user_id=current_user.id,
            db=db,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc

    if inserted:
        return {"status": "track_added"}
    return {"status": "track_already_in_playlist"}


@router.get("/{playlist_id}/tracks", response_model=list[PlaylistTrackResponse])
async def list_playlist_tracks(
    playlist_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> list[PlaylistTrackResponse]:
    try:
        tracks = await get_playlist_tracks(
            playlist_id=playlist_id,
            user_id=current_user.id,
            db=db,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc

    return [PlaylistTrackResponse.model_validate(track) for track in tracks]
