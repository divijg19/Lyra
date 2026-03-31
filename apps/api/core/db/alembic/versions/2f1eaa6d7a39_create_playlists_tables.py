"""create playlists tables

Revision ID: 2f1eaa6d7a39
Revises: cdd83355e96a
Create Date: 2026-03-31 20:15:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "2f1eaa6d7a39"
down_revision: Union[str, Sequence[str], None] = "cdd83355e96a"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "playlists",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("description", sa.String(length=1024), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_playlists_user_id"), "playlists", ["user_id"], unique=False
    )

    op.create_table(
        "playlist_tracks",
        sa.Column("playlist_id", sa.UUID(), nullable=False),
        sa.Column("track_id", sa.UUID(), nullable=False),
        sa.Column(
            "added_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["playlist_id"], ["playlists.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["track_id"], ["tracks.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("playlist_id", "track_id"),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_table("playlist_tracks")
    op.drop_index(op.f("ix_playlists_user_id"), table_name="playlists")
    op.drop_table("playlists")
