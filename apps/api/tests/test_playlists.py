from __future__ import annotations

from datetime import UTC, datetime

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from core.models.track import Track
from core.models.user import User


async def _create_track_for_user(
    db_session: AsyncSession,
    user: User,
    *,
    spotify_id: str,
    title: str,
) -> Track:
    track = Track(
        user_id=user.id,
        spotify_id=spotify_id,
        title=title,
        artist="Lyra",
        album="Playlists",
        added_at=datetime.now(tz=UTC),
    )
    db_session.add(track)
    await db_session.commit()
    await db_session.refresh(track)
    return track


@pytest.mark.asyncio
async def test_playlist_crud_flow(
    authenticated_client,
    authenticated_user: User,
    db_session: AsyncSession,
) -> None:
    track = await _create_track_for_user(
        db_session,
        authenticated_user,
        spotify_id="spotify-playlist-track",
        title="Orbit",
    )

    create_response = await authenticated_client.post(
        "/playlists",
        json={"name": "Focus", "description": "Deep work queue"},
    )
    assert create_response.status_code == 201
    playlist = create_response.json()

    add_response = await authenticated_client.post(
        f"/playlists/{playlist['id']}/tracks",
        json={"track_id": str(track.id)},
    )
    assert add_response.status_code == 200
    assert add_response.json() == {"status": "track_added"}

    tracks_response = await authenticated_client.get(
        f"/playlists/{playlist['id']}/tracks"
    )
    assert tracks_response.status_code == 200
    assert [item["id"] for item in tracks_response.json()] == [str(track.id)]

    delete_response = await authenticated_client.delete(f"/playlists/{playlist['id']}")
    assert delete_response.status_code == 204

    list_response = await authenticated_client.get("/playlists")
    assert list_response.status_code == 200
    assert list_response.json() == []


@pytest.mark.asyncio
async def test_duplicate_playlist_track_returns_conflict(
    authenticated_client,
    authenticated_user: User,
    db_session: AsyncSession,
) -> None:
    track = await _create_track_for_user(
        db_session,
        authenticated_user,
        spotify_id="spotify-duplicate-track",
        title="Echo",
    )
    playlist_response = await authenticated_client.post(
        "/playlists",
        json={"name": "Duplicates"},
    )
    playlist_id = playlist_response.json()["id"]

    first_add = await authenticated_client.post(
        f"/playlists/{playlist_id}/tracks",
        json={"track_id": str(track.id)},
    )
    second_add = await authenticated_client.post(
        f"/playlists/{playlist_id}/tracks",
        json={"track_id": str(track.id)},
    )

    assert first_add.status_code == 200
    assert second_add.status_code == 409
    assert second_add.json() == {"detail": "Track already in playlist"}
