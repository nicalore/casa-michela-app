from datetime import datetime
from enum import StrEnum
from typing import Any

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Integer, String
from sqlalchemy import Enum as SqlEnum
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.core import field_lengths
from app.db.base import Base
from app.models.mixins import CreatedAtMixin


class ReportKindEnum(StrEnum):
    APP_PROBLEM = "APP_PROBLEM"
    PERSONAL_DATA = "PERSONAL_DATA"
    MISSING_SUBJECT = "MISSING_SUBJECT"


# What a member sent in from the app; kept until somebody marks it resolved.
class Report(CreatedAtMixin, Base):
    __tablename__ = "reports"

    __table_args__ = (
        CheckConstraint(
            "kind <> 'PERSONAL_DATA' "
            "OR (person_tax_code IS NOT NULL AND corrections IS NOT NULL)",
            name="personal_data_has_corrections",
        ),
        CheckConstraint(
            "kind <> 'MISSING_SUBJECT' OR title IS NOT NULL",
            name="missing_subject_has_name",
        ),
        CheckConstraint(
            "kind <> 'APP_PROBLEM' OR description IS NOT NULL",
            name="app_problem_has_description",
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    kind: Mapped[ReportKindEnum] = mapped_column(
        SqlEnum(ReportKindEnum, name="report_kind_enum"),
        nullable=False,
    )

    reporter_tax_code: Mapped[str] = mapped_column(
        # tax_code is a mutable natural key, so onupdate is required here.
        ForeignKey("people.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        nullable=False,
        index=True,
    )

    # The hat worn when sending, as a role code.
    reporter_role: Mapped[str | None] = mapped_column(String(30))

    # Whose personal data is wrong: the reporter, a child of theirs, anyone for admins.
    person_tax_code: Mapped[str | None] = mapped_column(
        # tax_code is a mutable natural key, so onupdate is required here.
        ForeignKey("people.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
    )

    # The discipline missing.
    title: Mapped[str | None] = mapped_column(String(field_lengths.NAME))

    description: Mapped[str | None] = mapped_column(String(field_lengths.DESCRIPTION))

    # In the order asked: [{"field": label, "value": the right one}, ...].
    corrections: Mapped[list[dict[str, Any]] | None] = mapped_column(JSONB)

    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    resolved_by_tax_code: Mapped[str | None] = mapped_column(
        # tax_code is a mutable natural key, so onupdate is required here.
        ForeignKey("people.tax_code", ondelete="SET NULL", onupdate="CASCADE"),
    )


# Read is each reader's own: one opening it leaves it new for the others.
class ReportRead(Base):
    __tablename__ = "report_reads"

    report_id: Mapped[int] = mapped_column(
        ForeignKey("reports.id", ondelete="CASCADE"),
        primary_key=True,
    )

    account_tax_code: Mapped[str] = mapped_column(
        ForeignKey("accounts.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        primary_key=True,
    )

    read_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
