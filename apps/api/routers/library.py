from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Depends, Query
from pydantic import BaseModel, ConfigDict
from sqlalchemy.ext.asyncio import AsyncSession

from core.db.session import AsyncSessionLocal, get_db_session
from core.models.user import User
from core.security.auth import get_current_user
from modules.library.service import get_user_tracks, sync_user_library

router = APIRouter(prefix="/library", tags=["library"])


class TrackResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    spotify_id: str
    title: str
    artist: str
    album: str | None
    added_at: datetime


@router.post("/sync")
async def start_library_sync(
    background_tasks: BackgroundTasks, current_user: User = Depends(get_current_user)
):
    # schedule a background task to perform the sync using a new session maker
    background_tasks.add_task(sync_user_library, current_user.id, AsyncSessionLocal)
    return {"status": "sync_started", "message": "Library is syncing in the background"}


@router.get("/tracks", response_model=list[TrackResponse])
async def list_library_tracks(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
    skip: int = Query(default=0, ge=0),
    limit: int = Query(default=50, ge=1, le=100),
) -> list[TrackResponse]:
    tracks = await get_user_tracks(
        user_id=current_user.id,
        db=db,
        skip=skip,
        limit=limit,
    )
    return [TrackResponse.model_validate(track) for track in tracks]
