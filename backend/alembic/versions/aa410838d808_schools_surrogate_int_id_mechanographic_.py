"""schools: surrogate int id, mechanographic_code opzionale, (name, city) unique

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
    # 1. schools: nuova PK surrogata `id` (sequenza in stile SERIAL).
    #    ADD COLUMN con default volatile nextval() forza il rewrite e assegna
    #    un id distinto a ogni riga esistente.
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

    # 2. bridge + enrollments: aggiungo school_id (nullable) e faccio il backfill
    #    tramite join sul vecchio codice (oggi univoco -> mapping 1:1).
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

    # 3. drop delle FK che puntano al vecchio codice (per lookup, nome-agnostico:
    #    ogni tabella ha al massimo una FK verso quella relatione specifica).
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

    # 4. swap PK su schools.
    #    Nome-agnostico: ogni tabella ha esattamente una PK (contype = 'p'),
    #    quindi non serve conoscerne il nome reale (potrebbe non essere
    #    "schools_pkey" se Base usa una naming_convention custom).
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

    # 5. swap PK su bridge (stesso motivo: lookup per contype, non per nome).
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

    # 6. ricreo le FK su school_id (nomi scelti qui esplicitamente: nessuna
    #    ambiguità, sono create da questa stessa migrazione).
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

    # 7. rimuovo le vecchie colonne codice (i CHECK collegati ad esse cadono
    #    automaticamente col DROP COLUMN, qualunque sia il loro nome reale).
    op.drop_column("school_study_programs", "school_mechanographic_code")
    op.drop_column("school_enrollments", "school_mechanographic_code")

    # 8. schools: codice opzionale, drop dei check di formato (nome-agnostico,
    #    individuati per contenuto della definizione: length(...) = 10 per il
    #    primo, substr(mechanographic_code per il secondo — nessuno dei due
    #    pattern compare nel CHECK di whitespace, che resta intatto),
    #    UNIQUE su (name, city).
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
    # PRECONDIZIONE: ogni scuola deve avere mechanographic_code NON NULL e UNIVOCO.
    # Se sono state create/modificate scuole con codice NULL o duplicato sotto il
    # nuovo modello, il downgrade fallisce (è intrinsecamente non reversibile).
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

    # Queste FK sono state create con nome esplicito da questa stessa
    # migrazione (step 6 di upgrade): il drop per nome letterale è sicuro.
    op.drop_constraint("school_enrollments_ssp_fkey", "school_enrollments", type_="foreignkey")
    op.drop_constraint("school_study_programs_school_id_fkey", "school_study_programs", type_="foreignkey")

    # Idem per le PK: ricreate con nome esplicito da questa migrazione
    # (step 4/5 di upgrade), quindi il drop per nome letterale è sicuro.
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
    # NB: se in constraints.py il no-whitespace su school_mechanographic_code
    #     genera un CHECK, ricrealo qui con la stessa espressione.

    op.drop_column("school_enrollments", "school_id")
    op.drop_column("school_study_programs", "school_id")
    op.drop_column("schools", "id")
    op.execute("DROP SEQUENCE schools_id_seq")