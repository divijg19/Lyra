from typing import Any
from uuid import UUID

from sentence_transformers import SentenceTransformer
from sqlalchemy import select

from core.models.track import Track

# Load once per process so repeated requests/background tasks reuse model memory.
model = SentenceTransformer("all-MiniLM-L6-v2")


def generate_track_embedding(
    title: str,
    artist: str,
    energy: float,
    valence: float,
) -> list[float]:
    text = f"{title} by {artist}. Energy: {energy}, Valence: {valence}"
    return model.encode(text).tolist()


def generate_query_embedding(query: str) -> list[float]:
    return model.encode(query).tolist()


async def vectorize_user_tracks(user_id: UUID, db_session_maker: Any) -> None:
    async with db_session_maker() as session:
        result = await session.scalars(
            select(Track)
            .where(
                Track.user_id == user_id,
                Track.embedding.is_(None),
                Track.bpm.is_not(None),
            )
            .limit(100)
        )
        tracks = list(result.all())
        if not tracks:
            return

        for track in tracks:
            track.embedding = generate_track_embedding(
                title=track.title,
                artist=track.artist or "Unknown Artist",
                energy=float(track.energy) if track.energy is not None else 0.0,
                valence=float(track.valence) if track.valence is not None else 0.0,
            )

        await session.commit()
