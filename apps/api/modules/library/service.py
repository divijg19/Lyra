from datetime import datetime
from typing import Any
from uuid import UUID

from sqlalchemy import or_, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from core.models.spotify import SpotifyAuth
from core.models.track import Track

from integrations.spotify.client import fetch_audio_features, fetch_saved_tracks


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
                if added_at is None:
                    continue

                artists = [
                    a.get("name") for a in track.get("artists", []) if a.get("name")
                ]
                artist = ", ".join(artists) if artists else "Unknown Artist"

                rows.append(
                    {
                        "user_id": user_id,
                        "spotify_id": spotify_id,
                        "title": title,
                        "artist": artist,
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


async def enrich_user_tracks(user_id: UUID, db_session_maker: Any) -> None:
    """Populate audio features for up to 100 user tracks missing enrichment."""
    async with db_session_maker() as session:  # type: AsyncSession
        auth = await session.scalar(
            select(SpotifyAuth).where(SpotifyAuth.user_id == user_id)
        )
        if auth is None:
            return

        tracks_result = await session.scalars(
            select(Track)
            .where(
                Track.user_id == user_id,
                Track.bpm.is_(None),
            )
            .limit(100)
        )
        tracks = list(tracks_result.all())
        if not tracks:
            return

        track_by_spotify_id = {track.spotify_id: track for track in tracks}
        spotify_ids = list(track_by_spotify_id.keys())
        features = await fetch_audio_features(auth.access_token, spotify_ids)

        for feature in features:
            spotify_id = feature.get("id")
            if not spotify_id:
                continue

            track = track_by_spotify_id.get(spotify_id)
            if track is None:
                continue

            # Spotify sends tempo; we store it as BPM.
            track.bpm = feature.get("tempo")
            track.energy = feature.get("energy")
            track.valence = feature.get("valence")
            track.danceability = feature.get("danceability")

        await session.commit()


async def get_user_tracks(
    user_id: UUID,
    db: AsyncSession,
    skip: int = 0,
    limit: int = 50,
    search_query: str | None = None,
    min_bpm: float | None = None,
    max_bpm: float | None = None,
    min_energy: float | None = None,
    max_energy: float | None = None,
    min_valence: float | None = None,
    max_valence: float | None = None,
) -> list[Track]:
    stmt = select(Track).where(
        Track.user_id == user_id,
        Track.added_at.is_not(None),
        Track.artist.is_not(None),
    )

    if search_query:
        stmt = stmt.where(
            or_(
                Track.title.ilike(f"%{search_query}%"),
                Track.artist.ilike(f"%{search_query}%"),
            )
        )

    if min_bpm is not None:
        stmt = stmt.where(Track.bpm >= min_bpm)
    if max_bpm is not None:
        stmt = stmt.where(Track.bpm <= max_bpm)

    if min_energy is not None:
        stmt = stmt.where(Track.energy >= min_energy)
    if max_energy is not None:
        stmt = stmt.where(Track.energy <= max_energy)

    if min_valence is not None:
        stmt = stmt.where(Track.valence >= min_valence)
    if max_valence is not None:
        stmt = stmt.where(Track.valence <= max_valence)

    stmt = stmt.order_by(Track.added_at.desc()).offset(skip).limit(limit)
    result = await db.scalars(stmt)
    return list(result.all())


def _parse_spotify_datetime(value: Any) -> datetime | None:
    if not isinstance(value, str) or not value:
        return None

    # Spotify timestamps are ISO-8601 and commonly end with "Z".
    normalized = value.replace("Z", "+00:00")
    try:
        return datetime.fromisoformat(normalized)
    except ValueError:
        return None
