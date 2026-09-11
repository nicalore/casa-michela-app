# Anagraphic text is stored in the shape it is printed in, so it is fixed once
# on the way in instead of at every place that shows it.


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


# Where an acronym or a proper name further in has to survive: a diagnosis, a
# drug, the department a role answers to.
def opening_capital(value: str) -> str:
    return value[:1].upper() + value[1:]
