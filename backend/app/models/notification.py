from datetime import date, datetime
from enum import StrEnum
from typing import Any, Final

from sqlalchemy import (
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    text,
)
from sqlalchemy import Enum as SqlEnum
from sqlalchemy.dialects.postgresql import ARRAY, JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.constraints import (
    not_blank_constraints,
    not_blank_when_present_constraints,
)
from app.models.mixins import CreatedAtMixin

NOTIFICATION_TITLE_LENGTH: Final[int] = 120
NOTIFICATION_BODY_LENGTH: Final[int] = 500


class NotificationKindEnum(StrEnum):
    TEST = "TEST"
    BOOKINGS_CLOSED = "BOOKINGS_CLOSED"
    CALENDAR_PUBLISHED = "CALENDAR_PUBLISHED"
    CONVOCATION = "CONVOCATION"
    ARRIVAL_REMINDER = "ARRIVAL_REMINDER"
    AVAILABILITY_OPENED = "AVAILABILITY_OPENED"
    BOOKINGS_OPENED = "BOOKINGS_OPENED"
    AVAILABILITY_REMINDER = "AVAILABILITY_REMINDER"
    BOOKING_REMINDER = "BOOKING_REMINDER"
    OPENING_HOURS_CHANGED = "OPENING_HOURS_CHANGED"
    NOTICE_RECEIVED = "NOTICE_RECEIVED"
    BOOKING_ADDED = "BOOKING_ADDED"
    BOOKING_CANCELLED = "BOOKING_CANCELLED"
    BOOKING_CHANGED = "BOOKING_CHANGED"
    AVAILABILITY_ADDED = "AVAILABILITY_ADDED"
    AVAILABILITY_CHANGED = "AVAILABILITY_CHANGED"
    AVAILABILITY_CANCELLED = "AVAILABILITY_CANCELLED"
    NEW_DEVICE = "NEW_DEVICE"
    REPORT_RECEIVED = "REPORT_RECEIVED"
    RATING_REMINDER = "RATING_REMINDER"


# What an account was told; the home card lists these, a push only announces one.
class Notification(CreatedAtMixin, Base):
    __tablename__ = "notifications"

    __table_args__ = (
        *not_blank_constraints("title", "body"),
        *not_blank_when_present_constraints("web_body"),
        CheckConstraint(
            "calendar_band IS NULL "
            "OR calendar_band IN ('MORNING', 'AFTERNOON', 'EVENING')",
            name="calendar_band_valid",
        ),
        # A band needs its day; a day alone is a kind about days, not bands.
        CheckConstraint(
            "calendar_band IS NULL OR calendar_date IS NOT NULL",
            name="calendar_band_with_date",
        ),
        # Kept once withdrawn too: a band unpublished later is not announced again.
        Index(
            "uq_notifications_bookings_closed",
            "account_tax_code",
            "calendar_date",
            "calendar_band",
            unique=True,
            postgresql_where=text("kind = 'BOOKINGS_CLOSED'"),
        ),
        # One reminder per teacher and band, however often the calendar changes.
        Index(
            "uq_notifications_arrival_reminder",
            "account_tax_code",
            "calendar_date",
            "calendar_band",
            unique=True,
            postgresql_where=text("kind = 'ARRIVAL_REMINDER'"),
        ),
        # Once per account and week, the week told by the Monday it expires at.
        Index(
            "uq_notifications_week_opened",
            "account_tax_code",
            "kind",
            "expires_at",
            unique=True,
            postgresql_where=text(
                "kind IN ('AVAILABILITY_OPENED', 'BOOKINGS_OPENED')"
            ),
        ),
        # Once per account and evening, the day told by the midnight it expires at.
        Index(
            "uq_notifications_daily_reminder",
            "account_tax_code",
            "kind",
            "expires_at",
            unique=True,
            postgresql_where=text(
                "kind IN ('AVAILABILITY_REMINDER', 'BOOKING_REMINDER')"
            ),
        ),
        # Once per account and notice: an edit tells only those it newly reaches.
        Index(
            "uq_notifications_notice_received",
            "account_tax_code",
            "notice_id",
            unique=True,
            postgresql_where=text("kind = 'NOTICE_RECEIVED'"),
        ),
        Index(
            "uq_notifications_report_received",
            "account_tax_code",
            "report_id",
            unique=True,
            postgresql_where=text("kind = 'REPORT_RECEIVED'"),
        ),
        # Kept once withdrawn too: a teacher's rating is asked for only once.
        Index(
            "uq_notifications_rating_reminder",
            "account_tax_code",
            "teacher_tax_code",
            unique=True,
            postgresql_where=text("kind = 'RATING_REMINDER'"),
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    account_tax_code: Mapped[str] = mapped_column(
        ForeignKey("accounts.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        nullable=False,
        index=True,
    )

    kind: Mapped[NotificationKindEnum] = mapped_column(
        SqlEnum(NotificationKindEnum, name="notification_kind_enum"),
        nullable=False,
    )

    title: Mapped[str] = mapped_column(
        String(NOTIFICATION_TITLE_LENGTH),
        nullable=False,
    )

    body: Mapped[str] = mapped_column(String(NOTIFICATION_BODY_LENGTH), nullable=False)

    # The desktop's wording where it differs: "Clicca" for the phone's "Tocca".
    web_body: Mapped[str | None] = mapped_column(String(NOTIFICATION_BODY_LENGTH))

    # The band of the calendar it is about, or just the first day, for kinds about one.
    calendar_date: Mapped[date | None] = mapped_column(Date)

    calendar_band: Mapped[str | None] = mapped_column(String(20))

    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    # Gone from the home card: what it asked for no longer needs doing.
    withdrawn_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    # Withdrawn by itself at this moment, for kinds that only hold until then.
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    # The notice it announces; withdrawn before the notice goes, then gone with it.
    notice_id: Mapped[int | None] = mapped_column(
        ForeignKey("notices.id", ondelete="CASCADE"),
        index=True,
    )

    # The report it announces; gone with it.
    report_id: Mapped[int | None] = mapped_column(
        ForeignKey("reports.id", ondelete="CASCADE"),
        index=True,
    )

    # The pupil whose bookings it is about, and who wrote what it tells of.
    pupil_tax_code: Mapped[str | None] = mapped_column(
        # tax_code is a mutable natural key, so onupdate is required here.
        ForeignKey("people.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        index=True,
    )

    author_tax_code: Mapped[str | None] = mapped_column(
        # tax_code is a mutable natural key, so onupdate is required here.
        ForeignKey("people.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
    )

    # The teacher whose rating it asks to update.
    teacher_tax_code: Mapped[str | None] = mapped_column(
        # tax_code is a mutable natural key, so onupdate is required here.
        ForeignKey("people.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        index=True,
    )

    # The lessons or availabilities it tells of: no key, so one deleted is still found.
    item_ids: Mapped[list[int] | None] = mapped_column(ARRAY(Integer))

    # What its reader knew before the news it tells, so news undone can take it away:
    # each item's day and earlier shape, or the calendar band's earlier view.
    known: Mapped[dict[str, Any] | None] = mapped_column(JSONB)
