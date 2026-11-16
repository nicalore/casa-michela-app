from io import BytesIO
from typing import Final, cast

from pypdf import PdfWriter
from pypdf.generic import (
    ArrayObject,
    DecodedStreamObject,
    DictionaryObject,
    FloatObject,
    NameObject,
    NumberObject,
    TextStringObject,
)

AGREED_FEES_FIELD: Final[str] = "quote_concordate"

# Second page, in points: cut between the payment line of section 8 and the bar
# of section 9; what lies between the cut and the footer moves down.
_PAGE: Final[int] = 1
_CUT: Final[float] = 418.0
_FOOT: Final[float] = 60.0
_SHIFT: Final[float] = 14.0
_WIDTH: Final[float] = 595.0
_HEIGHT: Final[float] = 842.0
_RECT: Final[tuple[float, float, float, float]] = (31.0, 404.5, 566.0, 416.5)

# The line under the rate table: the new one is written the same way.
_LOOK_FIELD: Final[str] = "tariffa_concordata"

_BODY: Final[str] = "/PageBody"


def _numbers(values: tuple[float, ...]) -> ArrayObject:
    return ArrayObject([FloatObject(value) for value in values])


def _page_body(writer: PdfWriter, page: DictionaryObject) -> None:
    """Draw the page as one form three times: above the cut, moved, the footer."""
    contents = page.get_contents()

    if contents is None:
        return

    body = DecodedStreamObject()
    body.set_data(contents.get_data())
    body.update(
        {
            NameObject("/Type"): NameObject("/XObject"),
            NameObject("/Subtype"): NameObject("/Form"),
            NameObject("/BBox"): _numbers((0, 0, _WIDTH, _HEIGHT)),
            NameObject("/Resources"): page["/Resources"],
        }
    )
    reference = writer._add_object(body.flate_encode())
    resources = cast(DictionaryObject, page["/Resources"].get_object())

    if "/XObject" not in resources:
        resources[NameObject("/XObject")] = DictionaryObject()

    xobjects = cast(DictionaryObject, resources["/XObject"].get_object())
    xobjects[NameObject(_BODY)] = reference

    moved = _CUT - _FOOT
    drawn = (
        f"q 0 {_CUT} {_WIDTH} {_HEIGHT - _CUT} re W n {_BODY} Do Q\n"
        f"q 0 {_FOOT - _SHIFT} {_WIDTH} {moved} re W n "
        f"1 0 0 1 0 {-_SHIFT} cm {_BODY} Do Q\n"
        f"q 0 0 {_WIDTH} {_FOOT} re W n {_BODY} Do Q\n"
    )
    stream = DecodedStreamObject()
    stream.set_data(drawn.encode())
    page.replace_contents(stream)


def with_agreed_fees_line(template: bytes) -> bytes:
    """The enrolment form with room under section 8 for the agreed fees line."""
    writer = PdfWriter(clone_from=BytesIO(template))
    page = writer.pages[_PAGE]

    _page_body(writer, page)

    for annotation in page.get("/Annots", []):
        widget = cast(DictionaryObject, annotation.get_object())
        left, bottom, right, top = (float(value) for value in widget["/Rect"])

        if _FOOT < top < _CUT:
            widget[NameObject("/Rect")] = _numbers(
                (left, bottom - _SHIFT, right, top - _SHIFT),
            )

    look = next(
        cast(DictionaryObject, annotation.get_object())
        for annotation in writer.pages[0]["/Annots"]
        if annotation.get_object().get("/T") == _LOOK_FIELD
    )
    field = DictionaryObject(
        {
            NameObject("/Type"): NameObject("/Annot"),
            NameObject("/Subtype"): NameObject("/Widget"),
            NameObject("/FT"): NameObject("/Tx"),
            NameObject("/T"): TextStringObject(AGREED_FEES_FIELD),
            NameObject("/Rect"): _numbers(_RECT),
            NameObject("/F"): NumberObject(4),
            NameObject("/DA"): look["/DA"],
            NameObject("/P"): page.indirect_reference,
        }
    )

    for key in ("/MK", "/Ff", "/Q"):
        if key in look:
            field[NameObject(key)] = look[key]

    reference = writer._add_object(field)
    cast(ArrayObject, page["/Annots"]).append(reference)
    acroform = cast(DictionaryObject, writer._root_object["/AcroForm"])
    cast(ArrayObject, acroform["/Fields"]).append(reference)

    out = BytesIO()
    writer.write(out)

    return out.getvalue()
