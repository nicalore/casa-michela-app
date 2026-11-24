from dataclasses import dataclass
from datetime import UTC, date, datetime
from typing import Final

from fastapi import HTTPException, UploadFile, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import undefer

from app.core import field_lengths
from app.models.confirmed_hours import ConfirmedHours
from app.models.payment_receipt import PaymentReceipt
from app.models.person import GenderEnum
from app.models.teacher import Teacher
from app.repositories.person_repository import PersonRepository
from app.services.bilingual import Bilingual
from app.services.compensation import load_terms
from app.services.worked_hours import month_after

MAX_RECEIPT_BYTES: Final[int] = 15 * 1024 * 1024

_TEACHER_NOT_FOUND_ERROR: Final[Bilingual] = Bilingual(
    "Docente non trovato.",
    "Teacher not found.",
)
_RECEIPT_NOT_FOUND_ERROR: Final[Bilingual] = Bilingual(
    "Ricevuta non trovata.",
    "Receipt not found.",
)
_NOT_PAID_ERROR: Final[Bilingual] = Bilingual(
    "La ricevuta può essere caricata solo a chi è retribuito.",
    "A receipt can be uploaded only for paid staff.",
)
_NO_HOURS_ERROR: Final[Bilingual] = Bilingual(
    "La ricevuta può essere caricata solo a chi ha ore lavorate.",
    "A receipt can be uploaded only for those with hours worked.",
)
_OPENING_PENDING_ERRORS: Final[dict[GenderEnum, Bilingual]] = {
    GenderEnum.M: Bilingual(
        "Prima configura il docente in Contabilità › Configurazione iniziale.",
        "First set up the teacher in Accounting › Initial setup.",
    ),
    GenderEnum.F: Bilingual(
        "Prima configura la docente in Contabilità › Configurazione iniziale.",
        "First set up the teacher in Accounting › Initial setup.",
    ),
}
_TOO_LARGE_ERROR: Final[Bilingual] = Bilingual(
    "La ricevuta supera i 15 MB.",
    "The receipt exceeds 15 MB.",
)
_WRONG_KIND_ERROR: Final[Bilingual] = Bilingual(
    "La ricevuta deve essere un PDF o una foto JPG o PNG.",
    "The receipt must be a PDF or a JPG or PNG photo.",
)

_DEFAULT_FILE_NAME: Final[str] = "ricevuta"

# Told by the first bytes, never by the name or the browser: the file is served
# back with this type.
_SIGNATURES: Final[tuple[tuple[bytes, str], ...]] = (
    (b"%PDF-", "application/pdf"),
    (b"\xff\xd8\xff", "image/jpeg"),
    (b"\x89PNG\r\n\x1a\n", "image/png"),
)


@dataclass(frozen=True)
class ReceiptInfo:
    file_name: str
    content_type: str
    size: int
    uploaded_at: datetime


def _info(receipt: PaymentReceipt) -> ReceiptInfo:
    return ReceiptInfo(
        file_name=receipt.file_name,
        content_type=receipt.content_type,
        size=receipt.size,
        uploaded_at=receipt.uploaded_at,
    )


def _kind_of(content: bytes) -> str | None:
    return next(
        (kind for signature, kind in _SIGNATURES if content.startswith(signature)),
        None,
    )


def _file_name(name: str | None) -> str:
    cleaned = (name or "").strip().replace("/", "_").replace("\\", "_")

    if not cleaned:
        return _DEFAULT_FILE_NAME

    if len(cleaned) <= field_lengths.FILE_NAME:
        return cleaned

    stem, dot, extension = cleaned.rpartition(".")

    if not dot or len(extension) > 10:
        return cleaned[: field_lengths.FILE_NAME]

    return stem[: field_lengths.FILE_NAME - len(extension) - 1] + "." + extension


async def _readable(file: UploadFile) -> tuple[bytes, str]:
    # Refused before reading when the client declared the size.
    if file.size is not None and file.size > MAX_RECEIPT_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_CONTENT_TOO_LARGE,
            detail=_TOO_LARGE_ERROR.for_request(),
        )

    content = await file.read(MAX_RECEIPT_BYTES + 1)

    if len(content) > MAX_RECEIPT_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_CONTENT_TOO_LARGE,
            detail=_TOO_LARGE_ERROR.for_request(),
        )

    kind = _kind_of(content)

    if kind is None:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=_WRONG_KIND_ERROR.for_request(),
        )

    return content, kind


# One teacher's receipt of the month, without its bytes.
async def receipt_of(
    db: AsyncSession,
    tax_code: str,
    month: date,
) -> ReceiptInfo | None:
    receipt = await db.get(PaymentReceipt, (tax_code, month))

    return None if receipt is None else _info(receipt)


# The month's receipts by teacher, without their bytes.
async def receipts_of_month(db: AsyncSession, month: date) -> dict[str, ReceiptInfo]:
    receipts = await db.scalars(
        select(PaymentReceipt).where(PaymentReceipt.month == month),
    )

    return {receipt.staff_tax_code: _info(receipt) for receipt in receipts}


# A new upload takes the place of the month's receipt, if there was one.
async def store_receipt(
    db: AsyncSession,
    tax_code: str,
    month: date,
    file: UploadFile,
    author_tax_code: str,
) -> None:
    if await db.get(Teacher, tax_code) is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_TEACHER_NOT_FOUND_ERROR.for_request(),
        )

    timeline = await load_terms(db, tax_code)

    if not timeline.of_month(month).is_paid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_NOT_PAID_ERROR.for_request(),
        )

    # The month's pay is not known while its initial set-up waits.
    if timeline.pending_in(month):
        gender = await PersonRepository(db).gender(tax_code)

        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=_OPENING_PENDING_ERRORS[gender].for_request(),
        )

    content, kind = await _readable(file)

    # As the monthly summary lists them: only who has confirmed hours in the month.
    worked = await db.scalar(
        select(ConfirmedHours.id)
        .where(
            ConfirmedHours.teacher_tax_code == tax_code,
            ConfirmedHours.date >= month,
            ConfirmedHours.date < month_after(month),
        )
        .limit(1),
    )

    if worked is None and not timeline.opening_in(month):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_NO_HOURS_ERROR.for_request(),
        )

    receipt = await db.get(PaymentReceipt, (tax_code, month))

    if receipt is None:
        receipt = PaymentReceipt(staff_tax_code=tax_code, month=month)
        db.add(receipt)

    receipt.file_name = _file_name(file.filename)
    receipt.content_type = kind
    receipt.size = len(content)
    receipt.content = content
    # Set here, not by the database: the summary read next needs it in this session.
    receipt.uploaded_at = datetime.now(UTC)
    receipt.uploaded_by_tax_code = author_tax_code

    await db.flush()


async def receipt_file(db: AsyncSession, tax_code: str, month: date) -> PaymentReceipt:
    receipt = await db.scalar(
        select(PaymentReceipt)
        .where(
            PaymentReceipt.staff_tax_code == tax_code,
            PaymentReceipt.month == month,
        )
        .options(undefer(PaymentReceipt.content)),
    )

    if receipt is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_RECEIPT_NOT_FOUND_ERROR.for_request(),
        )

    return receipt


async def delete_receipt(db: AsyncSession, tax_code: str, month: date) -> None:
    receipt = await db.get(PaymentReceipt, (tax_code, month))

    if receipt is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=_RECEIPT_NOT_FOUND_ERROR.for_request(),
        )

    await db.delete(receipt)
    await db.flush()
