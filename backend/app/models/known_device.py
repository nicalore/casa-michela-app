from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.db.base import Base


# A browser or app an account signed in from, known by the code it keeps, hashed.
class KnownDevice(Base):
    __tablename__ = "known_devices"

    __table_args__ = (UniqueConstraint("account_tax_code", "key_hash"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    account_tax_code: Mapped[str] = mapped_column(
        ForeignKey("accounts.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        nullable=False,
        index=True,
    )

    key_hash: Mapped[str] = mapped_column(String(64), nullable=False)

    first_seen_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
