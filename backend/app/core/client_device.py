from dataclasses import dataclass
from typing import Final

from app.models.refresh_token import DeviceTypeEnum

# Sent by the app with the request that opens a session. Preferred to the user
# agent: iPadOS Safari presents itself as a Mac, and the native apps' agent
# says nothing about the screen.
FORM_FACTOR_HEADER: Final[str] = "X-Client-Form-Factor"

_FORM_FACTORS: Final[dict[str, DeviceTypeEnum]] = {
    "desktop": DeviceTypeEnum.DESKTOP,
    "phone": DeviceTypeEnum.PHONE,
    "tablet": DeviceTypeEnum.TABLET,
}

# A browser sends its own agent, which a page cannot override; the native apps
# announce themselves as "CasaMichela/app (ios)".
_APP_AGENT_PREFIX: Final[str] = "CasaMichela/"

_APP_SYSTEMS: Final[dict[str, str]] = {
    "ios": "iOS",
    "android": "Android",
    "macos": "macOS",
    "windows": "Windows",
    "linux": "Linux",
}

_HANDHELD_SYSTEMS: Final[frozenset[str]] = frozenset({"ios", "android"})

_APP_NAME: Final[str] = "App {system}"
_BROWSER_NAME: Final[str] = "{browser} su {system}"

# First match wins: Chromium forks keep "Chrome/", and everybody keeps "Safari/".
_BROWSERS: Final[tuple[tuple[str, str], ...]] = (
    ("Edg", "Edge"),
    ("OPR/", "Opera"),
    ("SamsungBrowser/", "Samsung Internet"),
    ("Firefox/", "Firefox"),
    ("FxiOS/", "Firefox"),
    ("CriOS/", "Chrome"),
    ("Chrome/", "Chrome"),
    ("Chromium/", "Chrome"),
    ("Safari/", "Safari"),
)

# Android and ChromeOS agents mention Linux too.
_SYSTEMS: Final[tuple[tuple[str, str], ...]] = (
    ("Windows", "Windows"),
    ("Android", "Android"),
    ("iPhone", "iOS"),
    ("iPod", "iOS"),
    ("iPad", "iPadOS"),
    ("CrOS", "ChromeOS"),
    ("Macintosh", "macOS"),
    ("Linux", "Linux"),
)

_MAC: Final[str] = "macOS"
_IPAD: Final[str] = "iPadOS"


@dataclass(frozen=True, slots=True)
class ClientDevice:
    device_type: DeviceTypeEnum
    name: str | None


UNKNOWN_DEVICE: Final[ClientDevice] = ClientDevice(DeviceTypeEnum.UNKNOWN, None)


def _first_match(agent: str, table: tuple[tuple[str, str], ...]) -> str | None:
    for needle, label in table:
        if needle in agent:
            return label

    return None


def _form_factor_of_agent(agent: str) -> DeviceTypeEnum:
    if "iPad" in agent or "Tablet" in agent:
        return DeviceTypeEnum.TABLET

    # Android tablets are the ones that do not say "Mobile".
    if "Android" in agent:
        return DeviceTypeEnum.PHONE if "Mobile" in agent else DeviceTypeEnum.TABLET

    if "Mobi" in agent or "iPhone" in agent or "iPod" in agent:
        return DeviceTypeEnum.PHONE

    return DeviceTypeEnum.DESKTOP


def _app_device(agent: str, declared: DeviceTypeEnum | None) -> ClientDevice:
    start = agent.find("(")
    end = agent.find(")", start)
    key = agent[start + 1:end].strip().lower() if 0 <= start < end else ""
    system = _APP_SYSTEMS.get(key)

    if system is None:
        return ClientDevice(declared or DeviceTypeEnum.UNKNOWN, None)

    if declared is not None:
        device_type = declared
    elif key in _HANDHELD_SYSTEMS:
        device_type = DeviceTypeEnum.PHONE
    else:
        device_type = DeviceTypeEnum.DESKTOP

    return ClientDevice(device_type, _APP_NAME.format(system=system))


def describe_client(user_agent: str | None, form_factor: str | None) -> ClientDevice:
    agent = (user_agent or "").strip()
    declared = _FORM_FACTORS.get((form_factor or "").strip().lower())

    if agent.startswith(_APP_AGENT_PREFIX):
        return _app_device(agent, declared)

    browser = _first_match(agent, _BROWSERS)
    system = _first_match(agent, _SYSTEMS)

    if browser is None and system is None:
        return ClientDevice(declared or DeviceTypeEnum.UNKNOWN, None)

    device_type = declared or _form_factor_of_agent(agent)

    if system == _MAC and device_type == DeviceTypeEnum.TABLET:
        system = _IPAD

    if browser is not None and system is not None:
        name = _BROWSER_NAME.format(browser=browser, system=system)
    else:
        name = browser or system

    return ClientDevice(device_type, name)
