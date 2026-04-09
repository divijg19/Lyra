from datetime import datetime
from typing import TYPE_CHECKING
from uuid import UUID, uuid4

from pgvector.sqlalchemy import Vector
from sqlalchemy import DateTime, Float, ForeignKey, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from core.models.base import Base

if TYPE_CHECKING:
    from core.models.playlist import Playlist, PlaylistTrack
    from core.models.user import User


class Track(Base):
    __tablename__ = "tracks"
    __table_args__ = (
        UniqueConstraint("user_id", "spotify_id", name="uq_user_spotify_track"),
    )

    id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    user_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    spotify_id: Mapped[str] = mapped_column(String(128), nullable=False)
    title: Mapped[str] = mapped_column(String(512), nullable=False)
    artist: Mapped[str | None] = mapped_column(String(512), nullable=True)
    album: Mapped[str | None] = mapped_column(String(512), nullable=True)
    added_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    bpm: Mapped[float | None] = mapped_column(Float, nullable=True)
    energy: Mapped[float | None] = mapped_column(Float, nullable=True)
    valence: Mapped[float | None] = mapped_column(Float, nullable=True)
    danceability: Mapped[float | None] = mapped_column(Float, nullable=True)
    embedding: Mapped[list[float] | None] = mapped_column(Vector(384), nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    user: Mapped["User"] = relationship(back_populates="tracks")
    playlist_tracks: Mapped[list["PlaylistTrack"]] = relationship(
        "PlaylistTrack",
        back_populates="track",
        cascade="all, delete-orphan",
        overlaps="playlists,tracks",
    )
    playlists: Mapped[list["Playlist"]] = relationship(
        "Playlist",
        secondary="playlist_tracks",
        back_populates="tracks",
        overlaps="playlist_tracks,playlist,track",
    )
