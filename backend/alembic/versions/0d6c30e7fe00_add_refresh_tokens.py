"""add refresh tokens

Revision ID: 0d6c30e7fe00
Revises: 5653d8989dad
Create Date: 2026-06-03 22:29:36.859108

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '0d6c30e7fe00'
down_revision: Union[str, Sequence[str], None] = '5653d8989dad'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table('refresh_tokens',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('account_tax_code', sa.String(length=16), nullable=False),
    sa.Column('token_id', sa.String(length=36), nullable=False),
    sa.Column('token_hash', sa.String(length=512), nullable=False),
    sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('revoked_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.CheckConstraint('expires_at > created_at', name=op.f('ck_refresh_tokens_refresh_token_expiration_after_creation')),
    sa.CheckConstraint('length(trim(token_hash)) > 0', name=op.f('ck_refresh_tokens_token_hash_not_blank')),
    sa.CheckConstraint('length(trim(token_id)) > 0', name=op.f('ck_refresh_tokens_token_id_not_blank')),
    sa.ForeignKeyConstraint(['account_tax_code'], ['accounts.tax_code'], name=op.f('fk_refresh_tokens_account_tax_code_accounts'), ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_refresh_tokens'))
    )
    op.create_index(op.f('ix_refresh_tokens_account_tax_code'), 'refresh_tokens', ['account_tax_code'], unique=False)
    op.create_index(op.f('ix_refresh_tokens_token_id'), 'refresh_tokens', ['token_id'], unique=True)
    op.alter_column('accounts', 'password_hash',
               existing_type=sa.VARCHAR(length=255),
               type_=sa.String(length=512),
               existing_nullable=False)


def downgrade() -> None:
    """Downgrade schema."""
    op.alter_column('accounts', 'password_hash',
               existing_type=sa.String(length=512),
               type_=sa.VARCHAR(length=255),
               existing_nullable=False)
    op.drop_index(op.f('ix_refresh_tokens_token_id'), table_name='refresh_tokens')
    op.drop_index(op.f('ix_refresh_tokens_account_tax_code'), table_name='refresh_tokens')
    op.drop_table('refresh_tokens')
