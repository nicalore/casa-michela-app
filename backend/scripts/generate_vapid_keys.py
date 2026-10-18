# Prints a fresh VAPID pair to paste into backend/.env.
#
#     python -m scripts.generate_vapid_keys
#
# Browsers tie their subscriptions to the public key: replacing a pair in use
# silences every browser until it subscribes again.

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec
from py_vapid.utils import b64urlencode


def main() -> None:
    key = ec.generate_private_key(ec.SECP256R1())
    private = key.private_numbers().private_value.to_bytes(32, "big")
    public = key.public_key().public_bytes(
        serialization.Encoding.X962,
        serialization.PublicFormat.UncompressedPoint,
    )

    print(f"VAPID_PUBLIC_KEY={b64urlencode(public)}")
    print(f"VAPID_PRIVATE_KEY={b64urlencode(private)}")


if __name__ == "__main__":
    main()
