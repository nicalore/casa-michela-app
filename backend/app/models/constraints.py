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


def not_blank_constraints(*column_names: str) -> tuple[CheckConstraint, ...]:
    return tuple(
        CheckConstraint(
            f"length(trim({column_name})) > 0",
            name=f"{column_name}_not_blank",
        )
        for column_name in column_names
    )


def not_blank_when_present_constraints(
    *column_names: str,
) -> tuple[CheckConstraint, ...]:
    return tuple(
        CheckConstraint(
            f"{column_name} IS NULL OR length(trim({column_name})) > 0",
            name=f"{column_name}_not_blank",
        )
        for column_name in column_names
    )