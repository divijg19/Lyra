from typing import Any
from uuid import UUID

from sqlalchemy import insert
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from core.models.spotify import SpotifyAuth
from core.models.track import Track

from integrations.spotify.client import fetch_saved_tracks


async def sync_user_library(user_id: UUID, db_session_maker: Any) -> None:
    """Sync a user's Spotify saved tracks into the local DB.

    This function is safe to run inside BackgroundTasks because it creates
    its own session from the provided session maker.
    """
    async with db_session_maker() as session:  # type: AsyncSession
        # load spotify auth
        auth = await session.scalar(
            SpotifyAuth.__table__.select().where(SpotifyAuth.user_id == user_id)
        )
        # If not using scalar with select, fallback to get
        if auth is None:
            auth = await session.scalar(
                SpotifyAuth.__table__.select().where(SpotifyAuth.user_id == user_id)
            )

        if auth is None:
            return

        access_token = auth.access_token

        async for items in fetch_saved_tracks(access_token):
            # transform items into rows
            rows = []
            for item in items:
                track = item.get("track") or {}
                rows.append(
                    {
                        "user_id": user_id,
                        "spotify_id": track.get("id"),
                        "title": track.get("name"),
                        "artist": ", ".join(
                            [a.get("name") for a in track.get("artists", [])]
                        )
                        if track.get("artists")
                        else None,
                        "album": track.get("album", {}).get("name"),
                        "added_at": item.get("added_at"),
                    }
                )

            if not rows:
                continue

            stmt = pg_insert(Track).values(rows)
            update_cols = {
                "title": stmt.excluded.title,
                "artist": stmt.excluded.artist,
                "album": stmt.excluded.album,
                "added_at": stmt.excluded.added_at,
            }
            stmt = stmt.on_conflict_do_update(
                index_elements=[
                    Track.__table__.c.user_id,
                    Track.__table__.c.spotify_id,
                ],
                set_=update_cols,
            )

            await session.execute(stmt)
            await session.commit()
