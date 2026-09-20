"""schools: surrogate int id, optional mechanographic_code, (name, city) unique

Revision ID: aa410838d808
Revises: 69e755fafde0
"""
import sqlalchemy as sa

from alembic import op

revision = "aa410838d808"
down_revision = "69e755fafde0"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # A volatile nextval() default forces a table rewrite: each row gets a distinct id.
    op.execute("CREATE SEQUENCE schools_id_seq")
    op.add_column(
        "schools",
        sa.Column(
            "id",
            sa.Integer(),
            nullable=False,
            server_default=sa.text("nextval('schools_id_seq')"),
        ),
    )
    op.execute("ALTER SEQUENCE schools_id_seq OWNED BY schools.id")

    # Backfill school_id via the old code, unique today so the mapping is 1:1.
    op.add_column(
        "school_study_programs",
        sa.Column("school_id", sa.Integer(), nullable=True),
    )
    op.add_column(
        "school_enrollments",
        sa.Column("school_id", sa.Integer(), nullable=True),
    )
    op.execute("""
        UPDATE school_study_programs ssp
        SET school_id = s.id
        FROM schools s
        WHERE ssp.school_mechanographic_code = s.mechanographic_code
    """)
    op.execute("""
        UPDATE school_enrollments se
        SET school_id = s.id
        FROM schools s
        WHERE se.school_mechanographic_code = s.mechanographic_code
    """)

    # Drop FKs to the old code by lookup: each table has at most one FK to it.
    op.execute("""
        DO $$
        DECLARE fk text;
        BEGIN
            SELECT conname INTO fk FROM pg_constraint
            WHERE conrelid = 'school_enrollments'::regclass
              AND contype = 'f'
              AND confrelid = 'school_study_programs'::regclass;
            IF fk IS NOT NULL THEN
                EXECUTE format('ALTER TABLE school_enrollments DROP CONSTRAINT %I', fk);
            END IF;
        END $$;
    """)
    op.execute("""
        DO $$
        DECLARE fk text;
        BEGIN
            SELECT conname INTO fk FROM pg_constraint
            WHERE conrelid = 'school_study_programs'::regclass
              AND contype = 'f'
              AND confrelid = 'schools'::regclass;
            IF fk IS NOT NULL THEN
                EXECUTE format('ALTER TABLE school_study_programs DROP CONSTRAINT %I', fk);
            END IF;
        END $$;
    """)

    # PK swap by lookup: the one contype 'p' row may not be named schools_pkey.
    op.execute("""
        DO $$
        DECLARE pk text;
        BEGIN
            SELECT conname INTO pk FROM pg_constraint
            WHERE conrelid = 'schools'::regclass AND contype = 'p';
            IF pk IS NOT NULL THEN
                EXECUTE format('ALTER TABLE schools DROP CONSTRAINT %I', pk);
            END IF;
        END $$;
    """)
    op.create_primary_key("schools_pkey", "schools", ["id"])

    # Same name-agnostic PK swap for the bridge table.
    op.execute("""
        DO $$
        DECLARE pk text;
        BEGIN
            SELECT conname INTO pk FROM pg_constraint
            WHERE conrelid = 'school_study_programs'::regclass AND contype = 'p';
            IF pk IS NOT NULL THEN
                EXECUTE format('ALTER TABLE school_study_programs DROP CONSTRAINT %I', pk);
            END IF;
        END $$;
    """)
    op.alter_column("school_study_programs", "school_id", nullable=False)
    op.create_primary_key(
        "school_study_programs_pkey",
        "school_study_programs",
        ["study_program_id", "school_id"],
    )

    # Recreate the FKs on school_id with explicit names chosen here.
    op.create_foreign_key(
        "school_study_programs_school_id_fkey",
        "school_study_programs", "schools",
        ["school_id"], ["id"],
        ondelete="CASCADE",
    )
    op.alter_column("school_enrollments", "school_id", nullable=False)
    op.create_foreign_key(
        "school_enrollments_ssp_fkey",
        "school_enrollments", "school_study_programs",
        ["study_program_id", "school_id"],
        ["study_program_id", "school_id"],
        ondelete="RESTRICT",
    )

    # DROP COLUMN also drops the attached CHECKs, whatever their names.
    op.drop_column("school_study_programs", "school_mechanographic_code")
    op.drop_column("school_enrollments", "school_mechanographic_code")

    # Drop both format CHECKs by definition; neither pattern matches the whitespace one.
    op.alter_column(
        "schools", "mechanographic_code",
        existing_type=sa.String(20), nullable=True,
    )
    op.execute("""
        DO $$
        DECLARE c text;
        BEGIN
            SELECT conname INTO c FROM pg_constraint
            WHERE conrelid = 'schools'::regclass
              AND contype = 'c'
              AND pg_get_constraintdef(oid) ILIKE '%length(mechanographic_code)%';
            IF c IS NOT NULL THEN
                EXECUTE format('ALTER TABLE schools DROP CONSTRAINT %I', c);
            END IF;
        END $$;
    """)
    op.execute("""
        DO $$
        DECLARE c text;
        BEGIN
            SELECT conname INTO c FROM pg_constraint
            WHERE conrelid = 'schools'::regclass
              AND contype = 'c'
              AND pg_get_constraintdef(oid) ILIKE '%substr(mechanographic_code%';
            IF c IS NOT NULL THEN
                EXECUTE format('ALTER TABLE schools DROP CONSTRAINT %I', c);
            END IF;
        END $$;
    """)
    op.create_unique_constraint("uq_school_name_city", "schools", ["name", "city"])


def downgrade() -> None:
    # Downgrade fails unless every school has a NOT NULL, unique mechanographic_code.
    op.drop_constraint("uq_school_name_city", "schools", type_="unique")
    op.create_check_constraint(
        "school_code_length", "schools",
        "mechanographic_code LIKE 'PRIV-%' OR length(mechanographic_code) = 10",
    )
    op.create_check_constraint(
        "school_code_province_consistency", "schools",
        "mechanographic_code LIKE 'PRIV-%' OR "
        "upper(substr(mechanographic_code, 1, 2)) = upper(province)",
    )
    op.alter_column(
        "schools", "mechanographic_code",
        existing_type=sa.String(20), nullable=False,
    )

    op.add_column(
        "school_study_programs",
        sa.Column("school_mechanographic_code", sa.String(20), nullable=True),
    )
    op.add_column(
        "school_enrollments",
        sa.Column("school_mechanographic_code", sa.String(20), nullable=True),
    )
    op.execute("""
        UPDATE school_study_programs ssp
        SET school_mechanographic_code = s.mechanographic_code
        FROM schools s WHERE ssp.school_id = s.id
    """)
    op.execute("""
        UPDATE school_enrollments se
        SET school_mechanographic_code = s.mechanographic_code
        FROM schools s WHERE se.school_id = s.id
    """)

    # These FKs got explicit names in upgrade: literal-name drop is safe.
    op.drop_constraint("school_enrollments_ssp_fkey", "school_enrollments", type_="foreignkey")
    op.drop_constraint("school_study_programs_school_id_fkey", "school_study_programs", type_="foreignkey")

    # Same for the PKs, recreated with explicit names in upgrade.
    op.drop_constraint("school_study_programs_pkey", "school_study_programs", type_="primary")
    op.drop_constraint("schools_pkey", "schools", type_="primary")
    op.create_primary_key("schools_pkey", "schools", ["mechanographic_code"])

    op.alter_column("school_study_programs", "school_mechanographic_code", nullable=False)
    op.create_primary_key(
        "school_study_programs_pkey", "school_study_programs",
        ["study_program_id", "school_mechanographic_code"],
    )
    op.create_foreign_key(
        None, "school_study_programs", "schools",
        ["school_mechanographic_code"], ["mechanographic_code"],
        ondelete="CASCADE", onupdate="CASCADE",
    )
    op.alter_column("school_enrollments", "school_mechanographic_code", nullable=False)
    op.create_foreign_key(
        None, "school_enrollments", "school_study_programs",
        ["study_program_id", "school_mechanographic_code"],
        ["study_program_id", "school_mechanographic_code"],
        ondelete="RESTRICT", onupdate="CASCADE",
    )
    # If constraints.py ever emits a no-whitespace CHECK for the code, recreate it here.

    op.drop_column("school_enrollments", "school_id")
    op.drop_column("school_study_programs", "school_id")
    op.drop_column("schools", "id")
    op.execute("DROP SEQUENCE schools_id_seq")