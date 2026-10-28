from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


# An IT manager's request that everyone accept the legal documents again.
# Only the newest counts: one acceptance after it covers all the older ones.
class TermsRequest(Base):
    __tablename__ = "terms_requests"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    # Written by the app, like the acceptances it is compared with.
    requested_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        index=True,
    )

    author_tax_code: Mapped[str | None] = mapped_column(
        # tax_code is a mutable natural key, so onupdate is required here.
        ForeignKey("people.tax_code", ondelete="SET NULL", onupdate="CASCADE"),
        nullable=True,
    )


# Every acceptance, as proof of who accepted when; the account keeps the latest.
class TermsAcceptance(Base):
    __tablename__ = "terms_acceptances"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    account_tax_code: Mapped[str] = mapped_column(
        ForeignKey("accounts.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        nullable=False,
        index=True,
    )

    accepted_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )
