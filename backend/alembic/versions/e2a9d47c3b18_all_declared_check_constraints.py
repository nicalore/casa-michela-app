"""add every check constraint the models declared but the database lacked

Revision ID: e2a9d47c3b18
Revises: b1e7c94af205
Create Date: 2026-08-26

"""

from typing import Final

from alembic import op

revision = "e2a9d47c3b18"
down_revision = "b1e7c94af205"
branch_labels = None
depends_on = None


# Optional text columns: trimmed, and whatever trims to empty becomes NULL.
_TRIM_TO_NULL: Final[tuple[tuple[str, str], ...]] = (
    ("administrators", "other_role"),
    ("people", "profile_image_url"),
    ("schools", "mechanographic_code"),
    ("staff", "iban"),
    ("study_programs", "description"),
)

# Required text columns: trim only. One left empty is surfaced by the guard
# below rather than filled with an invented value.
_TRIM_IN_PLACE: Final[tuple[tuple[str, str], ...]] = (
    ("people", "first_name"),
    ("people", "last_name"),
    ("people", "birth_city"),
    ("people", "email"),
    ("people", "residence_address"),
    ("people", "residence_city"),
    ("people", "residence_street_number"),
    ("people", "residence_type"),
    ("schools", "name"),
    ("schools", "city"),
    ("study_programs", "name"),
)

# Province codes: the existing DB check is ^[A-Za-z]{2}$ while the model wants
# ^[A-Z]{2}$, so lowercase rows can genuinely exist.
_UPPERCASE: Final[tuple[tuple[str, str], ...]] = (
    ("people", "birth_province"),
    ("people", "residence_province"),
)

# An account that never logged in must have a pending password reset. The only
# fix beyond whitespace, and it only adds a reset, never removes protection.
_FIRST_LOGIN_FIX: Final[str] = """
    UPDATE accounts
    SET password_reset_required = TRUE
    WHERE last_login IS NULL AND password_reset_required = FALSE
    """

# Same rule (id > 0) under a name an old migration gave it. Rename, don't
# create: duplicates would both run per write and autogenerate would drop one.
_RENAMES: Final[tuple[tuple[str, str, str], ...]] = (
    (
        "study_programs",
        "ck_study_programs_positive_id",
        "ck_study_programs_positive_study_program_id",
    ),
)

_CHECKS: Final[tuple[tuple[str, str, str], ...]] = (
    (
        "accounts",
        "ck_accounts_first_login_requires_password_reset",
        r"""last_login IS NOT NULL OR password_reset_required = TRUE""",
    ),
    (
        "accounts",
        "ck_accounts_last_login_after_creation",
        r"""last_login IS NULL OR last_login >= created_at""",
    ),
    (
        "accounts",
        "ck_accounts_password_hash_no_surrounding_whitespace",
        r"""password_hash IS NULL OR password_hash = btrim(password_hash)""",
    ),
    (
        "accounts",
        "ck_accounts_password_hash_not_blank",
        r"""length(trim(password_hash)) > 0""",
    ),
    (
        "accounts",
        "ck_accounts_tax_code_no_surrounding_whitespace",
        r"""tax_code IS NULL OR tax_code = btrim(tax_code)""",
    ),
    (
        "accounts",
        "ck_accounts_username_no_surrounding_whitespace",
        r"""username IS NULL OR username = btrim(username)""",
    ),
    (
        "accounts",
        "ck_accounts_username_not_blank",
        r"""length(trim(username)) > 0""",
    ),
    (
        "administrators",
        "ck_administrators_other_role_no_surrounding_whitespace",
        r"""other_role IS NULL OR other_role = btrim(other_role)""",
    ),
    (
        "administrators",
        "ck_administrators_other_role_not_blank",
        r"""other_role IS NULL OR length(trim(other_role)) > 0""",
    ),
    (
        "parental_responsibilities",
        "ck_parental_responsibilities_parent_child_different",
        r"""parent_tax_code <> child_tax_code""",
    ),
    (
        "people",
        "ck_people_birth_city_no_surrounding_whitespace",
        r"""birth_city IS NULL OR birth_city = btrim(birth_city)""",
    ),
    (
        "people",
        "ck_people_birth_city_not_blank",
        r"""length(trim(birth_city)) > 0""",
    ),
    (
        "people",
        "ck_people_birth_province_no_surrounding_whitespace",
        r"""birth_province IS NULL OR birth_province = btrim(birth_province)""",
    ),
    (
        "people",
        "ck_people_birth_province_uppercase",
        r"""birth_province = upper(birth_province)""",
    ),
    (
        "people",
        "ck_people_email_format",
        r"""email ~ '^[A-Za-z0-9.!#$%&''*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$'""",
    ),
    (
        "people",
        "ck_people_email_no_surrounding_whitespace",
        r"""email IS NULL OR email = btrim(email)""",
    ),
    (
        "people",
        "ck_people_first_name_no_surrounding_whitespace",
        r"""first_name IS NULL OR first_name = btrim(first_name)""",
    ),
    (
        "people",
        "ck_people_first_name_not_blank",
        r"""length(trim(first_name)) > 0""",
    ),
    (
        "people",
        "ck_people_last_name_no_surrounding_whitespace",
        r"""last_name IS NULL OR last_name = btrim(last_name)""",
    ),
    (
        "people",
        "ck_people_last_name_not_blank",
        r"""length(trim(last_name)) > 0""",
    ),
    (
        "people",
        "ck_people_phone_no_surrounding_whitespace",
        r"""phone IS NULL OR phone = btrim(phone)""",
    ),
    (
        "people",
        "ck_people_postal_code_no_surrounding_whitespace",
        r"""postal_code IS NULL OR postal_code = btrim(postal_code)""",
    ),
    (
        "people",
        "ck_people_profile_image_url_no_surrounding_whitespace",
        r"""profile_image_url IS NULL OR profile_image_url = btrim(profile_image_url)""",
    ),
    (
        "people",
        "ck_people_profile_image_url_not_blank",
        r"""profile_image_url IS NULL OR length(trim(profile_image_url)) > 0""",
    ),
    (
        "people",
        "ck_people_residence_address_no_surrounding_whitespace",
        r"""residence_address IS NULL OR residence_address = btrim(residence_address)""",
    ),
    (
        "people",
        "ck_people_residence_address_not_blank",
        r"""length(trim(residence_address)) > 0""",
    ),
    (
        "people",
        "ck_people_residence_city_no_surrounding_whitespace",
        r"""residence_city IS NULL OR residence_city = btrim(residence_city)""",
    ),
    (
        "people",
        "ck_people_residence_city_not_blank",
        r"""length(trim(residence_city)) > 0""",
    ),
    (
        "people",
        "ck_people_residence_province_no_surrounding_whitespace",
        r"""residence_province IS NULL OR residence_province = btrim(residence_province)""",
    ),
    (
        "people",
        "ck_people_residence_province_uppercase",
        r"""residence_province = upper(residence_province)""",
    ),
    (
        "people",
        "ck_people_residence_street_number_no_surrounding_whitespace",
        r"""residence_street_number IS NULL OR residence_street_number = btrim(residence_street_number)""",
    ),
    (
        "people",
        "ck_people_residence_street_number_not_blank",
        r"""length(trim(residence_street_number)) > 0""",
    ),
    (
        "people",
        "ck_people_residence_type_no_surrounding_whitespace",
        r"""residence_type IS NULL OR residence_type = btrim(residence_type)""",
    ),
    (
        "people",
        "ck_people_residence_type_not_blank",
        r"""length(trim(residence_type)) > 0""",
    ),
    (
        "people",
        "ck_people_tax_code_format",
        r"""tax_code ~ '^[A-Z]{6}[0-9LMNPQRSTUV]{2}[ABCDEHLMPRST][0-9LMNPQRSTUV]{2}[A-Z][0-9LMNPQRSTUV]{3}[A-Z]$'""",
    ),
    (
        "people",
        "ck_people_tax_code_no_surrounding_whitespace",
        r"""tax_code IS NULL OR tax_code = btrim(tax_code)""",
    ),
    (
        "school_enrollments",
        "ck_school_enrollments_positive_grade",
        r"""grade > 0""",
    ),
    (
        "schools",
        "ck_schools_city_no_surrounding_whitespace",
        r"""city IS NULL OR city = btrim(city)""",
    ),
    (
        "schools",
        "ck_schools_mechanographic_code_no_surrounding_whitespace",
        r"""mechanographic_code IS NULL OR mechanographic_code = btrim(mechanographic_code)""",
    ),
    (
        "schools",
        "ck_schools_name_no_surrounding_whitespace",
        r"""name IS NULL OR name = btrim(name)""",
    ),
    (
        "schools",
        "ck_schools_province_no_surrounding_whitespace",
        r"""province IS NULL OR province = btrim(province)""",
    ),
    (
        "schools",
        "ck_schools_school_city_not_blank",
        r"""length(trim(city)) > 0""",
    ),
    (
        "schools",
        "ck_schools_school_name_not_blank",
        r"""length(trim(name)) > 0""",
    ),
    (
        "staff",
        "ck_staff_iban_no_surrounding_whitespace",
        r"""iban IS NULL OR iban = btrim(iban)""",
    ),
    (
        "staff",
        "ck_staff_iban_not_blank",
        r"""iban IS NULL OR length(trim(iban)) > 0""",
    ),
    (
        "study_programs",
        "ck_study_programs_description_no_surrounding_whitespace",
        r"""description IS NULL OR description = btrim(description)""",
    ),
    (
        "study_programs",
        "ck_study_programs_name_no_surrounding_whitespace",
        r"""name IS NULL OR name = btrim(name)""",
    ),
    (
        "study_programs",
        "ck_study_programs_study_program_description_not_blank",
        r"""description IS NULL OR length(trim(description)) > 0""",
    ),
    (
        "study_programs",
        "ck_study_programs_study_program_level_max_year_match",
        r"""(level = 'PRIMARY_SCHOOL' AND max_year <= 5) OR (level = 'MIDDLE_SCHOOL' AND max_year <= 3) OR (level = 'HIGH_SCHOOL' AND max_year <= 5)""",
    ),
    (
        "study_programs",
        "ck_study_programs_study_program_min_year_valid",
        r"""min_year >= 1""",
    ),
    (
        "study_programs",
        "ck_study_programs_study_program_name_not_blank",
        r"""length(trim(name)) > 0""",
    ),
    (
        "study_programs",
        "ck_study_programs_study_program_years_range_valid",
        r"""min_year <= max_year""",
    ),
)


# Counts rows a constraint would reject, before trying. NOT (condition) is NULL
# where the condition is NULL, so those rows don't count — exactly a CHECK's rule.
_GUARD: Final[str] = """
    DO $$
    DECLARE
        offending bigint;
    BEGIN
        SELECT count(*) INTO offending FROM {table} WHERE NOT ({condition});

        IF offending > 0 THEN
            RAISE EXCEPTION
                'Il vincolo % non si può creare su %: % righe non lo rispettano. Correggerle e rilanciare la migrazione.',
                '{name}', '{table}', offending;
        END IF;
    END $$;
    """


def upgrade() -> None:
    for table, column in _TRIM_TO_NULL:
        op.execute(
            f"""
            UPDATE {table}
            SET {column} = nullif(btrim({column}), '')
            WHERE {column} IS DISTINCT FROM nullif(btrim({column}), '')
            """
        )

    for table, column in _TRIM_IN_PLACE:
        op.execute(
            f"""
            UPDATE {table}
            SET {column} = btrim({column})
            WHERE {column} IS DISTINCT FROM btrim({column})
            """
        )

    for table, column in _UPPERCASE:
        op.execute(
            f"""
            UPDATE {table}
            SET {column} = upper({column})
            WHERE {column} IS DISTINCT FROM upper({column})
            """
        )

    op.execute(_FIRST_LOGIN_FIX)

    # All guards run before any creation: on failure the migration stops having
    # added nothing, and reruns clean once the data is fixed.
    for table, name, condition in _CHECKS:
        op.execute(_GUARD.format(table=table, name=name, condition=condition))

    for table, old_name, new_name in _RENAMES:
        op.execute(f"ALTER TABLE {table} RENAME CONSTRAINT {old_name} TO {new_name}")

    for table, name, condition in _CHECKS:
        op.create_check_constraint(op.f(name), table, condition)


def downgrade() -> None:
    for table, name, _condition in _CHECKS:
        op.drop_constraint(op.f(name), table, type_="check")

    for table, old_name, new_name in _RENAMES:
        op.execute(f"ALTER TABLE {table} RENAME CONSTRAINT {new_name} TO {old_name}")


# Deliberately omitted: ck_people_profile_image_url_format demands http(s) URLs
# while app/core/storage.py writes relative paths, so every upload would violate
# it — resolve that model/code conflict before adding it here.
#
# paid_staff_requires_iban was removed from the model together with this
# migration: being paid and having an IBAN on file are separate things.
