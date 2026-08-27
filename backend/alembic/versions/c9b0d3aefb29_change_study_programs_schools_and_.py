"""change study programs, schools, and subjects models. Add teaching competences model

Revision ID: c9b0d3aefb29
Revises: a028c0f3a0d2
Create Date: 2026-06-17 23:22:50.239461

"""
from typing import Sequence, Union

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

# revision identifiers, used by Alembic.
revision: str = 'c9b0d3aefb29'
down_revision: Union[str, Sequence[str], None] = 'a028c0f3a0d2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    
    # Existing rows are dummy data: wipe them so the new NOT NULL columns
    # can be added without violations.
    op.execute("TRUNCATE TABLE study_programs, school_enrollments, teaching_competences CASCADE;")

    op.create_table('association_subjects',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('name', sa.String(length=255), nullable=False),
    sa.Column('description', sa.String(length=1000), nullable=True),
    sa.CheckConstraint('\n            description IS NULL\n            OR length(trim(description)) > 0\n            ', name=op.f('ck_association_subjects_association_subject_description_not_blank')),
    sa.CheckConstraint('description IS NULL OR description = btrim(description)', name=op.f('ck_association_subjects_description_no_surrounding_whitespace')),
    sa.CheckConstraint('id > 0', name=op.f('ck_association_subjects_positive_association_subject_id')),
    sa.CheckConstraint('length(trim(name)) > 0', name=op.f('ck_association_subjects_association_subject_name_not_blank')),
    sa.CheckConstraint('name IS NULL OR name = btrim(name)', name=op.f('ck_association_subjects_name_no_surrounding_whitespace')),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_association_subjects')),
    sa.UniqueConstraint('name', name='uq_association_subject_name')
    )
    
    op.create_table('ministry_subjects',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('name', sa.String(length=255), nullable=False),
    sa.Column('description', sa.String(length=1000), nullable=True),
    sa.CheckConstraint('\n            description IS NULL\n            OR length(trim(description)) > 0\n            ', name=op.f('ck_ministry_subjects_ministry_subject_description_not_blank')),
    sa.CheckConstraint('description IS NULL OR description = btrim(description)', name=op.f('ck_ministry_subjects_description_no_surrounding_whitespace')),
    sa.CheckConstraint('id > 0', name=op.f('ck_ministry_subjects_positive_ministry_subject_id')),
    sa.CheckConstraint('length(trim(name)) > 0', name=op.f('ck_ministry_subjects_ministry_subject_name_not_blank')),
    sa.CheckConstraint('name IS NULL OR name = btrim(name)', name=op.f('ck_ministry_subjects_name_no_surrounding_whitespace')),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_ministry_subjects')),
    sa.UniqueConstraint('name', name='uq_ministry_subject_name')
    )
    
    op.create_table('ministry_association_subjects',
    sa.Column('ministry_subject_id', sa.Integer(), nullable=False),
    sa.Column('association_subject_id', sa.Integer(), nullable=False),
    sa.ForeignKeyConstraint(['association_subject_id'], ['association_subjects.id'], name=op.f('fk_ministry_association_subjects_association_subject_id_association_subjects'), ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['ministry_subject_id'], ['ministry_subjects.id'], name=op.f('fk_ministry_association_subjects_ministry_subject_id_ministry_subjects'), ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('ministry_subject_id', 'association_subject_id', name=op.f('pk_ministry_association_subjects'))
    )
    
    op.create_table('school_study_programs',
    sa.Column('study_program_id', sa.Integer(), nullable=False),
    sa.Column('school_mechanographic_code', sa.String(length=255), nullable=False),
    sa.CheckConstraint('school_mechanographic_code IS NULL OR school_mechanographic_code = btrim(school_mechanographic_code)', name=op.f('ck_school_study_programs_school_mechanographic_code_no_surrounding_whitespace')),
    sa.ForeignKeyConstraint(['school_mechanographic_code'], ['schools.mechanographic_code'], name=op.f('fk_school_study_programs_school_mechanographic_code_schools'), ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['study_program_id'], ['study_programs.id'], name=op.f('fk_school_study_programs_study_program_id_study_programs'), ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('study_program_id', 'school_mechanographic_code', name=op.f('pk_school_study_programs'))
    )
    
    op.create_table('study_program_subjects',
    sa.Column('study_program_id', sa.Integer(), nullable=False),
    sa.Column('ministry_subject_id', sa.Integer(), nullable=False),
    sa.ForeignKeyConstraint(['ministry_subject_id'], ['ministry_subjects.id'], name=op.f('fk_study_program_subjects_ministry_subject_id_ministry_subjects'), ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['study_program_id'], ['study_programs.id'], name=op.f('fk_study_program_subjects_study_program_id_study_programs'), ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('study_program_id', 'ministry_subject_id', name=op.f('pk_study_program_subjects'))
    )

    # FKs into the old tables must go before the tables themselves.
    op.drop_constraint(op.f('fk_school_enrollments_teaching_offering_id_teaching_offerings'), 'school_enrollments', type_='foreignkey')
    op.drop_constraint(op.f('fk_teaching_competences_subject_id_subjects'), 'teaching_competences', type_='foreignkey')
    op.drop_constraint(op.f('fk_teaching_competences_teaching_offering_id_teaching_offerings'), 'teaching_competences', type_='foreignkey')

    op.drop_table('teacher_subjects')
    op.drop_table('teaching_offering_subjects')
    op.drop_table('teaching_offering_years')

    op.drop_index(op.f('uq_subject_discipline_specialization'), table_name='subjects')
    op.drop_table('subjects')
    op.drop_index(op.f('ix_teaching_offerings_school_mechanographic_code'), table_name='teaching_offerings')
    op.drop_table('teaching_offerings')

    op.add_column('school_enrollments', sa.Column('study_program_id', sa.Integer(), nullable=False))
    op.drop_index(op.f('ix_school_enrollments_teaching_offering_id'), table_name='school_enrollments')
    op.create_index(op.f('ix_school_enrollments_study_program_id'), 'school_enrollments', ['study_program_id'], unique=False)
    op.create_foreign_key(op.f('fk_school_enrollments_study_program_id_study_programs'), 'school_enrollments', 'study_programs', ['study_program_id'], ['id'], ondelete='RESTRICT')
    op.drop_column('school_enrollments', 'teaching_offering_id')

    op.add_column('study_programs', sa.Column('level', postgresql.ENUM('PRIMARY_SCHOOL', 'MIDDLE_SCHOOL', 'HIGH_SCHOOL', name='education_level_enum', create_type=False), nullable=False))
    op.add_column('study_programs', sa.Column('min_year', sa.Integer(), nullable=False))
    op.add_column('study_programs', sa.Column('max_year', sa.Integer(), nullable=False))
    op.drop_constraint(op.f('uq_study_program_name'), 'study_programs', type_='unique')
    op.create_unique_constraint('uq_level_program_name', 'study_programs', ['level', 'name'])

    op.add_column('teaching_competences', sa.Column('association_subject_id', sa.Integer(), nullable=False))
    op.add_column('teaching_competences', sa.Column('study_program_id', sa.Integer(), nullable=False))
    op.create_foreign_key(op.f('fk_teaching_competences_association_subject_id_association_subjects'), 'teaching_competences', 'association_subjects', ['association_subject_id'], ['id'], ondelete='CASCADE')
    op.create_foreign_key(op.f('fk_teaching_competences_study_program_id_study_programs'), 'teaching_competences', 'study_programs', ['study_program_id'], ['id'], ondelete='CASCADE')
    op.drop_column('teaching_competences', 'subject_id')
    op.drop_column('teaching_competences', 'teaching_offering_id')


def downgrade() -> None:
    """Downgrade schema."""
    
    op.add_column('teaching_competences', sa.Column('teaching_offering_id', sa.INTEGER(), autoincrement=False, nullable=False))
    op.add_column('teaching_competences', sa.Column('subject_id', sa.INTEGER(), autoincrement=False, nullable=False))
    op.drop_constraint(op.f('fk_teaching_competences_study_program_id_study_programs'), 'teaching_competences', type_='foreignkey')
    op.drop_constraint(op.f('fk_teaching_competences_association_subject_id_association_subjects'), 'teaching_competences', type_='foreignkey')
    op.drop_column('teaching_competences', 'study_program_id')
    op.drop_column('teaching_competences', 'association_subject_id')

    op.drop_constraint('uq_level_program_name', 'study_programs', type_='unique')
    op.create_unique_constraint(op.f('uq_study_program_name'), 'study_programs', ['name'], postgresql_nulls_not_distinct=False)
    op.drop_column('study_programs', 'max_year')
    op.drop_column('study_programs', 'min_year')
    op.drop_column('study_programs', 'level')

    op.add_column('school_enrollments', sa.Column('teaching_offering_id', sa.INTEGER(), autoincrement=False, nullable=False))
    op.drop_constraint(op.f('fk_school_enrollments_study_program_id_study_programs'), 'school_enrollments', type_='foreignkey')
    op.drop_index(op.f('ix_school_enrollments_study_program_id'), table_name='school_enrollments')
    op.create_index(op.f('ix_school_enrollments_teaching_offering_id'), 'school_enrollments', ['teaching_offering_id'], unique=False)
    op.drop_column('school_enrollments', 'study_program_id')

    op.create_table('subjects',
    sa.Column('id', sa.INTEGER(), autoincrement=True, nullable=False),
    sa.Column('discipline', sa.VARCHAR(length=100), autoincrement=False, nullable=False),
    sa.Column('specialization', sa.VARCHAR(length=100), autoincrement=False, nullable=True),
    sa.CheckConstraint('id > 0', name=op.f('ck_subjects_positive_id')),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_subjects'))
    )
    op.create_index(op.f('uq_subject_discipline_specialization'), 'subjects', ['discipline', sa.literal_column("COALESCE(specialization, ''::character varying)")], unique=True)
    
    op.create_table('teaching_offerings',
    sa.Column('id', sa.INTEGER(), autoincrement=True, nullable=False),
    sa.Column('level', postgresql.ENUM('PRIMARY_SCHOOL', 'MIDDLE_SCHOOL', 'HIGH_SCHOOL', name='education_level_enum'), autoincrement=False, nullable=False),
    sa.Column('school_mechanographic_code', sa.VARCHAR(length=20), autoincrement=False, nullable=False),
    sa.Column('study_program_id', sa.INTEGER(), autoincrement=False, nullable=False),
    sa.CheckConstraint('id > 0', name=op.f('ck_teaching_offerings_positive_id')),
    sa.ForeignKeyConstraint(['school_mechanographic_code'], ['schools.mechanographic_code'], name=op.f('fk_teaching_offerings_school_mechanographic_code_schools'), ondelete='RESTRICT'),
    sa.ForeignKeyConstraint(['study_program_id'], ['study_programs.id'], name=op.f('fk_teaching_offerings_study_program_id_study_programs'), ondelete='RESTRICT'),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_teaching_offerings')),
    sa.UniqueConstraint('school_mechanographic_code', 'study_program_id', 'level', name=op.f('uq_teaching_offering'), postgresql_include=[], postgresql_nulls_not_distinct=False)
    )
    op.create_index(op.f('ix_teaching_offerings_school_mechanographic_code'), 'teaching_offerings', ['school_mechanographic_code'], unique=False)

    op.create_table('teaching_offering_years',
    sa.Column('offering_id', sa.INTEGER(), autoincrement=False, nullable=False),
    sa.Column('year', sa.INTEGER(), autoincrement=False, nullable=False),
    sa.CheckConstraint('year > 0', name=op.f('ck_teaching_offering_years_positive_year')),
    sa.CheckConstraint('year >= 1 AND year <= 5', name=op.f('ck_teaching_offering_years_valid_school_year')),
    sa.ForeignKeyConstraint(['offering_id'], ['teaching_offerings.id'], name=op.f('fk_teaching_offering_years_offering_id_teaching_offerings'), ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('offering_id', 'year', name=op.f('pk_teaching_offering_years'))
    )
    
    op.create_table('teaching_offering_subjects',
    sa.Column('subject_id', sa.INTEGER(), autoincrement=False, nullable=False),
    sa.Column('teaching_offering_id', sa.INTEGER(), autoincrement=False, nullable=False),
    sa.ForeignKeyConstraint(['subject_id'], ['subjects.id'], name=op.f('fk_teaching_offering_subjects_subject_id_subjects'), ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['teaching_offering_id'], ['teaching_offerings.id'], name=op.f('fk_teaching_offering_subjects_teaching_offering_id_teac_a688'), ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('subject_id', 'teaching_offering_id', name=op.f('pk_teaching_offering_subjects'))
    )
    
    op.create_table('teacher_subjects',
    sa.Column('teacher_tax_code', sa.VARCHAR(length=16), autoincrement=False, nullable=False),
    sa.Column('subject_id', sa.INTEGER(), autoincrement=False, nullable=False),
    sa.ForeignKeyConstraint(['subject_id'], ['subjects.id'], name=op.f('fk_teacher_subjects_subject_id_subjects'), ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['teacher_tax_code'], ['teachers.tax_code'], name=op.f('fk_teacher_subjects_teacher_tax_code_teachers'), ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('teacher_tax_code', 'subject_id', name=op.f('pk_teacher_subjects'))
    )

    op.create_foreign_key(op.f('fk_teaching_competences_teaching_offering_id_teaching_offerings'), 'teaching_competences', 'teaching_offerings', ['teaching_offering_id'], ['id'], ondelete='CASCADE')
    op.create_foreign_key(op.f('fk_teaching_competences_subject_id_subjects'), 'teaching_competences', 'subjects', ['subject_id'], ['id'], ondelete='CASCADE')
    op.create_foreign_key(op.f('fk_school_enrollments_teaching_offering_id_teaching_offerings'), 'school_enrollments', 'teaching_offerings', ['teaching_offering_id'], ['id'], ondelete='RESTRICT')

    op.drop_table('study_program_subjects')
    op.drop_table('school_study_programs')
    op.drop_table('ministry_association_subjects')
    op.drop_table('ministry_subjects')
    op.drop_table('association_subjects')
