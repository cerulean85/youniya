"""Database tables. Fields ending in `_enc` hold Fernet-encrypted text."""

import uuid
from datetime import datetime, timezone

from sqlalchemy import (JSON, Boolean, CheckConstraint, DateTime, Float, ForeignKey, Index, Integer, String, Text,
                        UniqueConstraint, false, true as sa_true)
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
    # 14.3 새 기능·혜택 알림 수신 동의: when given and withdrawn, and the last two-yearly reminder.
    marketing_consented_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    marketing_revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    marketing_reminded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    settings: Mapped[dict] = mapped_column(JSON, default=dict)
    coins: Mapped[int] = mapped_column(Integer, default=0)
    free_telescope_used: Mapped[bool] = mapped_column(Boolean, default=False)  # the sign-up one
    # Free uses (youniya_api/allowance.py): the Korean day and how many free floats it had,
    # and the month whose free telescope was used.
    free_star_day: Mapped[str | None] = mapped_column(String(10))
    free_star_count: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    free_telescope_month: Mapped[str | None] = mapped_column(String(7))
    # 서사 다듬기 was removed on 20261108; the column stays, unused.
    free_story_used: Mapped[bool] = mapped_column(Boolean, default=False, server_default=false())
    # 별지기 멤버십: uses on member_day (Korean day) out of MEMBER_DAILY_LIMIT each.
    member_day: Mapped[str | None] = mapped_column(String(10))
    member_star_count: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    member_telescope_count: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    # Unused since 서사 다듬기 was removed (20261108).
    member_story_count: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    # 별지기 이름 (15장): unique ignoring case (uq_users_nickname_key), shown on the plaza.
    nickname: Mapped[str | None] = mapped_column(String(12))
    nickname_key: Mapped[str | None] = mapped_column(String(12), unique=True)
    nickname_changed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    # 별빛 없이 띄우기 (17.1): UNLIT_PER_DAY a Korean day, free.
    unlit_day: Mapped[str | None] = mapped_column(String(10))
    unlit_count: Mapped[int] = mapped_column(Integer, default=0, server_default="0")


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
    moods: Mapped[list | None] = mapped_column(JSON)  # 17.5, the first is `mood`
    title_enc: Mapped[str] = mapped_column(Text)
    body_enc: Mapped[str] = mapped_column(Text)
    # 11.2 고쳐 쓰기: the star this draft rewrites; floating it links the two.
    source_star_id: Mapped[str | None] = mapped_column(ForeignKey("stars.id", ondelete="SET NULL"))
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
    # When it went up to the sky (written then, or floated later from kept); null while kept.
    floated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), index=True)
    # Set when the owner edits the writing; null for one never edited.
    updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    # 17.6 the prism version that read this star; null for those read before prism-v1-2026-11.
    prism_version: Mapped[str | None] = mapped_column(String(32))
    # 17.5 감정 여러 개, the first is `mood` (the star's colour). Null for stars before 20261109: [mood].
    moods: Mapped[list | None] = mapped_column(JSON)


class StarLink(Base):
    """11.5 별 잇기: two of my stars joined, no direction (star_a < star_b), any number per star."""

    __tablename__ = "star_links"
    __table_args__ = (UniqueConstraint("star_a", "star_b"), CheckConstraint("star_a < star_b"))

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = user_fk()
    star_a: Mapped[str] = mapped_column(ForeignKey("stars.id", ondelete="CASCADE"), index=True)
    star_b: Mapped[str] = mapped_column(ForeignKey("stars.id", ondelete="CASCADE"), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)


class StarShare(Base):
    """19/20/55: a star given to the plaza. Holds only the masked sentence the owner chose."""

    __tablename__ = "star_shares"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    star_id: Mapped[str] = mapped_column(ForeignKey("stars.id", ondelete="CASCADE"), unique=True)
    user_id: Mapped[str] = user_fk()
    name: Mapped[str] = mapped_column(String(80))
    # 대표 문장. Null when an edit took it out of the writing, until the owner picks another.
    quote: Mapped[str | None] = mapped_column(Text)
    # The whole writing goes out too (20261108), contacts masked; only when the owner agreed to it.
    full_text: Mapped[bool] = mapped_column(Boolean, default=False, server_default=false())
    body_masked_enc: Mapped[str | None] = mapped_column(Text)
    receive_lines: Mapped[bool] = mapped_column(Boolean, default=True, server_default=sa_true())  # 10.1
    mood: Mapped[str] = mapped_column(String(16))
    moods: Mapped[list] = mapped_column(JSON, default=list)
    depth_level: Mapped[int] = mapped_column(Integer)
    shape: Mapped[dict] = mapped_column(JSON)
    # Taken down for everyone: three reports, or an operator (101).
    hidden: Mapped[bool] = mapped_column(Boolean, default=False, server_default=false())
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
    # Lines from the removed 서사 다듬기 (20261108): kept in the table, never sent.
    story_bridges: Mapped[list | None] = mapped_column(JSON)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)
    # Set when the nebula is drawn again; null for one never changed.
    updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


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
    # Taken down for everyone: three reports, or an operator (101).
    hidden: Mapped[bool] = mapped_column(Boolean, default=False, server_default=false())
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


class StarLine(Base):
    """10.1 별빛 한 줄 on a star shared to the plaza. Only the star's owner reads it; it stays (no
    fading) and outlives the share. One per person per star."""

    __tablename__ = "star_lines"
    __table_args__ = (UniqueConstraint("star_id", "user_id"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    star_id: Mapped[str] = mapped_column(ForeignKey("stars.id", ondelete="CASCADE"), index=True)
    user_id: Mapped[str] = user_fk()  # who left it
    chip: Mapped[str | None] = mapped_column(String(16))  # LINE_CHIPS key, or null for written words
    text: Mapped[str] = mapped_column(String(60))
    hidden: Mapped[bool] = mapped_column(Boolean, default=False, server_default=false())
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)


class StarLineReport(Base):
    __tablename__ = "star_line_reports"

    line_id: Mapped[str] = mapped_column(ForeignKey("star_lines.id", ondelete="CASCADE"), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    reason: Mapped[str] = mapped_column(String(20))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)


class LineReport(Base):
    """100 이 별빛을 신고할까요?"""

    __tablename__ = "line_reports"

    line_id: Mapped[str] = mapped_column(ForeignKey("starlight_lines.id", ondelete="CASCADE"), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    reason: Mapped[str] = mapped_column(String(16))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)
    # When the reporter was told the outcome (101 "결과를 알림으로 알려 드릴게요"). Told once.
    notified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class ShareReport(Base):
    """신고하기 for a plaza star or nebula, as LineReport is for a line."""

    __tablename__ = "share_reports"

    kind: Mapped[str] = mapped_column(String(8), primary_key=True)  # star | nebula
    target_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    reason: Mapped[str] = mapped_column(String(16))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)
    notified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


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
    # NULL once the account is deleted: store purchases and refunds (rows with a transaction_id) are
    # kept for 5 years under 전자상거래법, cut off from the person (개인정보 처리방침 3).
    user_id: Mapped[str | None] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True,
                                                nullable=True)
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


class DeviceToken(Base):
    """An APNs device token. A device belongs to whoever signed in on it last."""

    __tablename__ = "device_tokens"

    token: Mapped[str] = mapped_column(String(200), primary_key=True)
    user_id: Mapped[str] = user_fk()
    environment: Mapped[str] = mapped_column(String(16))  # "production" | "sandbox"
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now, onupdate=now)


class Block(Base):
    """차단 (App Store 1.2). One-sided to make, two-sided to hide: neither sees the other's shares or lines.
    The blocker never learns who it was; the blocked never learns they were blocked."""

    __tablename__ = "blocks"
    __table_args__ = (UniqueConstraint("blocker_id", "blocked_id"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    blocker_id: Mapped[str] = user_fk()
    blocked_id: Mapped[str] = user_fk()
    source: Mapped[str] = mapped_column(String(16))  # line | star | nebula | star_line: where it was blocked from
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)


class InviteAccount(Base):
    """초대 계정 (App Review): made by an operator, signed in with login and password. No sign-up."""

    __tablename__ = "invite_accounts"

    login: Mapped[str] = mapped_column(String(64), primary_key=True)
    password_hash: Mapped[str] = mapped_column(String(200))  # argon2id
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), unique=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)


class Subscription(Base):
    """별지기 멤버십: one App Store auto-renewable subscription, kept current by Server Notifications."""

    __tablename__ = "subscriptions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = user_fk()
    product_id: Mapped[str] = mapped_column(String(64))
    original_transaction_id: Mapped[str] = mapped_column(String(64), unique=True)
    transaction_id: Mapped[str] = mapped_column(String(64))  # the latest one
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    status: Mapped[str] = mapped_column(String(16))  # active | grace | expired | revoked
    auto_renew: Mapped[bool] = mapped_column(Boolean, default=True)
    environment: Mapped[str] = mapped_column(String(16))  # Production | Sandbox
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now, onupdate=now)


class MonthlyReport(Base):
    """월간 마음 리포트 (Figma 123): one per member per month."""

    __tablename__ = "monthly_reports"
    __table_args__ = (UniqueConstraint("user_id", "month"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = user_fk()
    month: Mapped[str] = mapped_column(String(7))  # YYYY-MM, Korean time
    report_enc: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)


class AiCost(Base):
    """What the model cost for one account in one month (KRW, from usageMetadata)."""

    __tablename__ = "ai_costs"

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    month: Mapped[str] = mapped_column(String(7), primary_key=True)
    krw: Mapped[float] = mapped_column(Float, default=0.0)
    calls: Mapped[int] = mapped_column(Integer, default=0)
    alerted: Mapped[bool] = mapped_column(Boolean, default=False)


class AiCache(Base):
    """An explicit Gemini context cache for one feature's fixed prompt, shared by every instance."""

    __tablename__ = "ai_caches"

    feature: Mapped[str] = mapped_column(String(16), primary_key=True)
    key: Mapped[str] = mapped_column(String(64))  # model + prompt hash: a new prompt or model, a new cache
    name: Mapped[str | None] = mapped_column(String(128))  # None: too small to cache
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
