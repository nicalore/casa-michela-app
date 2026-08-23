from typing import Final

# Mirrored by frontend/lib/core/constants/field_limits.dart, which stops the
# typing before a form is sent: the two have to be changed together.
NAME: Final[int] = 255

DESCRIPTION: Final[int] = 1000

NOTES: Final[int] = 1000

TOPIC: Final[int] = 255

PERSON_NAME: Final[int] = 100
TAX_CODE: Final[int] = 16
CITY: Final[int] = 100
NATION: Final[int] = 100

PROVINCE: Final[int] = 2
POSTAL_CODE: Final[int] = 5

RESIDENCE_TYPE: Final[int] = 100
ADDRESS: Final[int] = 255
STREET_NUMBER: Final[int] = 20

EMAIL: Final[int] = 255
PHONE: Final[int] = 20

CONTACT_NAME: Final[int] = 200

IBAN: Final[int] = 27

EDUCATION: Final[int] = 500

OTHER_ROLE: Final[int] = 100
OTHER_DETAIL: Final[int] = 255

PICKUP_REASON: Final[int] = 500

REPORT_VALUE: Final[int] = 255

MECHANOGRAPHIC_CODE: Final[int] = 100
SECTOR: Final[int] = 100

USERNAME: Final[int] = 50
