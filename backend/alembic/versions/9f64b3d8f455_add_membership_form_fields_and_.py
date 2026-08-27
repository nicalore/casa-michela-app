"""add membership form fields and psychological support

Revision ID: 9f64b3d8f455
Revises: 632faad7c7dd
Create Date: 2026-07-15 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = "9f64b3d8f455"
down_revision = "632faad7c7dd"
branch_labels = None
depends_on = None


# Enum definitions used both for the explicit CREATE TYPE and for the columns
# referencing them (those use create_type=False so SQLAlchemy won't recreate them).
certification_type_enum = postgresql.ENUM(
    "DSA", "BES", "ADHD", "OTHER",
    name="certification_type_enum",
)

course_type_enum = postgresql.ENUM(
    "YOGA", "PILATES",
    name="course_type_enum",
)

payment_method_enum = postgresql.ENUM(
    "CASH", "BANK_TRANSFER", "OTHER",
    name="payment_method_enum",
)


def upgrade() -> None:
    # Alembic autogenerate does not emit CREATE TYPE for Postgres enums: create
    # them explicitly, before any column that uses them.
    bind = op.get_bind()
    certification_type_enum.create(bind, checkfirst=True)
    course_type_enum.create(bind, checkfirst=True)
    payment_method_enum.create(bind, checkfirst=True)

    op.add_column(
        "people",
        sa.Column(
            "birth_nation",
            sa.String(length=100),
            nullable=False,
            server_default="Italia",
        ),
    )
    op.create_check_constraint(
        op.f("ck_people_birth_nation_not_blank"),
        "people",
        "length(trim(birth_nation)) > 0",
    )
    op.create_check_constraint(
        op.f("ck_people_birth_nation_no_surrounding_whitespace"),
        "people",
        "birth_nation IS NULL OR birth_nation = btrim(birth_nation)",
    )
    # The default only backfills historical rows; from here on the value must
    # always be provided explicitly, as the model requires.
    op.alter_column("people", "birth_nation", server_default=None)

    op.add_column(
        "students",
        sa.Column(
            "certification_type",
            postgresql.ENUM(
                "DSA", "BES", "ADHD", "OTHER",
                name="certification_type_enum",
                create_type=False,
            ),
            nullable=True,
        ),
    )
    op.add_column(
        "students",
        sa.Column(
            "certification_other_detail",
            sa.String(length=255),
            nullable=True,
        ),
    )
    op.add_column(
        "students",
        sa.Column(
            "mandatory_psych_meetings_acknowledged",
            sa.Boolean(),
            nullable=False,
            server_default="false",
        ),
    )
    op.create_check_constraint(
        op.f("ck_students_certification_other_detail_requires_other_type"),
        "students",
        "certification_other_detail IS NULL "
        "OR certification_type IS NOT DISTINCT FROM 'OTHER'",
    )
    op.create_check_constraint(
        op.f("ck_students_certification_other_detail_not_blank"),
        "students",
        "certification_other_detail IS NULL "
        "OR length(trim(certification_other_detail)) > 0",
    )
    op.create_check_constraint(
        op.f("ck_students_certification_other_detail_no_surrounding_whitespace"),
        "students",
        "certification_other_detail IS NULL "
        "OR certification_other_detail = btrim(certification_other_detail)",
    )

    # The two legacy CHECKs from 5653d8989dad are dropped by name SUFFIX, not
    # full name: they may still carry the historical "partecipants" prefix (the
    # table was renamed but Postgres kept the constraint names), and the suffix
    # comes from the column name, so it is stable across environments.
    op.execute(
        """
        DO $$
        DECLARE
            found_name text;
        BEGIN
            SELECT conname INTO found_name
            FROM pg_constraint
            WHERE conrelid = 'course_participants'::regclass
              AND contype = 'c'
              AND conname LIKE '%course_type_not_blank';

            IF found_name IS NULL THEN
                RAISE EXCEPTION 'Nessun vincolo CHECK "%%course_type_not_blank" trovato su course_participants: verificare manualmente prima di procedere.';
            END IF;

            EXECUTE format('ALTER TABLE course_participants DROP CONSTRAINT %I', found_name);

            SELECT conname INTO found_name
            FROM pg_constraint
            WHERE conrelid = 'course_participants'::regclass
              AND contype = 'c'
              AND conname LIKE '%course_type_no_surrounding_whitespace';

            IF found_name IS NULL THEN
                RAISE EXCEPTION 'Nessun vincolo CHECK "%%course_type_no_surrounding_whitespace" trovato su course_participants: verificare manualmente prima di procedere.';
            END IF;

            EXECUTE format('ALTER TABLE course_participants DROP CONSTRAINT %I', found_name);
        END $$;
        """
    )
    # Residual values other than YOGA/PILATES (e.g. "SS") are confirmed test
    # junk, not real data: overwrite to YOGA instead of blocking the migration.
    op.execute(
        "UPDATE course_participants "
        "SET course_type = 'YOGA' "
        "WHERE UPPER(course_type) NOT IN ('YOGA', 'PILATES')"
    )
    # UPPER() tolerates historical lowercase/mixed-case values (e.g. "Pilates").
    op.alter_column(
        "course_participants",
        "course_type",
        existing_type=sa.String(length=100),
        type_=course_type_enum,
        postgresql_using="UPPER(course_type)::course_type_enum",
        existing_nullable=False,
    )

    op.add_column(
        "members",
        sa.Column(
            "payment_method",
            postgresql.ENUM(
                "CASH", "BANK_TRANSFER", "OTHER",
                name="payment_method_enum",
                create_type=False,
            ),
            nullable=True,
        ),
    )
    op.add_column(
        "members",
        sa.Column("payment_method_other", sa.String(length=255), nullable=True),
    )
    op.add_column(
        "members",
        sa.Column(
            "statute_acknowledged",
            sa.Boolean(),
            nullable=False,
            server_default="false",
        ),
    )
    op.add_column(
        "members",
        sa.Column(
            "regulation_acknowledged",
            sa.Boolean(),
            nullable=False,
            server_default="false",
        ),
    )
    op.add_column(
        "members",
        sa.Column(
            "video_surveillance_acknowledged",
            sa.Boolean(),
            nullable=False,
            server_default="false",
        ),
    )
    op.add_column(
        "members",
        sa.Column(
            "special_category_data_consent",
            sa.Boolean(),
            nullable=False,
            server_default="false",
        ),
    )
    op.add_column(
        "members",
        sa.Column(
            "newsletter_consent",
            sa.Boolean(),
            nullable=False,
            server_default="false",
        ),
    )
    op.add_column(
        "members",
        sa.Column("consents_signed_at", sa.Date(), nullable=True),
    )
    op.add_column(
        "members",
        sa.Column("emergency_contact_name", sa.String(length=200), nullable=True),
    )
    op.add_column(
        "members",
        sa.Column("emergency_contact_phone", sa.String(length=20), nullable=True),
    )
    op.add_column(
        "members",
        sa.Column("allergies_notes", sa.String(length=1000), nullable=True),
    )
    op.add_column(
        "members",
        sa.Column("medications_notes", sa.String(length=1000), nullable=True),
    )
    op.create_check_constraint(
        op.f("ck_members_payment_method_other_requires_other_method"),
        "members",
        "payment_method_other IS NULL "
        "OR payment_method IS NOT DISTINCT FROM 'OTHER'",
    )
    op.create_check_constraint(
        op.f("ck_members_payment_method_other_not_blank"),
        "members",
        "payment_method_other IS NULL "
        "OR length(trim(payment_method_other)) > 0",
    )
    op.create_check_constraint(
        op.f("ck_members_emergency_contact_name_not_blank"),
        "members",
        "emergency_contact_name IS NULL "
        "OR length(trim(emergency_contact_name)) > 0",
    )
    op.create_check_constraint(
        op.f("ck_members_emergency_contact_phone_format"),
        "members",
        "emergency_contact_phone IS NULL "
        "OR emergency_contact_phone ~ '^\\+?[0-9]+$'",
    )
    op.create_check_constraint(
        op.f("ck_members_allergies_notes_not_blank"),
        "members",
        "allergies_notes IS NULL OR length(trim(allergies_notes)) > 0",
    )
    op.create_check_constraint(
        op.f("ck_members_medications_notes_not_blank"),
        "members",
        "medications_notes IS NULL OR length(trim(medications_notes)) > 0",
    )
    op.create_check_constraint(
        op.f("ck_members_payment_method_other_no_surrounding_whitespace"),
        "members",
        "payment_method_other IS NULL "
        "OR payment_method_other = btrim(payment_method_other)",
    )
    op.create_check_constraint(
        op.f("ck_members_emergency_contact_name_no_surrounding_whitespace"),
        "members",
        "emergency_contact_name IS NULL "
        "OR emergency_contact_name = btrim(emergency_contact_name)",
    )
    op.create_check_constraint(
        op.f("ck_members_emergency_contact_phone_no_surrounding_whitespace"),
        "members",
        "emergency_contact_phone IS NULL "
        "OR emergency_contact_phone = btrim(emergency_contact_phone)",
    )
    op.create_check_constraint(
        op.f("ck_members_allergies_notes_no_surrounding_whitespace"),
        "members",
        "allergies_notes IS NULL OR allergies_notes = btrim(allergies_notes)",
    )
    op.create_check_constraint(
        op.f("ck_members_medications_notes_no_surrounding_whitespace"),
        "members",
        "medications_notes IS NULL OR medications_notes = btrim(medications_notes)",
    )

    op.create_table(
        "psychological_supports",
        sa.Column("tax_code", sa.String(length=16), nullable=False),
        sa.Column("start_date", sa.Date(), nullable=False),
        sa.CheckConstraint(
            "start_date >= DATE '1900-01-01'",
            name=op.f("ck_psychological_supports_psychological_support_start_date_min"),
        ),
        sa.ForeignKeyConstraint(
            ["tax_code"],
            ["members.tax_code"],
            name=op.f("fk_psychological_supports_tax_code_members"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("tax_code", name=op.f("pk_psychological_supports")),
    )


def downgrade() -> None:
    op.drop_table("psychological_supports")

    op.drop_constraint(
        op.f("ck_members_medications_notes_no_surrounding_whitespace"),
        "members",
        type_="check",
    )
    op.drop_constraint(
        op.f("ck_members_allergies_notes_no_surrounding_whitespace"),
        "members",
        type_="check",
    )
    op.drop_constraint(
        op.f("ck_members_emergency_contact_phone_no_surrounding_whitespace"),
        "members",
        type_="check",
    )
    op.drop_constraint(
        op.f("ck_members_emergency_contact_name_no_surrounding_whitespace"),
        "members",
        type_="check",
    )
    op.drop_constraint(
        op.f("ck_members_payment_method_other_no_surrounding_whitespace"),
        "members",
        type_="check",
    )
    op.drop_constraint(
        op.f("ck_members_medications_notes_not_blank"), "members", type_="check"
    )
    op.drop_constraint(
        op.f("ck_members_allergies_notes_not_blank"), "members", type_="check"
    )
    op.drop_constraint(
        op.f("ck_members_emergency_contact_phone_format"), "members", type_="check"
    )
    op.drop_constraint(
        op.f("ck_members_emergency_contact_name_not_blank"), "members", type_="check"
    )
    op.drop_constraint(
        op.f("ck_members_payment_method_other_not_blank"), "members", type_="check"
    )
    op.drop_constraint(
        op.f("ck_members_payment_method_other_requires_other_method"),
        "members",
        type_="check",
    )
    op.drop_column("members", "medications_notes")
    op.drop_column("members", "allergies_notes")
    op.drop_column("members", "emergency_contact_phone")
    op.drop_column("members", "emergency_contact_name")
    op.drop_column("members", "consents_signed_at")
    op.drop_column("members", "newsletter_consent")
    op.drop_column("members", "special_category_data_consent")
    op.drop_column("members", "video_surveillance_acknowledged")
    op.drop_column("members", "regulation_acknowledged")
    op.drop_column("members", "statute_acknowledged")
    op.drop_column("members", "payment_method_other")
    op.drop_column("members", "payment_method")

    op.alter_column(
        "course_participants",
        "course_type",
        existing_type=course_type_enum,
        type_=sa.String(length=100),
        postgresql_using="course_type::VARCHAR(100)",
        existing_nullable=False,
    )
    op.create_check_constraint(
        op.f("ck_course_participants_course_type_no_surrounding_whitespace"),
        "course_participants",
        "course_type IS NULL OR course_type = btrim(course_type)",
    )
    op.create_check_constraint(
        op.f("ck_course_participants_course_type_not_blank"),
        "course_participants",
        "length(trim(course_type)) > 0",
    )

    op.drop_constraint(
        op.f("ck_students_certification_other_detail_no_surrounding_whitespace"),
        "students",
        type_="check",
    )
    op.drop_constraint(
        op.f("ck_students_certification_other_detail_not_blank"),
        "students",
        type_="check",
    )
    op.drop_constraint(
        op.f("ck_students_certification_other_detail_requires_other_type"),
        "students",
        type_="check",
    )
    op.drop_column("students", "mandatory_psych_meetings_acknowledged")
    op.drop_column("students", "certification_other_detail")
    op.drop_column("students", "certification_type")

    op.drop_constraint(
        op.f("ck_people_birth_nation_no_surrounding_whitespace"),
        "people",
        type_="check",
    )
    op.drop_constraint(
        op.f("ck_people_birth_nation_not_blank"), "people", type_="check"
    )
    op.drop_column("people", "birth_nation")

    # Enum types are dropped last, once no column references them.
    bind = op.get_bind()
    payment_method_enum.drop(bind, checkfirst=True)
    course_type_enum.drop(bind, checkfirst=True)
    certification_type_enum.drop(bind, checkfirst=True)