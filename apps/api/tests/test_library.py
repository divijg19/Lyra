from __future__ import annotations

from datetime import UTC, datetime

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from core.models.track import Track
from core.models.user import User


def _embedding(index: int) -> list[float]:
    vector = [0.0] * 384
    vector[index] = 1.0
    return vector


@pytest.mark.asyncio
async def test_library_tracks_endpoint_applies_numeric_filters(
    authenticated_client,
    authenticated_user: User,
    db_session: AsyncSession,
) -> None:
    slow_track = Track(
        user_id=authenticated_user.id,
        spotify_id="spotify-slow",
        title="Slow Motion",
        artist="Lyra",
        album="Filters",
        added_at=datetime.now(tz=UTC),
        bpm=110,
        energy=0.4,
        valence=0.3,
        danceability=0.5,
    )
    fast_track = Track(
        user_id=authenticated_user.id,
        spotify_id="spotify-fast",
        title="Fast Lane",
        artist="Lyra",
        album="Filters",
        added_at=datetime.now(tz=UTC),
        bpm=128,
        energy=0.8,
        valence=0.7,
        danceability=0.9,
    )
    db_session.add_all([slow_track, fast_track])
    await db_session.commit()

    response = await authenticated_client.get("/library/tracks?min_bpm=120")

    assert response.status_code == 200
    payload = response.json()
    assert [track["title"] for track in payload] == ["Fast Lane"]


@pytest.mark.asyncio
async def test_semantic_search_returns_tracks_ordered_by_embedding_distance(
    authenticated_client,
    authenticated_user: User,
    db_session: AsyncSession,
) -> None:
    matching_track = Track(
        user_id=authenticated_user.id,
        spotify_id="spotify-match",
        title="North Star",
        artist="Lyra",
        album="Vectors",
        added_at=datetime.now(tz=UTC),
        bpm=120,
        energy=0.6,
        valence=0.5,
        danceability=0.7,
        embedding=_embedding(0),
    )
    distant_track = Track(
        user_id=authenticated_user.id,
        spotify_id="spotify-distant",
        title="Side Quest",
        artist="Lyra",
        album="Vectors",
        added_at=datetime.now(tz=UTC),
        bpm=100,
        energy=0.2,
        valence=0.1,
        danceability=0.2,
        embedding=_embedding(1),
    )
    db_session.add_all([matching_track, distant_track])
    await db_session.commit()

    response = await authenticated_client.get("/library/search/semantic?q=focus")

    assert response.status_code == 200
    payload = response.json()
    assert [track["spotify_id"] for track in payload[:2]] == [
        "spotify-match",
        "spotify-distant",
    ]
