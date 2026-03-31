from uuid import UUID

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from core.models.playlist import Playlist, PlaylistTrack
from core.models.track import Track


async def create_playlist(
    user_id: UUID,
    name: str,
    description: str | None,
    db: AsyncSession,
) -> Playlist:
    playlist = Playlist(
        user_id=user_id,
        name=name,
        description=description,
    )
    db.add(playlist)
    await db.commit()
    await db.refresh(playlist)
    return playlist


async def get_user_playlists(user_id: UUID, db: AsyncSession) -> list[Playlist]:
    result = await db.scalars(
        select(Playlist)
        .where(Playlist.user_id == user_id)
        .order_by(Playlist.created_at.desc())
    )
    return list(result.all())


async def add_track_to_playlist(
    playlist_id: UUID,
    track_id: UUID,
    user_id: UUID,
    db: AsyncSession,
) -> bool:
    playlist = await db.scalar(
        select(Playlist).where(
            Playlist.id == playlist_id,
            Playlist.user_id == user_id,
        )
    )
    if playlist is None:
        raise ValueError("Playlist not found")

    track = await db.scalar(
        select(Track).where(
            Track.id == track_id,
            Track.user_id == user_id,
        )
    )
    if track is None:
        raise ValueError("Track not found")

    stmt = (
        pg_insert(PlaylistTrack)
        .values(
            playlist_id=playlist_id,
            track_id=track_id,
        )
        .on_conflict_do_nothing(
            index_elements=[PlaylistTrack.playlist_id, PlaylistTrack.track_id]
        )
        .returning(PlaylistTrack.playlist_id)
    )
    result = await db.execute(stmt)
    await db.commit()
    inserted = result.scalar_one_or_none()
    return inserted is not None


async def get_playlist_tracks(
    playlist_id: UUID,
    user_id: UUID,
    db: AsyncSession,
) -> list[Track]:
    playlist = await db.scalar(
        select(Playlist).where(
            Playlist.id == playlist_id,
            Playlist.user_id == user_id,
        )
    )
    if playlist is None:
        raise ValueError("Playlist not found")

    result = await db.scalars(
        select(Track)
        .join(PlaylistTrack, PlaylistTrack.track_id == Track.id)
        .where(
            PlaylistTrack.playlist_id == playlist_id,
            Track.user_id == user_id,
        )
        .order_by(PlaylistTrack.added_at.desc())
    )
    return list(result.all())
