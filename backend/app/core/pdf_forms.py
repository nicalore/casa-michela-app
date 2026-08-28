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

# Bit 1 of /Ff (PDF 32000-1, table 221): the viewer refuses every edit. Set on
# every field of a generated form, which is a record of what was typed into the
# wizard and not a document to fill in again.
_READ_ONLY_FLAG: Final[int] = 1

# Every text widget of the template declares /MaxLen 100. pypdf does not
# enforce it on /V, so a longer value would survive here and be refused the
# moment someone re-opened the field.
_MAX_TEXT_LENGTH: Final[int] = 100

# The size in a widget's own /DA, as in "/Helv 8 Tf 0 0 0 rg". The template
# sets 8 nearly everywhere and 7 in the three narrow e-mail cells, and that
# choice stays the template's to make.
_FONT_SIZE_IN_DA: Final[re.Pattern[str]] = re.compile(r"/\S+\s+([\d.]+)\s+Tf")

_DEFAULT_FONT_SIZE: Final[float] = 8.0

_EMBEDDED_FONT_NAME: Final[str] = "/AppFont"

# pypdf floors a widget's margin at one point and clips the appearance to what
# is left, so this is the inset every cell loses on each side.
_FIELD_MARGIN: Final[float] = 1.0

# Font metrics travel in thousandths of an em whatever the font's own grid is.
_GLYPH_SPACE: Final[int] = 1000

# What a form actually carries. Accented capitals are left out on purpose: they
# reach far higher than anything else (999 units against 790 for an accented
# lowercase in Plus Jakarta Sans) and sizing every cell around a letter that
# never arrives would shrink the whole document.
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


@lru_cache(maxsize=1)
def enrollment_field_map(path: Path) -> FormFieldMap:
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
    """Stamp values into a copy of an AcroForm template and lock every field.

    A TrueType `font` is embedded and used for every text field; without one
    the template's own Helvetica is kept.
    """
    writer = PdfWriter(clone_from=BytesIO(template))
    ink = _ink_box(font) if font else None
    font_name = _embed_font(writer, font, ink) if font and ink else None

    for number, page in enumerate(writer.pages, start=1):
        given = values_by_page.get(number, {})
        values: dict[str, Any] = {}

        for name, size in _text_fields(page, ink).items():
            # Empty text fields too: their appearance is regenerated along with
            # the rest, which is what drops the tinted box the template paints.
            value = _clipped(given.get(name, ""))
            values[name] = (value, font_name, size) if font_name else value

        for name, value in given.items():
            values.setdefault(name, _clipped(value))

        if not values:
            continue

        # No /NeedAppearances: every appearance in the output is one we drew,
        # and the fields are read-only, so there is nothing for a viewer to
        # regenerate — and no second chance for it to draw them differently.
        writer.update_page_form_field_values(page, values, auto_regenerate=False)

    _drop_field_tint(writer)
    _lock_fields(writer)

    buffer = BytesIO()
    writer.write(buffer)

    return buffer.getvalue()


def _clipped(value: str) -> str:
    # Checkbox states are /Name values and are always short; clipping them
    # would be harmless but is not the point of the limit.
    return value[:_MAX_TEXT_LENGTH]


def _text_fields(page: Any, ink: tuple[float, float] | None) -> dict[str, float]:
    sizes: dict[str, float] = {}

    for annotation in page.get("/Annots", []):
        widget = annotation.get_object()

        if widget.get("/FT") != "/Tx":
            continue

        name = widget.get("/T")

        if name is not None:
            sizes[name] = _fitted_size(widget, ink)

    return sizes


def _fitted_size(widget: DictionaryObject, ink: tuple[float, float] | None) -> float:
    asked = _font_size_of(widget)

    if ink is None:
        return asked

    top, depth = ink
    rectangle = widget["/Rect"]
    height = abs(float(rectangle[3]) - float(rectangle[1])) - 2 * _FIELD_MARGIN

    # Whatever the template asks for, a line taller than its cell would have
    # its tails clipped away.
    fits = height * _GLYPH_SPACE / (top + depth)

    return min(asked, math.floor(fits * 10) / 10)


def _font_size_of(widget: DictionaryObject) -> float:
    match = _FONT_SIZE_IN_DA.search(str(widget.get("/DA", "")))

    if match is None:
        return _DEFAULT_FONT_SIZE

    size = float(match.group(1))

    # An autosizing /DA says 0; the appearance we draw needs a real number.
    return size or _DEFAULT_FONT_SIZE


# How far the ink of an ordinary line reaches above and below the baseline,
# in thousandths of an em. Read from the font rather than from its declared
# ascent, which is a line-height figure: for Plus Jakarta Sans that is 1038 on
# a 1000 unit em, and centring a line on it is what buries the tails.
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


# pypdf builds the font resource with its streams nested inline, and a PDF
# stream has to be an indirect object: left as they come, no reader can load
# the font and every value is either dropped or drawn with the wrong glyphs.
def _embed_font(writer: PdfWriter, font: bytes, ink: tuple[float, float]) -> str:
    resource = Font.from_truetype_font_file(BytesIO(font)).as_font_resource()

    if isinstance(resource.get("/ToUnicode"), StreamObject):
        resource[NameObject("/ToUnicode")] = writer._add_object(resource["/ToUnicode"])

    descendant = resource["/DescendantFonts"][0]
    descriptor = descendant["/FontDescriptor"]

    # pypdf puts the baseline at margin + (height - ascent x size) / 2, which
    # centres the line on the ascent alone and leaves the descent hanging below
    # the clip. Feeding it (ink above - ink below) makes the same arithmetic
    # centre the ink box instead. Nothing else in this document reads the
    # figure: the fields are read-only and carry the appearance we drew.
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


# The tint is a printed part of the page, not the viewer's own field
# highlighting: it lives in /MK /BG and in the appearance stream that paints
# it. Regenerating the appearances drops the second, this drops the first.
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
