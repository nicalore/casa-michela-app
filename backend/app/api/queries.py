from typing import Any

from sqlalchemy import Select, func, select
from sqlalchemy.orm import InstrumentedAttribute


def select_parents_left_without_children(
    parent_column: InstrumentedAttribute[Any],
    child_column: InstrumentedAttribute[Any],
    child_id: int,
) -> Select[Any]:
    # Parents linked to this child that have exactly one child overall: once
    # the child is deleted they would be left with none.
    linked_parents = select(parent_column).where(child_column == child_id)

    return (
        select(parent_column)
        .where(parent_column.in_(linked_parents))
        .group_by(parent_column)
        .having(func.count(child_column) == 1)
    )