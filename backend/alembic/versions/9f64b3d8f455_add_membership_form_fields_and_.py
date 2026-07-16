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


# Definizioni degli enum Postgres usate sia per la CREATE TYPE esplicita
# sia per le colonne che le referenziano (create_type=False su queste
# ultime per evitare che SQLAlchemy tenti di ricreare il tipo).
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
    # L'autogenerate di Alembic non emette il CREATE TYPE per gli enum
    # Postgres: va fatto esplicitamente, prima di qualunque colonna che
    # li usi.
    bind = op.get_bind()
    certification_type_enum.create(bind, checkfirst=True)
    course_type_enum.create(bind, checkfirst=True)
    payment_method_enum.create(bind, checkfirst=True)

    # --- people: nazione di nascita ---------------------------------
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
    # Il default serve solo per il backfill delle righe storiche: da qui
    # in poi il valore va sempre fornito esplicitamente, come da modello.
    op.alter_column("people", "birth_nation", server_default=None)

    # --- students: certificazioni -----------------------------------
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

    # --- course_participants: course_type da testo libero a enum -----
    # I due vincoli storici (creati in 5653d8989dad) non hanno più senso
    # su una colonna enum e vanno rimossi prima della conversione.
    #
    # NON usiamo op.drop_constraint con nome fisso: sul DB di sviluppo
    # questi vincoli portano ancora il prefisso storico "partecipants"
    # invece di "participants" (la tabella è stata rinominata in passato,
    # ma Postgres non rinomina i vincoli insieme alla tabella). Non è
    # garantito che ambienti diversi (dev/test/prod) abbiano lo stesso
    # refuso, quindi cerchiamo il vincolo per suffisso del nome — che
    # non cambia, essendo generato dal nome della colonna, non da quello
    # della tabella — invece che per nome completo.
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
    # Valori residui diversi da YOGA/PILATES (es. dati di prova inseriti
    # in sviluppo, come "SS") vengono normalizzati a YOGA prima della
    # conversione a enum. Confermato dal committente: non sono dati reali
    # da preservare, sono scarti di test — quindi va bene sovrascriverli
    # invece di bloccare la migration.
    op.execute(
        "UPDATE course_participants "
        "SET course_type = 'YOGA' "
        "WHERE UPPER(course_type) NOT IN ('YOGA', 'PILATES')"
    )
    # UPPER() tollera dati storici scritti in minuscolo/misto (es.
    # "Pilates"); dopo la normalizzazione sopra, ogni valore rimasto è
    # garantito essere YOGA o PILATES in qualche variante di maiuscole.
    op.alter_column(
        "course_participants",
        "course_type",
        existing_type=sa.String(length=100),
        type_=course_type_enum,
        postgresql_using="UPPER(course_type)::course_type_enum",
        existing_nullable=False,
    )

    # --- members: pagamento, dichiarazioni/consensi, sicurezza minore ---
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

    # --- psychological_supports: nuova tabella ------------------------
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

    # --- members ------------------------------------------------------
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

    # --- course_participants ------------------------------------------
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

    # --- students -------------------------------------------------------
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

    # --- people -----------------------------------------------------
    op.drop_constraint(
        op.f("ck_people_birth_nation_no_surrounding_whitespace"),
        "people",
        type_="check",
    )
    op.drop_constraint(
        op.f("ck_people_birth_nation_not_blank"), "people", type_="check"
    )
    op.drop_column("people", "birth_nation")

    # I tipi enum vanno droppati per ultimi, solo dopo che nessuna
    # colonna li referenzia più.
    bind = op.get_bind()
    payment_method_enum.drop(bind, checkfirst=True)
    course_type_enum.drop(bind, checkfirst=True)
    certification_type_enum.drop(bind, checkfirst=True)