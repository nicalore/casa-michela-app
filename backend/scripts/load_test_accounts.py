"""
Script per creare/eliminare account di test per il load testing (TC-IAM-135).

Uso:
    python -m scripts.load_test_accounts create        # crea 100 account
    python -m scripts.load_test_accounts create -n 50  # crea 50 account
    python -m scripts.load_test_accounts delete        # elimina tutti gli account di test
    python -m scripts.load_test_accounts list          # mostra quanti account di test esistono

Gli account sono identificabili dal prefisso 'LDT' nelle prime lettere del
codice fiscale (che è comunque sintatticamente valido, checksum incluso,
per superare la validazione di Person). Nessuna persona reale può avere
per puro caso proprio quel prefisso combinato con nome/cognome 'Load
Test', quindi la delete è sicura.
"""

import argparse
import asyncio
import csv
from datetime import date
from pathlib import Path

from sqlalchemy import delete, func, select

from app.core.security import hash_password
from app.db.session import AsyncSessionLocal
from app.models.account import Account, AccountStatusEnum
from app.models.person import GenderEnum, Person
from app.models.refresh_token import RefreshToken

TEST_PASSWORD = "LoadTest!2026#Cm"

CREDENTIALS_FILE = Path("scripts/load_test_credentials.csv")

TEST_LAST_NAME_PREFIX = "LoadTest"

_ODD_VALUES = {
    "0": 1, "1": 0, "2": 5, "3": 7, "4": 9, "5": 13, "6": 15, "7": 17, "8": 19, "9": 21,
    "A": 1, "B": 0, "C": 5, "D": 7, "E": 9, "F": 13, "G": 15, "H": 17, "I": 19, "J": 21,
    "K": 2, "L": 4, "M": 18, "N": 20, "O": 11, "P": 3, "Q": 6, "R": 8, "S": 12, "T": 14,
    "U": 16, "V": 10, "W": 22, "X": 25, "Y": 24, "Z": 23,
}
_EVEN_VALUES = {str(d): d for d in range(10)}
_EVEN_VALUES.update({chr(65 + i): i for i in range(26)})

_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"


def _compute_check_char(code_15: str) -> str:
    """Calcola il 16° carattere (check character) di un codice fiscale."""
    total = 0
    for position, char in enumerate(code_15, start=1):
        total += _ODD_VALUES[char] if position % 2 == 1 else _EVEN_VALUES[char]
    return _ALPHABET[total % 26]


def _num_to_letters(n: int, length: int = 3) -> str:
    """Converte un intero in una sequenza di N lettere (base 26), per
    garantire unicità nella parte 'cognome/nome' del CF sintetico."""
    letters = ""
    for _ in range(length):
        letters = chr(65 + n % 26) + letters
        n //= 26
    return letters


def _make_tax_code(i: int) -> str:
    """
    Genera un codice fiscale sintetico ma sintatticamente valido
    (formato + checksum corretti), univoco per ogni indice i.

    Struttura (identica al formato reale, dati ovviamente fittizi):
      LDT + 3 lettere derivate da i   -> 6 lettere (pseudo cognome+nome)
      00                              -> 2 cifre (anno)
      A                               -> 1 lettera (mese)
      01                              -> 2 cifre (giorno+sesso)
      Z                               -> 1 lettera (comune)
      i su 3 cifre                    -> 3 cifre (progressivo comune)
      [calcolato]                     -> 1 lettera di controllo
    """
    base = f"LDT{_num_to_letters(i)}00A01Z{i:03d}"
    return base + _compute_check_char(base)


def _make_username(i: int) -> str:
    return f"loadtest{i:04d}"


async def create_accounts(count: int) -> None:
    password_hash = hash_password(TEST_PASSWORD)

    async with AsyncSessionLocal() as session:
        existing = await session.scalar(
            select(func.count())
            .select_from(Person)
            .where(Person.last_name.like(f"{TEST_LAST_NAME_PREFIX}%"))
        )
        if existing:
            print(f"Esistono già {existing} account di test. Esegui prima 'delete'.")
            return

        for i in range(1, count + 1):
            tax_code = _make_tax_code(i)

            session.add(Person(
                tax_code=tax_code,
                first_name="Load",
                last_name=f"{TEST_LAST_NAME_PREFIX}{i:04d}",
                gender=GenderEnum.M,
                birth_date=date(1990, 1, 1),
                birth_city="Testville",
                birth_province="XX",
                email=f"loadtest{i:04d}@test.invalid",
                phone=f"+390000{i:06d}",
                residence_type="Via",
                residence_address="Di Test",
                residence_street_number="1",
                residence_city="Testville",
                residence_province="XX",
                postal_code="00000",
            ))

            session.add(Account(
                tax_code=tax_code,
                username=_make_username(i),
                password_hash=password_hash,
                status=AccountStatusEnum.ACTIVE,
                failed_login_attempts=0,
                password_reset_required=False,
            ))

        await session.commit()

    CREDENTIALS_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(CREDENTIALS_FILE, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["username", "password"])
        for i in range(1, count + 1):
            writer.writerow([_make_username(i), TEST_PASSWORD])

    print(f"Creati {count} account di test.")
    print(f"Credenziali esportate in {CREDENTIALS_FILE}")


async def delete_accounts() -> None:
    async with AsyncSessionLocal() as session:
        tax_codes = (await session.execute(
            select(Person.tax_code).where(Person.last_name.like(f"{TEST_LAST_NAME_PREFIX}%"))
        )).scalars().all()

        if not tax_codes:
            print("Nessun account di test trovato.")
            return

        await session.execute(
            delete(RefreshToken).where(RefreshToken.account_tax_code.in_(tax_codes))
        )
        await session.execute(
            delete(Account).where(Account.tax_code.in_(tax_codes))
        )
        await session.execute(
            delete(Person).where(Person.tax_code.in_(tax_codes))
        )

        await session.commit()

    CREDENTIALS_FILE.unlink(missing_ok=True)

    print(f"Eliminati {len(tax_codes)} account di test (e relativi refresh token).")


async def list_accounts() -> None:
    async with AsyncSessionLocal() as session:
        count = await session.scalar(
            select(func.count())
            .select_from(Person)
            .where(Person.last_name.like(f"{TEST_LAST_NAME_PREFIX}%"))
        )
    print(f"Account di test presenti: {count or 0}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Gestione account di test per load testing")
    subparsers = parser.add_subparsers(dest="command", required=True)

    create_parser = subparsers.add_parser("create", help="Crea gli account di test")
    create_parser.add_argument("-n", "--count", type=int, default=100, help="Numero di account (default: 100)")

    subparsers.add_parser("delete", help="Elimina tutti gli account di test")
    subparsers.add_parser("list", help="Conta gli account di test presenti")

    args = parser.parse_args()

    if args.command == "create":
        asyncio.run(create_accounts(args.count))
    elif args.command == "delete":
        asyncio.run(delete_accounts())
    elif args.command == "list":
        asyncio.run(list_accounts())


if __name__ == "__main__":
    main()