from fastapi import APIRouter, BackgroundTasks, Depends

from core.db.session import AsyncSessionLocal
from core.models.user import User
from core.security.auth import get_current_user
from modules.library.service import sync_user_library

router = APIRouter(prefix="/library", tags=["library"])


@router.post("/sync")
async def start_library_sync(
    background_tasks: BackgroundTasks, current_user: User = Depends(get_current_user)
):
    # schedule a background task to perform the sync using a new session maker
    background_tasks.add_task(sync_user_library, current_user.id, AsyncSessionLocal)
    return {"status": "sync_started", "message": "Library is syncing in the background"}
