"""Database tables. Fields ending in `_enc` hold Fernet-encrypted text."""

import uuid
from datetime import datetime, timezone

from sqlalchemy import (JSON, Boolean, CheckConstraint, DateTime, Float, ForeignKey, Index, Integer, String, Text,
                        UniqueConstraint)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


def new_id() -> str:
    return str(uuid.uuid4())


def now() -> datetime:
    return datetime.now(timezone.utc)


class Base(DeclarativeBase):
    pass


def user_fk() -> Mapped[str]:
    return mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)


class User(Base):
    __tablename__ = "users"
    __table_args__ = (UniqueConstraint("provider", "provider_sub"),
                      CheckConstraint("coins >= 0", name="coins_not_negative"))

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    provider: Mapped[str] = mapped_column(String(16))  # apple | google
    provider_sub: Mapped[str] = mapped_column(String(255))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)
    # 11 가입 동의
    consented_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    marketing_opt_in: Mapped[bool] = mapped_column(Boolean, default=False)
    settings: Mapped[dict] = mapped_column(JSON, default=dict)
    coins: Mapped[int] = mapped_column(Integer, default=0)
    free_telescope_used: Mapped[bool] = mapped_column(Boolean, default=False)


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    token_hash: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[str] = user_fk()
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class Draft(Base):
    """34 임시 저장: one draft per user."""

    __tablename__ = "drafts"

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    mood: Mapped[str] = mapped_column(String(16))
    title_enc: Mapped[str] = mapped_column(Text)
    body_enc: Mapped[str] = mapped_column(Text)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now, onupdate=now)


class Star(Base):
    __tablename__ = "stars"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = user_fk()
    mood: Mapped[str] = mapped_column(String(16))
    title_enc: Mapped[str] = mapped_column(Text)
    body_enc: Mapped[str] = mapped_column(Text)
    state: Mapped[str] = mapped_column(String(8))  # floated | kept
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now, index=True)
    rewrite_of: Mapped[str | None] = mapped_column(ForeignKey("stars.id", ondelete="SET NULL"))
    # Plain numbers for counting; the rest of the analysis is encrypted.
    starlight: Mapped[int | None] = mapped_column(Integer)
    depth_score: Mapped[int | None] = mapped_column(Integer)
    analysis_enc: Mapped[str | None] = mapped_column(Text)
    analysis_failed: Mapped[bool] = mapped_column(Boolean, default=False)
    crisis: Mapped[bool] = mapped_column(Boolean, default=False)


class StarShare(Base):
    """19/20/55: a star given to the plaza. Holds only the masked sentence the owner chose."""

    __tablename__ = "star_shares"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    star_id: Mapped[str] = mapped_column(ForeignKey("stars.id", ondelete="CASCADE"), unique=True)
    user_id: Mapped[str] = user_fk()
    name: Mapped[str] = mapped_column(String(80))
    quote: Mapped[str] = mapped_column(Text)
    mood: Mapped[str] = mapped_column(String(16))
    moods: Mapped[list] = mapped_column(JSON, default=list)
    depth_level: Mapped[int] = mapped_column(Integer)
    shape: Mapped[dict] = mapped_column(JSON)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now, index=True)


class Nebula(Base):
    """51–55, 84, 85: stars joined into a nebula."""

    __tablename__ = "nebulae"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = user_fk()
    name: Mapped[str] = mapped_column(String(40))
    silhouette: Mapped[str | None] = mapped_column(String(16))
    star_ids: Mapped[list] = mapped_column(JSON)
    edges: Mapped[list] = mapped_column(JSON, default=list)
    guest_share_ids: Mapped[list] = mapped_column(JSON, default=list)
    story_bridges: Mapped[list | None] = mapped_column(JSON)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)


class NebulaShare(Base):
    """71 하늘에 띄우기: the nebula's shape goes out; its writing does not."""

    __tablename__ = "nebula_shares"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    nebula_id: Mapped[str] = mapped_column(ForeignKey("nebulae.id", ondelete="CASCADE"), unique=True)
    user_id: Mapped[str] = user_fk()
    name: Mapped[str] = mapped_column(String(40))
    shape: Mapped[dict] = mapped_column(JSON)
    moods: Mapped[list] = mapped_column(JSON, default=list)
    depth_level: Mapped[int] = mapped_column(Integer)
    receive_lines: Mapped[bool] = mapped_column(Boolean, default=True)
    quote: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now, index=True)


class Resonance(Base):
    """공명. Counted for the owner only (Protoss punch concept 6.2)."""

    __tablename__ = "resonances"

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    kind: Mapped[str] = mapped_column(String(8), primary_key=True)  # star | nebula
    target_id: Mapped[str] = mapped_column(String(36), primary_key=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)


class Beside(Base):
    """곁에 둔: someone else's shared star or nebula kept in my collection (79, 80, 85)."""

    __tablename__ = "besides"

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    kind: Mapped[str] = mapped_column(String(8), primary_key=True)
    target_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)


class StarlightLine(Base):
    __tablename__ = "starlight_lines"
    __table_args__ = (UniqueConstraint("share_id", "user_id"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    share_id: Mapped[str] = mapped_column(ForeignKey("nebula_shares.id", ondelete="CASCADE"), index=True)
    user_id: Mapped[str] = user_fk()
    text: Mapped[str] = mapped_column(String(60))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)
    hidden: Mapped[bool] = mapped_column(Boolean, default=False)


class LineReport(Base):
    """100 이 별빛을 신고할까요?"""

    __tablename__ = "line_reports"

    line_id: Mapped[str] = mapped_column(ForeignKey("starlight_lines.id", ondelete="CASCADE"), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    reason: Mapped[str] = mapped_column(String(16))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)


class TelescopeReport(Base):
    __tablename__ = "telescope_reports"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = user_fk()
    star_ids: Mapped[list] = mapped_column(JSON)
    report_enc: Mapped[str] = mapped_column(Text)
    saved: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now, index=True)


class CoinEntry(Base):
    """33 코인 사용 내역. `transaction_id` makes store purchases idempotent."""

    __tablename__ = "coin_entries"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = user_fk()
    title: Mapped[str] = mapped_column(String(40))
    delta: Mapped[int] = mapped_column(Integer)
    transaction_id: Mapped[str | None] = mapped_column(String(128), unique=True)
    # 28 코인 충전: "쓴 코인은 환불되지 않아요 …" agreed at purchase. Only then may a refund
    # request be answered with this purchase's consumption (Apple requires the consent).
    refund_consent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now, index=True)


class Inquiry(Base):
    """32 문의하기"""

    __tablename__ = "inquiries"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = user_fk()
    kind: Mapped[str] = mapped_column(String(16))
    email: Mapped[str] = mapped_column(String(255))
    body_enc: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)


class AdminLog(Base):
    """Every operator read or action is recorded (Protoss concept.md 3장)."""

    __tablename__ = "admin_logs"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    action: Mapped[str] = mapped_column(String(40))
    target_id: Mapped[str | None] = mapped_column(String(36))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now, index=True)


class RateHit(Base):
    """One counted request for the rate limits. Shared by every server instance (Vercel runs many)."""

    __tablename__ = "rate_hits"
    __table_args__ = (Index("ix_rate_hits_key_at", "key", "at"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    key: Mapped[str] = mapped_column(String(200))
    at: Mapped[float] = mapped_column(Float)  # epoch seconds
