import unicodedata
from urllib.parse import quote


# Both filename forms: an ASCII-folded quoted fallback plus the UTF-8 encoded one.
def inline_disposition(file_name: str) -> str:
    folded = unicodedata.normalize("NFKD", file_name).encode("ascii", "ignore").decode()
    fallback = folded.replace('"', "").replace("\\", "")

    return f'inline; filename="{fallback}"; filename*=UTF-8\'\'{quote(file_name)}'
