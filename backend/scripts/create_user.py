from datetime import date
from enum import Enum
from getpass import getpass

from sqlalchemy import select

from app.core.security import hash_password
from app.db.session import AsyncSessionLocal
from app.models.account import (
    Account,
    AccountStatusEnum,
)
from app.models.administrator import (
    Administrator,
    AdministratorRoleEnum,
)
from app.models.course_participant import Courseparticipant
from app.models.member import Member
from app.models.membership import (
    Membership,
    MembershipRevocationEnum,
)
from app.models.parent import Parent
from app.models.person import (
    GenderEnum,
    Person,
)
from app.models.psychologist import Psychologist
from app.models.staff import (
    CollaborationTypeEnum,
    Staff,
)
from app.models.student import Student
from app.models.teacher import Teacher


class Role(Enum):
    PARENT = 1
    STUDENT = 2
    COURSE_PARTICIPANT = 3
    TEACHER = 4
    PSYCHOLOGIST = 5
    ADMINISTRATOR = 6


def ask(prompt: str) -> str:
    return input(f"{prompt}: ").strip()


def ask_bool(prompt: str) -> bool:
    while True:
        value = input(f"{prompt} [y/n]: ").strip().lower()

        if value in {"y", "yes"}:
            return True

        if value in {"n", "no"}:
            return False

        print("Valore non valido.")


def ask_roles() -> set[Role]:
    print(
        """
Ruoli disponibili:

1) Parent
2) Student
3) Course Participant
4) Teacher
5) Psychologist
6) Administrator
"""
    )

    raw = ask("Inserisci i numeri separati da virgola")

    selected = set()

    for token in raw.split(","):
        selected.add(Role(int(token.strip())))

    return selected


async def main() -> None:

    # ==========================
    # DATI ANAGRAFICI
    # ==========================

    tax_code = ask("Codice fiscale").upper()

    first_name = ask("Nome")
    last_name = ask("Cognome")

    gender = GenderEnum(ask("Sesso (M/F)").upper())

    birth_date = date.fromisoformat(ask("Data nascita (YYYY-MM-DD)"))

    birth_city = ask("Comune nascita")

    birth_province = ask("Provincia nascita (XX)").upper()

    email = ask("Email")

    phone = ask("Telefono")

    residence_type = ask("Tipo residenza")

    residence_address = ask("Via/Piazza")

    residence_street_number = ask("Numero civico")

    residence_city = ask("Comune residenza")

    residence_province = ask("Provincia residenza (XX)").upper()

    postal_code = ask("CAP")

    roles = ask_roles()

    needs_membership = bool(
        {
            Role.STUDENT,
            Role.COURSE_PARTICIPANT,
            Role.TEACHER,
            Role.PSYCHOLOGIST,
            Role.ADMINISTRATOR,
        }
        & roles
    )

    needs_staff = bool(
        {
            Role.TEACHER,
            Role.PSYCHOLOGIST,
            Role.ADMINISTRATOR,
        }
        & roles
    )

    # ==========================
    # DATI SPECIFICI
    # ==========================

    student_early_exit = False

    if Role.STUDENT in roles:
        student_early_exit = ask_bool("Uscita autonoma autorizzata")

    course_type = None
    medical_certificate_expiration = None

    if Role.COURSE_PARTICIPANT in roles:
        course_type = ask("Tipo corso")

        medical_certificate_expiration = date.fromisoformat(
            ask("Scadenza certificato medico (YYYY-MM-DD)")
        )

    collaboration_type = None
    iban = None

    if needs_staff:
        collaboration_type = CollaborationTypeEnum(
            ask("Tipo collaborazione (VOLUNTEER/PAID/PCTO)").upper()
        )

        if collaboration_type == CollaborationTypeEnum.PAID:
            iban = ask("IBAN").upper()

    school_education = None
    university_education = None

    if Role.TEACHER in roles:
        school_education = ask("Titolo scuola superiore")

        university_education = ask("Titolo universitario")

    admin_role = None
    other_role = None

    if Role.ADMINISTRATOR in roles:
        admin_role = AdministratorRoleEnum(
            ask("Ruolo (PRESIDENT/VICE_PRESIDENT/TREASURER/OTHER)").upper()
        )

        if admin_role == AdministratorRoleEnum.OTHER:
            other_role = ask("Descrizione ruolo")

    # ==========================
    # ACCOUNT
    # ==========================

    create_account = ask_bool("Creare account")

    username = None
    password_hash = None

    if create_account:
        username = ask("Username")

        password = getpass("Password temporanea: ")

        confirm = getpass("Conferma password: ")

        if password != confirm:
            raise ValueError("Le password non coincidono")

        password_hash = hash_password(password)

    # ==========================
    # RIEPILOGO
    # ==========================

    print("\n====================")
    print(f"{first_name} {last_name}")
    print(tax_code)

    print("\nRuoli:")

    for role in roles:
        print(f" - {role.name}")

    if create_account:
        print(f"\nAccount: {username}")

    print("====================\n")

    if not ask_bool("Confermare creazione"):
        print("Operazione annullata.")
        return

    # ==========================
    # PERSISTENZA
    # ==========================

    async with AsyncSessionLocal() as session:
        existing = await session.scalar(
            select(Person).where(Person.tax_code == tax_code)
        )

        if existing:
            raise ValueError("Esiste già una persona con questo codice fiscale")

        person = Person(
            tax_code=tax_code,
            first_name=first_name,
            last_name=last_name,
            gender=gender,
            birth_date=birth_date,
            birth_city=birth_city,
            birth_province=birth_province,
            email=email,
            phone=phone,
            residence_type=residence_type,
            residence_address=residence_address,
            residence_street_number=residence_street_number,
            residence_city=residence_city,
            residence_province=residence_province,
            postal_code=postal_code,
        )

        session.add(person)

        if Role.PARENT in roles:
            session.add(Parent(tax_code=tax_code))

        if needs_membership:
            session.add(Member(tax_code=tax_code))

            today = date.today()

            session.add(
                Membership(
                    member_tax_code=tax_code,
                    year=today.year,
                    start_date=today,
                    end_date=date(
                        today.year,
                        12,
                        31,
                    ),
                    renewal_period_days=30,
                    revocation=MembershipRevocationEnum.NO,
                )
            )

        if Role.STUDENT in roles:
            session.add(
                Student(
                    tax_code=tax_code,
                    authorized_early_exit=student_early_exit,
                )
            )

        if Role.COURSE_PARTICIPANT in roles:
            session.add(
                Courseparticipant(
                    tax_code=tax_code,
                    course_type=course_type,
                    medical_certificate_expiration=medical_certificate_expiration,
                )
            )

        if needs_staff:
            session.add(
                Staff(
                    tax_code=tax_code,
                    collaboration_type=collaboration_type,
                    iban=iban,
                )
            )

        if Role.TEACHER in roles:
            session.add(
                Teacher(
                    tax_code=tax_code,
                    school_education=school_education,
                    university_education=university_education,
                )
            )

        if Role.PSYCHOLOGIST in roles:
            session.add(Psychologist(tax_code=tax_code))

        if Role.ADMINISTRATOR in roles:
            session.add(
                Administrator(
                    tax_code=tax_code,
                    role=admin_role,
                    other_role=other_role,
                )
            )

        if create_account:
            session.add(
                Account(
                    tax_code=tax_code,
                    username=username,
                    password_hash=password_hash,
                    status=AccountStatusEnum.ACTIVE,
                    failed_login_attempts=0,
                    password_reset_required=True,
                )
            )

        await session.commit()

        print("\nPersona creata correttamente.")


if __name__ == "__main__":
    import asyncio

    asyncio.run(main())
