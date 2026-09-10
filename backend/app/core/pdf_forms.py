import json
import math
import re
from collections.abc import Mapping
from functools import lru_cache
from io import BytesIO
from pathlib import Path
from typing import Any, Final

from fontTools.ttLib import TTFont
from pypdf import PdfWriter
from pypdf._font import Font
from pypdf.generic import (
    ArrayObject,
    DictionaryObject,
    NameObject,
    NumberObject,
    StreamObject,
)

# Bit 1 of /Ff (PDF 32000-1 table 221): makes the field read-only.
_READ_ONLY_FLAG: Final[int] = 1

# Every text widget of the template declares /MaxLen 100; pypdf does not enforce it on /V.
_MAX_TEXT_LENGTH: Final[int] = 100

# Size in a widget's own /DA, as in "/Helv 8 Tf 0 0 0 rg": the template's choice to make.
_FONT_SIZE_IN_DA: Final[re.Pattern[str]] = re.compile(r"/\S+\s+([\d.]+)\s+Tf")

_DEFAULT_FONT_SIZE: Final[float] = 8.0

_EMBEDDED_FONT_NAME: Final[str] = "/AppFont"

# pypdf floors a widget's margin at 1pt and clips the appearance to what is left.
_FIELD_MARGIN: Final[float] = 1.0

# Font metrics travel in thousandths of an em whatever the font's own grid is.
_GLYPH_SPACE: Final[int] = 1000

# Accented capitals are left out on purpose: they reach far higher (999 units against
# 790 for an accented lowercase) and sizing around them would shrink every cell.
_INK_SAMPLE: Final[str] = (
    "abcdefghijklmnopqrstuvwxyz"
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    "0123456789.,;:/@-'àèéìòù"
)


class FormFieldMap:
    """The template's field inventory, as described by the JSON map."""

    def __init__(self, raw: dict[str, Any]) -> None:
        meta = raw["_meta"]

        self.checked: str = meta["checkbox_valore_spunta"]
        self.unchecked: str = meta["checkbox_valore_vuoto"]

        self.page_by_field: dict[str, int] = {
            name: field["pagina"] for name, field in raw["campi"].items()
        }

        self.kind_by_field: dict[str, str] = {
            name: field["tipo"] for name, field in raw["campi"].items()
        }

    def group_by_page(self, values: Mapping[str, str]) -> dict[int, dict[str, str]]:
        by_page: dict[int, dict[str, str]] = {}

        for name, value in values.items():
            page = self.page_by_field.get(name)

            if page is None:
                raise KeyError(name)

            by_page.setdefault(page, {})[name] = value

        return by_page


@lru_cache(maxsize=4)
def form_field_map(path: Path) -> FormFieldMap:
    return FormFieldMap(json.loads(path.read_text(encoding="utf-8")))


@lru_cache(maxsize=8)
def asset_bytes(path: Path) -> bytes:
    return path.read_bytes()


def fill_acroform(
    template: bytes,
    values_by_page: Mapping[int, Mapping[str, str]],
    *,
    font: bytes | None = None,
) -> bytes:
    """Stamp values into a copy of an AcroForm template and lock every field."""
    writer = PdfWriter(clone_from=BytesIO(template))
    ink = _ink_box(font) if font else None
    widths = _advance_widths(font) if font else None
    font_name = _embed_font(writer, font, ink) if font and ink else None

    for number, page in enumerate(writer.pages, start=1):
        given = values_by_page.get(number, {})
        values: dict[str, Any] = {}

        for name, widget in _text_fields(page).items():
            # Empty fields too: regenerating their appearance drops the template's tint.
            value = _clipped(given.get(name, ""))
            size = _fitted_size(widget, ink, value, widths)
            values[name] = (value, font_name, size) if font_name else value

        for name, value in given.items():
            values.setdefault(name, _clipped(value))

        if not values:
            continue

        # No /NeedAppearances: every appearance is drawn here and the fields are read-only.
        writer.update_page_form_field_values(page, values, auto_regenerate=False)

    _drop_field_tint(writer)
    _lock_fields(writer)

    buffer = BytesIO()
    writer.write(buffer)

    return buffer.getvalue()


def _clipped(value: str) -> str:
    return value[:_MAX_TEXT_LENGTH]


def _text_fields(page: Any) -> dict[str, DictionaryObject]:
    widgets: dict[str, DictionaryObject] = {}

    for annotation in page.get("/Annots", []):
        widget = annotation.get_object()

        if widget.get("/FT") != "/Tx":
            continue

        name = widget.get("/T")

        if name is not None:
            widgets[name] = widget

    return widgets


def _fitted_size(
    widget: DictionaryObject,
    ink: tuple[float, float] | None,
    value: str,
    widths: Mapping[int, int] | None,
) -> float:
    asked = _font_size_of(widget)

    if ink is None:
        return asked

    top, depth = ink
    rectangle = widget["/Rect"]
    height = abs(float(rectangle[3]) - float(rectangle[1])) - 2 * _FIELD_MARGIN

    # A line taller than its cell would have its tails clipped away.
    fits = height * _GLYPH_SPACE / (top + depth)

    # An overlong line is not clipped: it runs over the next column, so shrink it.
    if widths is not None and value:
        run = _run_length(value, widths)

        if run > 0:
            usable = abs(float(rectangle[2]) - float(rectangle[0])) - 2 * _FIELD_MARGIN
            fits = min(fits, usable * _GLYPH_SPACE / run)

    return min(asked, math.floor(fits * 10) / 10)


# Width of the value in thousandths of an em, the grid the height arithmetic uses.
def _run_length(value: str, widths: Mapping[int, int]) -> int:
    return sum(widths.get(ord(character), 0) for character in value)


# Advance widths by codepoint, in thousandths of an em.
@lru_cache(maxsize=4)
def _advance_widths(font: bytes) -> dict[int, int] | None:
    try:
        parsed = TTFont(BytesIO(font))
        metrics = parsed["hmtx"]
        by_code = parsed.getBestCmap()
        per_em = parsed["head"].unitsPerEm

    except Exception:
        return None

    scale = _GLYPH_SPACE / per_em

    return {
        code: round(metrics[name][0] * scale)
        for code, name in by_code.items()
        if name in metrics.metrics
    }


def _font_size_of(widget: DictionaryObject) -> float:
    match = _FONT_SIZE_IN_DA.search(str(widget.get("/DA", "")))

    if match is None:
        return _DEFAULT_FONT_SIZE

    size = float(match.group(1))

    # An autosizing /DA says 0; the appearance we draw needs a real number.
    return size or _DEFAULT_FONT_SIZE


# Ink reach above and below the baseline, in thousandths of an em. Read from the
# glyphs, not the declared ascent, which is a line-height figure (1038 per 1000 em).
@lru_cache(maxsize=4)
def _ink_box(font: bytes) -> tuple[float, float] | None:
    try:
        parsed = TTFont(BytesIO(font))
        glyphs = parsed["glyf"]
        by_code = parsed.getBestCmap()
        per_em = parsed["head"].unitsPerEm

    except Exception:
        return None

    tops: list[int] = []
    bottoms: list[int] = []

    for character in _INK_SAMPLE:
        name = by_code.get(ord(character))

        if name is None:
            continue

        glyph = glyphs[name]

        if glyph.numberOfContours == 0:
            continue

        tops.append(glyph.yMax)
        bottoms.append(glyph.yMin)

    if not tops:
        return None

    scale = _GLYPH_SPACE / per_em

    return max(tops) * scale, -min(bottoms) * scale


# pypdf nests the font resource's streams inline, but a PDF stream must be indirect.
def _embed_font(writer: PdfWriter, font: bytes, ink: tuple[float, float]) -> str:
    resource = Font.from_truetype_font_file(BytesIO(font)).as_font_resource()

    if isinstance(resource.get("/ToUnicode"), StreamObject):
        resource[NameObject("/ToUnicode")] = writer._add_object(resource["/ToUnicode"])

    descendant = resource["/DescendantFonts"][0]
    descriptor = descendant["/FontDescriptor"]

    # pypdf baselines at margin + (height - ascent x size) / 2, centring on /Ascent alone;
    # feeding it (ink above - ink below) makes that arithmetic centre the ink box instead.
    top, depth = ink
    descriptor[NameObject("/Ascent")] = NumberObject(round(top - depth))

    descriptor[NameObject("/FontFile2")] = writer._add_object(descriptor["/FontFile2"])
    descendant[NameObject("/FontDescriptor")] = writer._add_object(descriptor)
    resource[NameObject("/DescendantFonts")] = ArrayObject(
        [writer._add_object(descendant)]
    )

    fonts = writer.root_object["/AcroForm"]["/DR"][NameObject("/Font")]
    fonts[NameObject(_EMBEDDED_FONT_NAME)] = writer._add_object(resource)

    return _EMBEDDED_FONT_NAME


# The tint is printed into the page, not viewer highlighting: /MK /BG plus the
# appearance stream. Regenerating appearances drops the second, this the first.
def _drop_field_tint(writer: PdfWriter) -> None:
    for page in writer.pages:
        for annotation in page.get("/Annots", []):
            characteristics = annotation.get_object().get("/MK")

            if isinstance(characteristics, DictionaryObject):
                characteristics.pop("/BG", None)


def _lock_fields(writer: PdfWriter) -> None:
    acro_form = writer.root_object["/AcroForm"]

    for reference in acro_form["/Fields"]:
        field = reference.get_object()

        if not isinstance(field, DictionaryObject):
            continue

        flags = int(field.get(NameObject("/Ff"), 0))
        field[NameObject("/Ff")] = NumberObject(flags | _READ_ONLY_FLAG)
