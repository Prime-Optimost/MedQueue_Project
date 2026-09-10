"""
accounts/exceptions.py

Custom DRF exception handler — wraps all errors in the standard envelope.
Register in settings:
    REST_FRAMEWORK = {
        "EXCEPTION_HANDLER": "apps.accounts.exceptions.custom_exception_handler",
    }
"""

from rest_framework.views import exception_handler
from rest_framework.response import Response


def custom_exception_handler(exc, context):
    """
    Converts DRF exceptions into our standard envelope:
    {status: "error", message: "...", data: null, errors: {...}}
    """
    response = exception_handler(exc, context)

    if response is not None:
        response.data = {
            "status":  "error",
            "message": _extract_message(response.data),
            "data":    None,
            "errors":  response.data,
        }
    return response


def _extract_message(data) -> str:
    """Pull a human-readable top-level message from DRF error data."""
    if isinstance(data, dict):
        # DRF puts non-field errors under 'detail' or 'non_field_errors'
        if "detail" in data:
            return str(data["detail"])
        if "non_field_errors" in data:
            errs = data["non_field_errors"]
            return errs[0] if isinstance(errs, list) else str(errs)
        # First field error
        for key, value in data.items():
            if isinstance(value, list) and value:
                return f"{key}: {value[0]}"
            return f"{key}: {value}"
    if isinstance(data, list) and data:
        return str(data[0])
    return "An error occurred."