from datetime import datetime
from typing import TYPE_CHECKING
from uuid import UUID, uuid4

from sqlalchemy import DateTime, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from core.models.base import Base

if TYPE_CHECKING:
    from core.models.track import Track
    from core.models.user import User


class PlaylistTrack(Base):
    __tablename__ = "playlist_tracks"

    playlist_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("playlists.id", ondelete="CASCADE"),
        primary_key=True,
    )
    track_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("tracks.id", ondelete="CASCADE"),
        primary_key=True,
    )
    added_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    playlist: Mapped["Playlist"] = relationship(
        "Playlist",
        back_populates="playlist_tracks",
        overlaps="tracks,playlists",
    )
    track: Mapped["Track"] = relationship(
        "Track",
        back_populates="playlist_tracks",
        overlaps="tracks,playlists",
    )


class Playlist(Base):
    __tablename__ = "playlists"

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
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    user: Mapped["User"] = relationship(back_populates="playlists")
    playlist_tracks: Mapped[list["PlaylistTrack"]] = relationship(
        "PlaylistTrack",
        back_populates="playlist",
        cascade="all, delete-orphan",
        overlaps="tracks,playlists",
    )
    tracks: Mapped[list["Track"]] = relationship(
        "Track",
        secondary="playlist_tracks",
        back_populates="playlists",
        overlaps="playlist_tracks,playlist,track",
    )
