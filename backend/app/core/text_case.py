# Anagraphic text is stored in the shape it is printed in: fixed once on the way in.


# A word starts at a letter that no other letter precedes.
def title_case(value: str) -> str:
    characters: list[str] = []
    after_letter = False

    for character in value:
        characters.append(character.lower() if after_letter else character.upper())
        after_letter = character.isalpha()

    return "".join(characters)


# Where nothing further in is worth keeping the way it was typed.
def sentence_case(value: str) -> str:
    return value[:1].upper() + value[1:].lower()


# Where a later acronym or proper name must survive: a diagnosis, a drug, a department.
def opening_capital(value: str) -> str:
    return value[:1].upper() + value[1:]
