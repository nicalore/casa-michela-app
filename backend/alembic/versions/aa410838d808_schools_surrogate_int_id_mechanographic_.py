"""schools: surrogate int id, optional mechanographic_code, (name, city) unique

Revision ID: aa410838d808
Revises: 69e755fafde0
"""
from alembic import op
import sqlalchemy as sa

revision = "aa410838d808"
down_revision = "69e755fafde0"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Step 1 — schools surrogate PK: ADD COLUMN with a volatile nextval()
    # default forces a table rewrite, giving each existing row a distinct id.
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

    # Step 2 — backfill school_id by joining on the old code (unique today,
    # so a 1:1 mapping).
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

    # Step 3 — drop FKs to the old code by name-agnostic lookup: each table has
    # at most one FK toward that specific relation.
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

    # Step 4 — swap the schools PK. Name-agnostic: a table has exactly one PK
    # (contype 'p'), and its real name may not be "schools_pkey".
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

    # Step 5 — same name-agnostic PK swap for the bridge table.
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

    # Step 6 — recreate the FKs on school_id with explicit names chosen here.
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

    # Step 7 — DROP COLUMN also drops the attached CHECKs, whatever their names.
    op.drop_column("school_study_programs", "school_mechanographic_code")
    op.drop_column("school_enrollments", "school_mechanographic_code")

    # Step 8 — drop the two format CHECKs name-agnostically by definition
    # content; neither pattern matches the whitespace CHECK, which stays.
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
    # Precondition: every school needs a NOT NULL, unique mechanographic_code;
    # rows created under the new model may violate this and fail the downgrade.
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

    # These FKs got explicit names in upgrade step 6: literal-name drop is safe.
    op.drop_constraint("school_enrollments_ssp_fkey", "school_enrollments", type_="foreignkey")
    op.drop_constraint("school_study_programs_school_id_fkey", "school_study_programs", type_="foreignkey")

    # Same for the PKs, recreated with explicit names in upgrade steps 4/5.
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
    # NB: if constraints.py ever emits a no-whitespace CHECK for
    # school_mechanographic_code, recreate it here with the same expression.

    op.drop_column("school_enrollments", "school_id")
    op.drop_column("school_study_programs", "school_id")
    op.drop_column("schools", "id")
    op.execute("DROP SEQUENCE schools_id_seq")