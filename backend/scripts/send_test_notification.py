# Sends the test notification to everyone who can sign in, or to one person.
# Usage: python -m scripts.send_test_notification [--tax-code CODE]

import argparse
import asyncio
from typing import Final

from app.db.session import AsyncSessionLocal
from app.models.notification import NotificationKindEnum
from app.services import apns, fcm, push
from app.services.notifications import notify, reachable_accounts

TITLE: Final[str] = "Notifica di prova"
BODY: Final[str] = "Se leggi questo messaggio, le notifiche di Casa Michela funzionano."


async def main(tax_code: str | None) -> None:
    async with AsyncSessionLocal() as session:
        reachable = await reachable_accounts(session)
        recipients = [tax_code] if tax_code else reachable

        if tax_code and tax_code not in reachable:
            print(f"{tax_code}: nessun account attivo con questo codice fiscale.")
            return

        batch = await notify(
            session,
            recipients,
            kind=NotificationKindEnum.TEST,
            title=TITLE,
            body=BODY,
        )
        await session.commit()

    gone = await push.send_batch(batch)

    async with AsyncSessionLocal() as session:
        await push.forget(session, gone)

    print(f"Notifica creata per {len(recipients)} persone.")

    if batch.web and not push.web_push_enabled():
        print("Chiavi VAPID mancanti in backend/.env: nessun push ai browser.")

    if batch.android and not fcm.fcm_enabled():
        print("Chiave Firebase mancante in backend/.env: nessun push ad Android.")

    if batch.ios and not apns.apns_enabled():
        print("Chiave Apple mancante in backend/.env: nessun push a iPhone e iPad.")

    print(
        f"Push tentati: {len(batch.web)} browser, {len(batch.android)} Android, "
        f"{len(batch.ios)} iOS; "
        f"{len(gone)} indirizzi scaduti rimossi."
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Invia la notifica di prova")
    parser.add_argument(
        "--tax-code",
        default=None,
        help="Codice fiscale di una sola persona. Default: tutti.",
    )
    args = parser.parse_args()

    asyncio.run(main(args.tax_code.upper() if args.tax_code else None))
