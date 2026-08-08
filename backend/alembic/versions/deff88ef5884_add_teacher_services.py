"""add teacher services

Which services a teacher can take on, alongside the disciplines they teach.

The twin of teaching_competences without the study programme: a discipline is
taught differently to a first year and to a fifth, which is why competence is
keyed by programme, but "metodo di studio" is the same help whoever asks for
it. So the key here is just the teacher and the service.

Both foreign keys carry ON UPDATE CASCADE: tax_code and a service's name are
each a mutable natural key, and a rename on either side must not orphan the
rows that point at it.

Revision ID: deff88ef5884
Revises: f205d001bebd
Create Date: 2026-08-04 13:14:18.299539

"""

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision = "deff88ef5884"
down_revision = "f205d001bebd"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "teacher_services",
        sa.Column("teacher_tax_code", sa.String(length=16), nullable=False),
        sa.Column("service_name", sa.String(length=255), nullable=False),
        sa.ForeignKeyConstraint(
            ["teacher_tax_code"],
            ["teachers.tax_code"],
            name=op.f("fk_teacher_services_teacher_tax_code_teachers"),
            onupdate="CASCADE",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["service_name"],
            ["services.name"],
            name=op.f("fk_teacher_services_service_name_services"),
            onupdate="CASCADE",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "teacher_tax_code",
            "service_name",
            name=op.f("pk_teacher_services"),
        ),
    )
    # Per la domanda inversa: chi può seguire questo servizio. teacher_tax_code
    # è già la colonna guida della chiave primaria e non ne ha bisogno.
    op.create_index(
        op.f("ix_teacher_services_service_name"),
        "teacher_services",
        ["service_name"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_teacher_services_service_name"),
        table_name="teacher_services",
    )
    op.drop_table("teacher_services")
