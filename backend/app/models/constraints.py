from sqlalchemy import CheckConstraint


def no_surrounding_whitespace_constraints(
    *column_names: str,
) -> tuple[CheckConstraint, ...]:
    return tuple(
        CheckConstraint(
            f"{column_name} IS NULL OR {column_name} = btrim({column_name})",
            name=f"{column_name}_no_surrounding_whitespace",
        )
        for column_name in column_names
    )
