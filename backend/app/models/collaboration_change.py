from sqlalchemy import Boolean, ForeignKey, Integer, event, inspect
from sqlalchemy.orm import Mapped, Session, mapped_column, relationship

from app.db.base import Base
from app.models.flush_state import pending_instances
from app.models.member import Member
from app.models.mixins import CreatedAtMixin


# Each value Member.collaborating_active takes, from the flush hook below:
# a bulk UPDATE of the flag goes unrecorded.
class CollaborationChange(CreatedAtMixin, Base):
    __tablename__ = "collaboration_changes"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    member_tax_code: Mapped[str] = mapped_column(
        ForeignKey("members.tax_code", ondelete="CASCADE", onupdate="CASCADE"),
        nullable=False,
        index=True,
    )

    active: Mapped[bool] = mapped_column(Boolean, nullable=False)

    # Set instead of the key, which a member still being inserted may lack.
    member: Mapped[Member] = relationship()


def _collaboration_set(member: Member) -> bool:
    state = inspect(member)

    return state.pending or state.attrs.collaborating_active.history.has_changes()


@event.listens_for(Session, "before_flush")
def _record_collaboration_changes(
    session: Session,
    _flush_context: object,
    _instances: object,
) -> None:
    for member in pending_instances(session, Member):
        if not _collaboration_set(member):
            continue

        # None until the insert applies the column default, which is true.
        active = member.collaborating_active is not False

        session.add(CollaborationChange(member=member, active=active))
