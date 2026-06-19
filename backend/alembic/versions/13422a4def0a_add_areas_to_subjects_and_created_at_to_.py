"""Add areas to subjects and created_at to schools, subjects and study programs

Revision ID: 13422a4def0a
Revises: c9b0d3aefb29
Create Date: 2026-06-19 19:57:42.980883

"""
from typing import Sequence, Union

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

# revision identifiers, used by Alembic.
revision: str = '13422a4def0a'
down_revision: Union[str, Sequence[str], None] = 'c9b0d3aefb29'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    
    # 1. Definisce e CREA il nuovo Enum per le Aree
    subject_area_enum = postgresql.ENUM('HUMANITIES', 'LINGUISTICS', 'SCIENCES', name='subject_area_enum')
    subject_area_enum.create(op.get_bind(), checkfirst=True)
    
    # 2. Definisce il riferimento all'Enum dei Livelli GIA' ESISTENTE
    education_level_enum = postgresql.ENUM('PRIMARY_SCHOOL', 'MIDDLE_SCHOOL', 'HIGH_SCHOOL', name='education_level_enum', create_type=False)

    # --- ASSOCIATION SUBJECTS ---
    # Aggiunge le colonne temporaneamente con server_default per popolare le vecchie righe
    op.add_column('association_subjects', sa.Column('area', subject_area_enum, server_default='HUMANITIES', nullable=False))
    op.add_column('association_subjects', sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False))
    # Rimuove il server_default se non lo si desidera più per i futuri insert
    op.alter_column('association_subjects', 'area', server_default=None)
    
    
    # --- MINISTRY SUBJECTS ---
    op.add_column('ministry_subjects', sa.Column('level', education_level_enum, server_default='HIGH_SCHOOL', nullable=False))
    op.add_column('ministry_subjects', sa.Column('area', subject_area_enum, server_default='HUMANITIES', nullable=False))
    op.add_column('ministry_subjects', sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False))
    # Rimuove il server_default
    op.alter_column('ministry_subjects', 'level', server_default=None)
    op.alter_column('ministry_subjects', 'area', server_default=None)
    
    # Gestione constraint unicità
    op.drop_constraint(op.f('uq_ministry_subject_name'), 'ministry_subjects', type_='unique')
    op.create_unique_constraint('uq_level_ministry_subject_name', 'ministry_subjects', ['level', 'name'])
    
    
    # --- SCHOOLS e STUDY PROGRAMS ---
    op.add_column('schools', sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False))
    op.add_column('study_programs', sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False))


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column('study_programs', 'created_at')
    op.drop_column('schools', 'created_at')
    
    op.drop_constraint('uq_level_ministry_subject_name', 'ministry_subjects', type_='unique')
    op.create_unique_constraint(op.f('uq_ministry_subject_name'), 'ministry_subjects', ['name'], postgresql_nulls_not_distinct=False)
    
    op.drop_column('ministry_subjects', 'created_at')
    op.drop_column('ministry_subjects', 'area')
    op.drop_column('ministry_subjects', 'level')
    
    op.drop_column('association_subjects', 'created_at')
    op.drop_column('association_subjects', 'area')

    # ELIMINA il nuovo Enum per le Aree durante il downgrade
    subject_area_enum = postgresql.ENUM('HUMANITIES', 'LINGUISTICS', 'SCIENCES', name='subject_area_enum')
    subject_area_enum.drop(op.get_bind(), checkfirst=True)