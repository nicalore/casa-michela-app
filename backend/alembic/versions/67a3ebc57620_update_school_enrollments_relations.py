"""update school enrollments relations

Revision ID: 67a3ebc57620
Revises: 13422a4def0a
Create Date: 2026-06-20 21:47:11.410034

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '67a3ebc57620'
down_revision: Union[str, Sequence[str], None] = '13422a4def0a'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column('school_enrollments', sa.Column('school_mechanographic_code', sa.String(length=20), nullable=False))
    op.drop_index(op.f('ix_school_enrollments_study_program_id'), table_name='school_enrollments')
    op.drop_constraint(op.f('fk_school_enrollments_study_program_id_study_programs'), 'school_enrollments', type_='foreignkey')
    op.create_foreign_key(op.f('fk_school_enrollments_study_program_id_school_study_programs'), 'school_enrollments', 'school_study_programs', ['study_program_id', 'school_mechanographic_code'], ['study_program_id', 'school_mechanographic_code'], ondelete='RESTRICT')
    op.alter_column('school_study_programs', 'school_mechanographic_code',
               existing_type=sa.VARCHAR(length=255),
               type_=sa.String(length=20),
               existing_nullable=False)


def downgrade() -> None:
    """Downgrade schema."""
    op.alter_column('school_study_programs', 'school_mechanographic_code',
               existing_type=sa.String(length=20),
               type_=sa.VARCHAR(length=255),
               existing_nullable=False)
    op.drop_constraint(op.f('fk_school_enrollments_study_program_id_school_study_programs'), 'school_enrollments', type_='foreignkey')
    op.create_foreign_key(op.f('fk_school_enrollments_study_program_id_study_programs'), 'school_enrollments', 'study_programs', ['study_program_id'], ['id'], ondelete='RESTRICT')
    op.create_index(op.f('ix_school_enrollments_study_program_id'), 'school_enrollments', ['study_program_id'], unique=False)
    op.drop_column('school_enrollments', 'school_mechanographic_code')
