from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Depends, Query
from pydantic import BaseModel, ConfigDict
from sqlalchemy.ext.asyncio import AsyncSession

from core.db.session import AsyncSessionLocal, get_db_session
from core.models.user import User
from core.security.auth import get_current_user
from modules.library.service import (
    enrich_user_tracks,
    get_user_tracks,
    sync_user_library,
)

router = APIRouter(prefix="/library", tags=["library"])


class TrackResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    spotify_id: str
    title: str
    artist: str
    album: str | None
    added_at: datetime
    bpm: float | None
    energy: float | None
    valence: float | None
    danceability: float | None


@router.post("/sync")
async def start_library_sync(
    background_tasks: BackgroundTasks, current_user: User = Depends(get_current_user)
):
    # schedule a background task to perform the sync using a new session maker
    background_tasks.add_task(sync_user_library, current_user.id, AsyncSessionLocal)
    background_tasks.add_task(enrich_user_tracks, current_user.id, AsyncSessionLocal)
    return {"status": "sync_started", "message": "Library is syncing in the background"}


@router.get("/tracks", response_model=list[TrackResponse])
async def list_library_tracks(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
    q: str | None = Query(default=None),
    skip: int = Query(default=0, ge=0),
    limit: int = Query(default=50, ge=1, le=100),
    min_bpm: float | None = Query(default=None),
    max_bpm: float | None = Query(default=None),
    min_energy: float | None = Query(default=None, ge=0.0, le=1.0),
    max_energy: float | None = Query(default=None, ge=0.0, le=1.0),
    min_valence: float | None = Query(default=None, ge=0.0, le=1.0),
    max_valence: float | None = Query(default=None, ge=0.0, le=1.0),
) -> list[TrackResponse]:
    tracks = await get_user_tracks(
        user_id=current_user.id,
        db=db,
        skip=skip,
        limit=limit,
        search_query=q,
        min_bpm=min_bpm,
        max_bpm=max_bpm,
        min_energy=min_energy,
        max_energy=max_energy,
        min_valence=min_valence,
        max_valence=max_valence,
    )
    return [TrackResponse.model_validate(track) for track in tracks]
