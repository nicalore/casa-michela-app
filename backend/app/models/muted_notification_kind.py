from sqlalchemy import Enum as SqlEnum
from sqlalchemy import ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.mixins import CreatedAtMixin
from app.models.notification import NotificationKindEnum


# A kind an account turned off: on every device, and none are filed for it.
class MutedNotificationKind(CreatedAtMixin, Base):
    __tablename__ = "muted_notification_kinds"

    account_tax_code: Mapped[str] = mapped_column(
        ForeignKey("accounts.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        primary_key=True,
    )

    kind: Mapped[NotificationKindEnum] = mapped_column(
        SqlEnum(
            NotificationKindEnum,
            name="notification_kind_enum",
            create_type=False,
        ),
        primary_key=True,
    )
