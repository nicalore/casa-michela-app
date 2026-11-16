from __future__ import annotations

from datetime import date, datetime

from sqlalchemy import (
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    LargeBinary,
    String,
    func,
)
from sqlalchemy.orm import Mapped, deferred, mapped_column

from app.core import field_lengths
from app.db.base import Base


# The bank transfer that paid a teacher for a month: one per teacher and month,
# replaced when a new one is uploaded.
class PaymentReceipt(Base):
    __tablename__ = "payment_receipts"

    __table_args__ = (
        CheckConstraint(
            "EXTRACT(DAY FROM month) = 1",
            name="payment_receipt_month_first_day",
        ),
        CheckConstraint("size > 0", name="payment_receipt_not_empty"),
    )

    staff_tax_code: Mapped[str] = mapped_column(
        String(16),
        ForeignKey("staff.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        primary_key=True,
    )

    month: Mapped[date] = mapped_column(Date, primary_key=True)

    file_name: Mapped[str] = mapped_column(
        String(field_lengths.FILE_NAME),
        nullable=False,
    )

    content_type: Mapped[str] = mapped_column(String(255), nullable=False)

    size: Mapped[int] = mapped_column(Integer, nullable=False)

    uploaded_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    uploaded_by_tax_code: Mapped[str | None] = mapped_column(
        String(16),
        ForeignKey("people.tax_code", ondelete="SET NULL", onupdate="CASCADE"),
        nullable=True,
    )

    # In the database, not on disk, like the notices' files.
    content: Mapped[bytes] = deferred(mapped_column(LargeBinary, nullable=False))
