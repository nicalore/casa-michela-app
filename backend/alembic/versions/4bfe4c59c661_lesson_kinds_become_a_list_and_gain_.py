"""lesson kinds become a list and gain study

Un'ora è spesso due cose insieme — si ripassa per l'interrogazione e intanto si
fanno i compiti — e chiederne una sola costringeva a buttare via metà della
risposta. Il tipo diventa quindi una lista, e ne arriva uno nuovo: "studio".

Nessuna riga si perde: quello che era il tipo singolo diventa una lista di uno,
e chi non ne aveva prende la lista vuota.

Il valore nuovo dell'enum va aggiunto fuori dalla transazione della migrazione:
un ALTER TYPE ... ADD VALUE non è utilizzabile nella stessa transazione che lo
dichiara, e la colonna qui sotto lo usa subito.

Revision ID: 4bfe4c59c661
Revises: d6ec2503a510
Create Date: 2026-08-04 16:30:52.883385

"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

# revision identifiers, used by Alembic.
revision = "4bfe4c59c661"
down_revision = "d6ec2503a510"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("COMMIT")
    op.execute("ALTER TYPE booking_tag_enum ADD VALUE IF NOT EXISTS 'STUDY'")

    op.add_column(
        "bookings",
        sa.Column(
            "tags",
            postgresql.ARRAY(
                postgresql.ENUM(name="booking_tag_enum", create_type=False)
            ),
            nullable=False,
            server_default="{}",
        ),
    )

    # Quello che era scritto resta: un tipo solo diventa una lista di uno.
    op.execute("UPDATE bookings SET tags = ARRAY[tag] WHERE tag IS NOT NULL")

    # Il servizio non ha tipo: il CHECK ora conta la lista invece della colonna.
    op.drop_constraint(
        op.f("ck_bookings_booking_service_has_no_tag_or_topic"),
        "bookings",
        type_="check",
    )
    op.drop_column("bookings", "tag")
    op.create_check_constraint(
        op.f("ck_bookings_booking_service_has_no_tag_or_topic"),
        "bookings",
        "service_name IS NULL OR (cardinality(tags) = 0 AND topic IS NULL)",
    )


def downgrade() -> None:
    op.drop_constraint(
        op.f("ck_bookings_booking_service_has_no_tag_or_topic"),
        "bookings",
        type_="check",
    )

    op.add_column(
        "bookings",
        sa.Column(
            "tag",
            postgresql.ENUM(name="booking_tag_enum", create_type=False),
            nullable=True,
        ),
    )

    # Torna indietro il primo, che è tutto quello che una colonna sola può
    # tenere; gli altri si perdono, e non c'è dove metterli.
    op.execute("UPDATE bookings SET tag = tags[1] WHERE cardinality(tags) > 0")

    op.drop_column("bookings", "tags")
    op.create_check_constraint(
        op.f("ck_bookings_booking_service_has_no_tag_or_topic"),
        "bookings",
        "service_name IS NULL OR (tag IS NULL AND topic IS NULL)",
    )

    # Il valore aggiunto all'enum resta: Postgres non sa togliere un valore da
    # un tipo, e ricrearlo qui vorrebbe dire riscrivere ogni colonna che lo usa.
