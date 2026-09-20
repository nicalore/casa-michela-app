from typing import Any

from sqlalchemy import ColumnElement, Select, func, select
from sqlalchemy.orm import InstrumentedAttribute


def select_parents_left_without_children(
    parent_column: InstrumentedAttribute[Any],
    child_column: InstrumentedAttribute[Any],
    child_id: int,
    *,
    only: ColumnElement[bool] | None = None,
) -> Select[Any]:
    # Parents whose only child this is; `only` narrows the links that count.
    linked_parents = select(parent_column).where(child_column == child_id)
    counted = select(parent_column)

    if only is not None:
        linked_parents = linked_parents.where(only)
        counted = counted.where(only)

    return (
        counted.where(parent_column.in_(linked_parents))
        .group_by(parent_column)
        .having(func.count(child_column) == 1)
    )