"""
accounts/permissions.py

Custom DRF permission classes for MedQueue GH RBAC.
Use these on any view that needs role-gating.

Usage:
    class MyView(APIView):
        permission_classes = [IsAuthenticated, IsDoctorOrAdmin]
"""

from rest_framework.permissions import BasePermission, IsAuthenticated  # noqa: F401


class IsPatient(BasePermission):
    """Allows access only to users with the 'patient' role."""
    message = "Only patients can perform this action."

    def has_permission(self, request, view) -> bool:
        return bool(
            request.user
            and request.user.is_authenticated
            and request.user.is_patient
        )


class IsDoctor(BasePermission):
    """Allows access only to users with the 'doctor' role."""
    message = "Only doctors can perform this action."

    def has_permission(self, request, view) -> bool:
        return bool(
            request.user
            and request.user.is_authenticated
            and request.user.is_doctor
        )


class IsAdminUser(BasePermission):
    """Allows access only to users with the 'admin' role."""
    message = "Only administrators can perform this action."

    def has_permission(self, request, view) -> bool:
        return bool(
            request.user
            and request.user.is_authenticated
            and request.user.is_admin_user
        )


class IsDoctorOrAdmin(BasePermission):
    """Allows access to doctors and admins."""
    message = "Doctors or administrators only."

    def has_permission(self, request, view) -> bool:
        return bool(
            request.user
            and request.user.is_authenticated
            and (request.user.is_doctor or request.user.is_admin_user)
        )


class IsOwnerOrAdmin(BasePermission):
    """
    Object-level permission.
    Allows users to modify only their own objects unless they are admin.
    The view's object must have a `user` attribute.
    """
    message = "You can only modify your own data."

    def has_object_permission(self, request, view, obj) -> bool:
        if request.user.is_admin_user:
            return True
        return getattr(obj, "user", None) == request.user or obj == request.user