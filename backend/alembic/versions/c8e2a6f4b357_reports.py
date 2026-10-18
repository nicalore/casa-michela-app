"""Reports kept in the app, the IT manager's role and the news of a new report

Revision ID: c8e2a6f4b357
Revises: c2e7a9f4b158
Create Date: 2026-10-18
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "c8e2a6f4b357"
down_revision = "c2e7a9f4b158"
branch_labels = None
depends_on = None

_KIND = postgresql.ENUM(
    "APP_PROBLEM",
    "PERSONAL_DATA",
    "MISSING_SUBJECT",
    name="report_kind_enum",
    create_type=False,
)


def upgrade() -> None:
    # A new enum value is usable only once the transaction adding it commits.
    with op.get_context().autocommit_block():
        op.execute(
            "ALTER TYPE administrator_role_enum ADD VALUE IF NOT EXISTS 'IT_MANAGER'"
        )
        op.execute(
            "ALTER TYPE notification_kind_enum "
            "ADD VALUE IF NOT EXISTS 'REPORT_RECEIVED'"
        )

    # Written by hand under Other until now.
    op.execute(
        "UPDATE administrators SET role = 'IT_MANAGER', other_role = NULL "
        "WHERE role = 'OTHER' AND lower(trim(other_role)) = 'responsabile it'"
    )

    _KIND.create(op.get_bind(), checkfirst=True)

    op.create_table(
        "reports",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("kind", _KIND, nullable=False),
        sa.Column("reporter_tax_code", sa.String(length=16), nullable=False),
        sa.Column("reporter_role", sa.String(length=30), nullable=True),
        sa.Column("person_tax_code", sa.String(length=16), nullable=True),
        sa.Column("title", sa.String(length=255), nullable=True),
        sa.Column("description", sa.String(length=1000), nullable=True),
        sa.Column(
            "corrections",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=True,
        ),
        sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("resolved_by_tax_code", sa.String(length=16), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "kind <> 'PERSONAL_DATA' "
            "OR (person_tax_code IS NOT NULL AND corrections IS NOT NULL)",
            name=op.f("ck_reports_personal_data_has_corrections"),
        ),
        sa.CheckConstraint(
            "kind <> 'MISSING_SUBJECT' OR title IS NOT NULL",
            name=op.f("ck_reports_missing_subject_has_name"),
        ),
        sa.CheckConstraint(
            "kind <> 'APP_PROBLEM' OR description IS NOT NULL",
            name=op.f("ck_reports_app_problem_has_description"),
        ),
        sa.ForeignKeyConstraint(
            ["reporter_tax_code"],
            ["people.tax_code"],
            name=op.f("fk_reports_reporter_tax_code_people"),
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["person_tax_code"],
            ["people.tax_code"],
            name=op.f("fk_reports_person_tax_code_people"),
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["resolved_by_tax_code"],
            ["people.tax_code"],
            name=op.f("fk_reports_resolved_by_tax_code_people"),
            ondelete="SET NULL",
            onupdate="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_reports")),
    )
    op.create_index(
        op.f("ix_reports_reporter_tax_code"),
        "reports",
        ["reporter_tax_code"],
    )

    op.create_table(
        "report_reads",
        sa.Column("report_id", sa.Integer(), nullable=False),
        sa.Column("account_tax_code", sa.String(length=16), nullable=False),
        sa.Column(
            "read_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["report_id"],
            ["reports.id"],
            name=op.f("fk_report_reads_report_id_reports"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["account_tax_code"],
            ["accounts.tax_code"],
            name=op.f("fk_report_reads_account_tax_code_accounts"),
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "report_id",
            "account_tax_code",
            name=op.f("pk_report_reads"),
        ),
    )

    op.add_column("notifications", sa.Column("report_id", sa.Integer(), nullable=True))
    op.create_foreign_key(
        op.f("fk_notifications_report_id_reports"),
        "notifications",
        "reports",
        ["report_id"],
        ["id"],
        ondelete="CASCADE",
    )
    op.create_index(
        op.f("ix_notifications_report_id"),
        "notifications",
        ["report_id"],
    )
    op.create_index(
        "uq_notifications_report_received",
        "notifications",
        ["account_tax_code", "report_id"],
        unique=True,
        postgresql_where=sa.text("kind = 'REPORT_RECEIVED'"),
    )


# Postgres cannot drop an enum value: IT managers go back under Other.
def downgrade() -> None:
    op.drop_index("uq_notifications_report_received", table_name="notifications")
    op.drop_index(op.f("ix_notifications_report_id"), table_name="notifications")
    op.drop_constraint(
        op.f("fk_notifications_report_id_reports"),
        "notifications",
        type_="foreignkey",
    )
    op.drop_column("notifications", "report_id")
    op.drop_table("report_reads")
    op.drop_index(op.f("ix_reports_reporter_tax_code"), table_name="reports")
    op.drop_table("reports")
    _KIND.drop(op.get_bind(), checkfirst=True)
    op.execute("DELETE FROM notifications WHERE kind = 'REPORT_RECEIVED'")
    op.execute("DELETE FROM muted_notification_kinds WHERE kind = 'REPORT_RECEIVED'")
    op.execute(
        "UPDATE administrators SET role = 'OTHER', other_role = 'Responsabile IT' "
        "WHERE role = 'IT_MANAGER'"
    )
