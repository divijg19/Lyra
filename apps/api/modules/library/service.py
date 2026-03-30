from datetime import datetime
from typing import Any
from uuid import UUID

from sqlalchemy import select
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
        auth = await session.scalar(
            select(SpotifyAuth).where(SpotifyAuth.user_id == user_id)
        )

        if auth is None:
            return

        access_token = auth.access_token

        async for items in fetch_saved_tracks(access_token):
            rows: list[dict[str, Any]] = []
            for item in items:
                track = item.get("track") or {}
                spotify_id = track.get("id")
                title = track.get("name")
                if not spotify_id or not title:
                    continue

                added_at_raw = item.get("added_at")
                added_at = _parse_spotify_datetime(added_at_raw)

                rows.append(
                    {
                        "user_id": user_id,
                        "spotify_id": spotify_id,
                        "title": title,
                        "artist": ", ".join(
                            [a.get("name") for a in track.get("artists", [])]
                        )
                        if track.get("artists")
                        else None,
                        "album": track.get("album", {}).get("name"),
                        "added_at": added_at,
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
                constraint="uq_user_spotify_track",
                set_=update_cols,
            )

            await session.execute(stmt)

        await session.commit()


def _parse_spotify_datetime(value: Any) -> datetime | None:
    if not isinstance(value, str) or not value:
        return None

    # Spotify timestamps are ISO-8601 and commonly end with "Z".
    normalized = value.replace("Z", "+00:00")
    try:
        return datetime.fromisoformat(normalized)
    except ValueError:
        return None
