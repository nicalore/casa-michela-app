"""Add onupdate cascade to foreign keys


Revision ID: 5851f4355938
Revises: e31d8f9e69d4
Create Date: 2026-06-29 16:48:13.461899

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '5851f4355938'
down_revision: Union[str, Sequence[str], None] = 'e31d8f9e69d4'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.drop_constraint(op.f('fk_ministry_association_subjects_association_subject_id_6b36'), 'ministry_association_subjects', type_='foreignkey')
    op.drop_constraint(op.f('fk_ministry_association_subjects_ministry_subject_id_mi_54a8'), 'ministry_association_subjects', type_='foreignkey')
    op.create_foreign_key(op.f('fk_ministry_association_subjects_ministry_subject_id_ministry_subjects'), 'ministry_association_subjects', 'ministry_subjects', ['ministry_subject_id'], ['id'], onupdate='CASCADE', ondelete='CASCADE')
    op.create_foreign_key(op.f('fk_ministry_association_subjects_association_subject_id_association_subjects'), 'ministry_association_subjects', 'association_subjects', ['association_subject_id'], ['id'], onupdate='CASCADE', ondelete='CASCADE')
    op.drop_constraint(op.f('fk_school_enrollments_study_program_id_school_study_programs'), 'school_enrollments', type_='foreignkey')
    op.drop_constraint(op.f('fk_school_enrollments_student_tax_code_students'), 'school_enrollments', type_='foreignkey')
    op.create_foreign_key(op.f('fk_school_enrollments_study_program_id_school_study_programs'), 'school_enrollments', 'school_study_programs', ['study_program_id', 'school_mechanographic_code'], ['study_program_id', 'school_mechanographic_code'], onupdate='CASCADE', ondelete='RESTRICT')
    op.create_foreign_key(op.f('fk_school_enrollments_student_tax_code_students'), 'school_enrollments', 'students', ['student_tax_code'], ['tax_code'], onupdate='CASCADE', ondelete='CASCADE')
    op.drop_constraint(op.f('fk_school_study_programs_school_mechanographic_code_schools'), 'school_study_programs', type_='foreignkey')
    op.drop_constraint(op.f('fk_school_study_programs_study_program_id_study_programs'), 'school_study_programs', type_='foreignkey')
    op.create_foreign_key(op.f('fk_school_study_programs_school_mechanographic_code_schools'), 'school_study_programs', 'schools', ['school_mechanographic_code'], ['mechanographic_code'], onupdate='CASCADE', ondelete='CASCADE')
    op.create_foreign_key(op.f('fk_school_study_programs_study_program_id_study_programs'), 'school_study_programs', 'study_programs', ['study_program_id'], ['id'], onupdate='CASCADE', ondelete='CASCADE')
    op.drop_constraint(op.f('fk_study_program_subjects_ministry_subject_id_ministry_subjects'), 'study_program_subjects', type_='foreignkey')
    op.drop_constraint(op.f('fk_study_program_subjects_study_program_id_study_programs'), 'study_program_subjects', type_='foreignkey')
    op.create_foreign_key(op.f('fk_study_program_subjects_ministry_subject_id_ministry_subjects'), 'study_program_subjects', 'ministry_subjects', ['ministry_subject_id'], ['id'], onupdate='CASCADE', ondelete='CASCADE')
    op.create_foreign_key(op.f('fk_study_program_subjects_study_program_id_study_programs'), 'study_program_subjects', 'study_programs', ['study_program_id'], ['id'], onupdate='CASCADE', ondelete='CASCADE')
    op.drop_constraint(op.f('fk_teaching_competences_association_subject_id_associat_2ec7'), 'teaching_competences', type_='foreignkey')
    op.drop_constraint(op.f('fk_teaching_competences_study_program_id_study_programs'), 'teaching_competences', type_='foreignkey')
    op.drop_constraint(op.f('fk_teaching_competences_teacher_tax_code_teachers'), 'teaching_competences', type_='foreignkey')
    op.create_foreign_key(op.f('fk_teaching_competences_teacher_tax_code_teachers'), 'teaching_competences', 'teachers', ['teacher_tax_code'], ['tax_code'], onupdate='CASCADE', ondelete='CASCADE')
    op.create_foreign_key(op.f('fk_teaching_competences_association_subject_id_association_subjects'), 'teaching_competences', 'association_subjects', ['association_subject_id'], ['id'], onupdate='CASCADE', ondelete='CASCADE')
    op.create_foreign_key(op.f('fk_teaching_competences_study_program_id_study_programs'), 'teaching_competences', 'study_programs', ['study_program_id'], ['id'], onupdate='CASCADE', ondelete='CASCADE')


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_constraint(op.f('fk_teaching_competences_study_program_id_study_programs'), 'teaching_competences', type_='foreignkey')
    op.drop_constraint(op.f('fk_teaching_competences_association_subject_id_association_subjects'), 'teaching_competences', type_='foreignkey')
    op.drop_constraint(op.f('fk_teaching_competences_teacher_tax_code_teachers'), 'teaching_competences', type_='foreignkey')
    op.create_foreign_key(op.f('fk_teaching_competences_teacher_tax_code_teachers'), 'teaching_competences', 'teachers', ['teacher_tax_code'], ['tax_code'], ondelete='CASCADE')
    op.create_foreign_key(op.f('fk_teaching_competences_study_program_id_study_programs'), 'teaching_competences', 'study_programs', ['study_program_id'], ['id'], ondelete='CASCADE')
    op.create_foreign_key(op.f('fk_teaching_competences_association_subject_id_associat_2ec7'), 'teaching_competences', 'association_subjects', ['association_subject_id'], ['id'], ondelete='CASCADE')
    op.drop_constraint(op.f('fk_study_program_subjects_study_program_id_study_programs'), 'study_program_subjects', type_='foreignkey')
    op.drop_constraint(op.f('fk_study_program_subjects_ministry_subject_id_ministry_subjects'), 'study_program_subjects', type_='foreignkey')
    op.create_foreign_key(op.f('fk_study_program_subjects_study_program_id_study_programs'), 'study_program_subjects', 'study_programs', ['study_program_id'], ['id'], ondelete='CASCADE')
    op.create_foreign_key(op.f('fk_study_program_subjects_ministry_subject_id_ministry_subjects'), 'study_program_subjects', 'ministry_subjects', ['ministry_subject_id'], ['id'], ondelete='CASCADE')
    op.drop_constraint(op.f('fk_school_study_programs_study_program_id_study_programs'), 'school_study_programs', type_='foreignkey')
    op.drop_constraint(op.f('fk_school_study_programs_school_mechanographic_code_schools'), 'school_study_programs', type_='foreignkey')
    op.create_foreign_key(op.f('fk_school_study_programs_study_program_id_study_programs'), 'school_study_programs', 'study_programs', ['study_program_id'], ['id'], ondelete='CASCADE')
    op.create_foreign_key(op.f('fk_school_study_programs_school_mechanographic_code_schools'), 'school_study_programs', 'schools', ['school_mechanographic_code'], ['mechanographic_code'], ondelete='CASCADE')
    op.drop_constraint(op.f('fk_school_enrollments_student_tax_code_students'), 'school_enrollments', type_='foreignkey')
    op.drop_constraint(op.f('fk_school_enrollments_study_program_id_school_study_programs'), 'school_enrollments', type_='foreignkey')
    op.create_foreign_key(op.f('fk_school_enrollments_student_tax_code_students'), 'school_enrollments', 'students', ['student_tax_code'], ['tax_code'], ondelete='CASCADE')
    op.create_foreign_key(op.f('fk_school_enrollments_study_program_id_school_study_programs'), 'school_enrollments', 'school_study_programs', ['study_program_id', 'school_mechanographic_code'], ['study_program_id', 'school_mechanographic_code'], ondelete='RESTRICT')
    op.drop_constraint(op.f('fk_ministry_association_subjects_association_subject_id_association_subjects'), 'ministry_association_subjects', type_='foreignkey')
    op.drop_constraint(op.f('fk_ministry_association_subjects_ministry_subject_id_ministry_subjects'), 'ministry_association_subjects', type_='foreignkey')
    op.create_foreign_key(op.f('fk_ministry_association_subjects_ministry_subject_id_mi_54a8'), 'ministry_association_subjects', 'ministry_subjects', ['ministry_subject_id'], ['id'], ondelete='CASCADE')
    op.create_foreign_key(op.f('fk_ministry_association_subjects_association_subject_id_6b36'), 'ministry_association_subjects', 'association_subjects', ['association_subject_id'], ['id'], ondelete='CASCADE')
