# The rules of compareAlphabetically in the app, so both sides agree on ties.

_VARIANTS_OF: dict[str, str] = {
    "a": "àáâãäåāăą",
    "c": "çćĉċč",
    "d": "ďđð",
    "e": "èéêëēĕėęě",
    "g": "ĝğġģ",
    "h": "ĥħ",
    "i": "ìíîïĩīĭįı",
    "j": "ĵ",
    "k": "ķ",
    "l": "ĺļľŀł",
    "n": "ñńņň",
    "o": "òóôõöøōŏő",
    "r": "ŕŗř",
    "s": "śŝşšș",
    "t": "ţťŧț",
    "u": "ùúûüũūŭůűų",
    "w": "ŵ",
    "y": "ýÿŷ",
    "z": "źżž",
    "ss": "ß",
    "ae": "æ",
    "oe": "œ",
    "th": "þ",
    "": (
        " «´·»ʼ ‐‑‒–"
        "—‘’“”… "
    ),
}

_PLAIN: dict[int, str] = {
    **{code: "" for code in range(0x80) if not chr(code).isalnum()},
    **{
        ord(variant): plain
        for plain, variants in _VARIANTS_OF.items()
        for variant in variants
    },
    # Combining accents, left by decomposed text.
    **{code: "" for code in range(0x300, 0x370)},
}


# Case, accents, spaces and punctuation decide only once every part ties.
def alphabetical_key(*parts: str) -> tuple[str, ...]:
    return (
        *(part.lower().translate(_PLAIN) for part in parts),
        *(part.lower() for part in parts),
        *parts,
    )
