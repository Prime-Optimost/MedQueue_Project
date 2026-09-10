"""
Temporary test-only settings: swaps the password hasher to a fast one so the
suite can actually run on dev machines where OpenSSL PBKDF2 is pathological
(~6s/hash on Python 3.14 Windows). DELETE AFTER VERIFICATION.
"""

from medqueue_backend.settings import *  # noqa: F401,F403

PASSWORD_HASHERS = [
    "django.contrib.auth.hashers.MD5PasswordHasher",
    "django.contrib.auth.hashers.PBKDF2PasswordHasher",
]