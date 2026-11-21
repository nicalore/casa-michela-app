from datetime import date
from typing import Final

from fastapi import HTTPException, status

from app.core.birthdays import age_on
from app.models.membership import Membership, MembershipRevocationEnum
from app.models.membership_revocation import ExpulsionGroundEnum, MembershipRevocation
from app.models.person import Person
from app.schemas.person import RevokeMembershipPayload
from app.services.bilingual import Bilingual

_ADULT_AGE: Final[int] = 18

_NO_RESOLUTION_DATE_ERROR: Final[Bilingual] = Bilingual(
    "Indica la data della delibera di esclusione.",
    "Enter the date of the expulsion resolution.",
)
_FUTURE_RESOLUTION_ERROR: Final[Bilingual] = Bilingual(
    "La data della delibera non può essere nel futuro.",
    "The resolution date can't be in the future.",
)
_NO_GROUND_ERROR: Final[Bilingual] = Bilingual(
    "Indica almeno un motivo dell'esclusione.",
    "Choose at least one ground for the expulsion.",
)
_NO_OTHER_GROUND_ERROR: Final[Bilingual] = Bilingual(
    "Descrivi l'altro motivo dell'esclusione.",
    "Describe the other ground for the expulsion.",
)
_CHARGED_AFTER_RESOLUTION_ERROR: Final[Bilingual] = Bilingual(
    "Gli addebiti vanno contestati prima della delibera.",
    "The charges must be notified before the resolution.",
)
_EXPULSION_DATA_ON_RESIGNATION_ERROR: Final[Bilingual] = Bilingual(
    "Delibera, verbale, motivi e addebiti valgono solo per un'esclusione.",
    "Resolution, minutes, grounds and charges only apply to an expulsion.",
)
_REASON_ON_EXPULSION_ERROR: Final[Bilingual] = Bilingual(
    "La motivazione vale solo per un recesso.",
    "The reason only applies to a resignation.",
)
_NOT_A_PARENT_ERROR: Final[Bilingual] = Bilingual(
    "Il genitore indicato non risulta tra i genitori di questa persona.",
    "That parent isn't on record as this person's parent.",
)


def _refused(message: Bilingual) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail=message.for_request(),
    )


def _check_expulsion(payload: RevokeMembershipPayload, today: date) -> None:
    if payload.reason is not None:
        raise _refused(_REASON_ON_EXPULSION_ERROR)

    if payload.resolution_date is None:
        raise _refused(_NO_RESOLUTION_DATE_ERROR)

    if payload.resolution_date > today:
        raise _refused(_FUTURE_RESOLUTION_ERROR)

    if not payload.grounds:
        raise _refused(_NO_GROUND_ERROR)

    if (ExpulsionGroundEnum.OTHER in payload.grounds) != (
        payload.other_ground is not None
    ):
        raise _refused(_NO_OTHER_GROUND_ERROR)

    if payload.charged_on is not None and payload.charged_on > payload.resolution_date:
        raise _refused(_CHARGED_AFTER_RESOLUTION_ERROR)


def _check_resignation(payload: RevokeMembershipPayload) -> None:
    expulsion_data = (
        payload.resolution_date,
        payload.minutes_number,
        payload.other_ground,
        payload.charged_on,
    )

    if payload.grounds or any(value is not None for value in expulsion_data):
        raise _refused(_EXPULSION_DATA_ON_RESIGNATION_ERROR)


def is_minor_on(person: Person, day: date) -> bool:
    birth = person.birth_date

    return birth is not None and age_on(birth, day) < _ADULT_AGE


# A minor with one parent needs no choice; with two the client names one.
def _guardian(person: Person, asked: str | None, today: date) -> str | None:
    parents = [relation.parent_tax_code for relation in person.parental_relationships]

    if asked is not None:
        if asked.upper() not in parents:
            raise _refused(_NOT_A_PARENT_ERROR)

        return asked.upper()

    single = len(parents) == 1

    return parents[0] if single and is_minor_on(person, today) else None


def revocation_details(
    person: Person,
    membership: Membership,
    payload: RevokeMembershipPayload,
    *,
    today: date,
) -> MembershipRevocation:
    """Check the cessation form's data and shape it for the revoked membership."""
    if payload.revocation_type == MembershipRevocationEnum.EXPULSION:
        _check_expulsion(payload, today)

    else:
        _check_resignation(payload)

    grounds = set(payload.grounds)

    return MembershipRevocation(
        membership=membership,
        reason=payload.reason,
        resolution_date=payload.resolution_date,
        minutes_number=payload.minutes_number,
        ground_breach=ExpulsionGroundEnum.BREACH in grounds,
        ground_conduct=ExpulsionGroundEnum.CONDUCT in grounds,
        ground_harm=ExpulsionGroundEnum.HARM in grounds,
        ground_other=ExpulsionGroundEnum.OTHER in grounds,
        other_ground=payload.other_ground,
        charged_on=payload.charged_on,
        protocol_number=payload.protocol_number,
        card_number=payload.card_number,
        guardian_tax_code=_guardian(person, payload.guardian_tax_code, today),
    )
