"""Tax code follows the person downstream

Revision ID: a4e1c7d92b05
Revises: f7c2a09e34b8
Create Date: 2026-09-12
"""

import sqlalchemy as sa

from alembic import op

revision = "a4e1c7d92b05"
down_revision = "f7c2a09e34b8"
branch_labels = None
depends_on = None


# Every link in the chain from people down to the role tables cascaded on
# delete but not on update, so correcting a mistyped tax code failed on the
# first account or membership. The leaf tables already cascade both ways.
_FOREIGN_KEYS: tuple[tuple[str, str, str], ...] = (
    ("accounts", "tax_code", "people"),
    ("members", "tax_code", "people"),
    ("parents", "tax_code", "people"),
    ("parental_responsibilities", "child_tax_code", "people"),
    ("parental_responsibilities", "parent_tax_code", "parents"),
    ("students", "tax_code", "members"),
    ("staff", "tax_code", "members"),
    ("memberships", "member_tax_code", "members"),
    ("course_participants", "tax_code", "members"),
    ("psychological_supports", "tax_code", "members"),
    ("teachers", "tax_code", "staff"),
    ("administrators", "tax_code", "staff"),
    ("psychologists", "tax_code", "staff"),
    ("refresh_tokens", "account_tax_code", "accounts"),
)


# Constraints are found by structure, not by name: course_participants was
# renamed from "course_partecipants" and older databases still carry the old
# prefix on its foreign key. Each one is recreated under its canonical name.
def _existing_name(table: str, column: str, referent: str) -> str:
    inspector = sa.inspect(op.get_bind())

    for foreign_key in inspector.get_foreign_keys(table):
        if (
            foreign_key["constrained_columns"] == [column]
            and foreign_key["referred_table"] == referent
        ):
            return foreign_key["name"]

    raise RuntimeError(
        f"Nessuna foreign key da {table}.{column} a {referent}.tax_code: "
        "verificare manualmente prima di procedere."
    )


def _recreate(onupdate: str | None) -> None:
    for table, column, referent in _FOREIGN_KEYS:
        op.drop_constraint(
            _existing_name(table, column, referent),
            table,
            type_="foreignkey",
        )
        op.create_foreign_key(
            op.f(f"fk_{table}_{column}_{referent}"),
            table,
            referent,
            [column],
            ["tax_code"],
            onupdate=onupdate,
            ondelete="CASCADE",
        )


def upgrade() -> None:
    _recreate("CASCADE")


def downgrade() -> None:
    _recreate(None)
