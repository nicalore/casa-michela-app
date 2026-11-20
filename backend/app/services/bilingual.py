from dataclasses import dataclass

from app.core.i18n import tr, tr_for


# A text in both languages, Italian first: for_request() answers whoever asked,
# to() speaks to a recipient in their account's language (None is Italian).
@dataclass(frozen=True)
class Bilingual:
    it: str
    en: str

    def to(self, language: str | None) -> str:
        return tr_for(language, self.it, self.en)

    def for_request(self) -> str:
        return tr(self.it, self.en)

    # Both filled the same way.
    def format(self, **values: object) -> "Bilingual":
        return Bilingual(self.it.format(**values), self.en.format(**values))


# One of two by count: the first for one, the second for several.
def by_count(pair: tuple[Bilingual, Bilingual], count: int) -> Bilingual:
    return pair[0] if count == 1 else pair[1]
