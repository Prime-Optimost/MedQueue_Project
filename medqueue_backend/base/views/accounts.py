"""
accounts/views.py

All authentication and account management API views.
Design principles:
  - Views are thin: validation in serializers, logic in services.
  - Every endpoint returns a consistent envelope: {status, message, data}.
  - All significant events are written to AuditLog via AuditService.
  - No raw exceptions leak to the client.
"""

from django.utils import timezone
from rest_framework import status
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenRefreshView

from ..models import (
    Appointment,
    AuditLog,
    EmergencyRequest,
    OTPVerification,
    User,
)
from ..permissions import IsAdminUser, IsOwnerOrAdmin
from ..serializers import (
    AdminCreateUserSerializer,
    LoginSerializer,
    PasswordResetConfirmSerializer,
    PasswordResetRequestSerializer,
    ProfileUpdateSerializer,
    RegisterSerializer,
    SendOTPSerializer,
    UserSerializer,
    VerifyOTPSerializer,
)
from ..services import AuditService, OTPService


# ---------------------------------------------------------------------------
# Response helper
# ---------------------------------------------------------------------------

def api_response(
    data=None,
    message: str = "",
    status_code: int = status.HTTP_200_OK,
    errors=None,
) -> Response:
    """
    Standardised JSON envelope used across all endpoints:
    {
        "status": "success" | "error",
        "message": "...",
        "data": {...} | null,
        "errors": {...} | null
    }
    """
    return Response(
        {
            "status":  "error" if errors else "success",
            "message": message,
            "data":    data,
            "errors":  errors,
        },
        status=status_code,
    )


# ---------------------------------------------------------------------------
# Registration
# ---------------------------------------------------------------------------

class RegisterView(APIView):
    """
    POST /auth/register/

    Creates a new user account and dispatches an OTP to the provided
    phone number.  Account is active but `is_phone_verified=False` until
    the OTP is confirmed.

    Roles: patient and doctor can self-register.
    Admin accounts require an existing admin to create them.
    """
    permission_classes = [AllowAny]
    parser_classes     = [MultiPartParser, FormParser, JSONParser]
    throttle_scope     = "registration"   # configure in settings

    def post(self, request):
        serializer = RegisterSerializer(
            data=request.data,
            context={"request": request},
        )
        if not serializer.is_valid():
            return api_response(
                message="Registration failed. Please fix the errors below.",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        user: User = serializer.save()

        # Fire OTP
        OTPService.send_otp(user, OTPVerification.Purpose.PHONE_REGISTRATION)

        # Audit
        AuditService.log(
            event_type  = AuditLog.EventType.REGISTER,
            user        = user,
            description = f"New {user.role} account registered.",
            request     = request,
            metadata    = {"role": user.role},
        )

        return api_response(
            data    = {"user_id": user.id, "username": user.username},
            message = (
                "Registration successful. A 6-digit OTP has been sent to your "
                "phone number and email. Please verify to activate your account."
            ),
            status_code = status.HTTP_201_CREATED,
        )


# ---------------------------------------------------------------------------
# OTP
# ---------------------------------------------------------------------------

class SendOTPView(APIView):
    """
    POST /auth/otp/send/

    (Re-)send an OTP to the user's registered phone number.
    Used after registration and for password reset.
    """
    permission_classes = [AllowAny]
    throttle_scope     = "otp"

    def post(self, request):
        serializer = SendOTPSerializer(data=request.data)
        if not serializer.is_valid():
            return api_response(
                message="Unable to send OTP.",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        phone   = serializer.validated_data["phone_number"]
        purpose = serializer.validated_data["purpose"]
        user    = User.objects.get(phone_number=phone)

        OTPService.send_otp(user, purpose)

        return api_response(
            message=f"OTP sent to {phone}. Valid for 5 minutes.",
        )


class VerifyOTPView(APIView):
    """
    POST /auth/otp/verify/

    Validates the OTP and marks the phone as verified.
    Returns a JWT token pair so the user can proceed immediately
    after registration without a separate login step.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = VerifyOTPSerializer(data=request.data)
        if not serializer.is_valid():
            return api_response(
                message="OTP verification failed.",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        user: User = serializer.validated_data["_user"]
        otp: OTPVerification = serializer.validated_data["_otp"]
        purpose = serializer.validated_data["purpose"]
        code = request.data.get("code")

        # Verify via local code check (Brevo is delivery-only)
        success, message, verified_user = OTPService.verify(
            email=user.email,
            code=code,
            purpose=purpose,
        )

        if not success:
            return api_response(
                message=message,
                errors={"code": message},
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        # Mark phone verified on registration OTP
        if purpose == OTPVerification.Purpose.PHONE_REGISTRATION:
            verified_user.is_phone_verified = True
            verified_user.save(update_fields=["is_phone_verified"])

        # Issue tokens so user is logged in immediately
        refresh = RefreshToken.for_user(verified_user)
        refresh["role"]      = verified_user.role
        refresh["full_name"] = verified_user.get_full_name()

        AuditService.log(
            event_type  = AuditLog.EventType.LOGIN,
            user        = verified_user,
            description = f"Phone verified via OTP ({purpose}).",
            request     = request,
        )

        return api_response(
            data={
                "tokens": {
                    "refresh": str(refresh),
                    "access":  str(refresh.access_token),
                },
                "user": UserSerializer(verified_user).data,
            },
            message="Phone verified successfully.",
        )


class ResendOTPView(APIView):
    """
    POST /auth/otp/resend/

    Resend an OTP using the existing request_id from Hubtel.
    Used when the user requests another OTP before the session expires.
    """
    permission_classes = [AllowAny]
    throttle_scope     = "otp"

    def post(self, request):
        phone   = request.data.get("phone_number")
        purpose = request.data.get("purpose", OTPVerification.Purpose.PHONE_REGISTRATION)

        if not phone:
            return api_response(
                message="Phone number is required.",
                errors={"phone_number": "This field is required."},
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        try:
            user = User.objects.get(phone_number=phone)
        except User.DoesNotExist:
            return api_response(
                message="No account found with this phone number.",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        result = OTPService.resend_otp(user, purpose)

        if result:
            return api_response(
                message=f"OTP resent to {phone}. Valid for 5 minutes.",
            )
        else:
            # If resend fails, try sending a new OTP
            OTPService.send_otp(user, purpose)
            return api_response(
                message=f"A new OTP has been sent to {phone}. Valid for 5 minutes.",
            )


# ---------------------------------------------------------------------------
# Login / Logout
# ---------------------------------------------------------------------------

class LoginView(APIView):
    """
    POST /auth/login/

    Accepts username / email / phone_number + password.
    Returns JWT access + refresh tokens on success.
    Enforces account lockout policy. ignore the evn
    """
    permission_classes = [AllowAny]
    throttle_scope     = "login"

    def post(self, request):
        serializer = LoginSerializer( 
            data=request.data,
            context={"request": request},
        )
        if not serializer.is_valid():
            # Determine if this was a lockout error or credential error
            errors = serializer.errors
            flat   = str(errors)
            event  = (
                AuditLog.EventType.LOCKOUT
                if "locked" in flat
                else AuditLog.EventType.FAILED_LOGIN
            )

            # Try to resolve the user for audit log (best-effort)
            login_value = request.data.get("login", "")
            audit_user  = LoginSerializer._resolve_user(login_value)

            AuditService.log(
                event_type  = event,
                user        = audit_user,
                description = f"Failed login attempt for identifier '{login_value}'.",
                request     = request,
            )

            return api_response(
                message     = "Login failed.",
                errors      = errors,
                status_code = status.HTTP_401_UNAUTHORIZED,
            )

        user: User   = serializer.validated_data["user"]
        tokens: dict = serializer.validated_data["tokens"]

        AuditService.log(
            event_type  = AuditLog.EventType.LOGIN,
            user        = user,
            description = "Successful login.",
            request     = request,
            metadata    = {"role": user.role},
        )

        return api_response(
            data={
                "tokens": tokens,
                "user":   UserSerializer(user).data,
            },
            message="Login successful.",
        )


class LogoutView(APIView):
    """
    POST /auth/logout/

    Blacklists the refresh token so it cannot be reused.
    Requires the client to send the refresh token in the request body.
    Requires: djangorestframework-simplejwt with token blacklisting enabled.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        refresh_token = request.data.get("refresh")
        if not refresh_token:
            return api_response(
                message     = "Refresh token is required.",
                errors      = {"refresh": "This field is required."},
                status_code = status.HTTP_400_BAD_REQUEST,
            )

        try:
            token = RefreshToken(refresh_token)
            token.blacklist()
        except TokenError as exc:
            return api_response(
                message     = "Token is invalid or already expired.",
                errors      = {"refresh": str(exc)},
                status_code = status.HTTP_400_BAD_REQUEST,
            )

        AuditService.log(
            event_type  = AuditLog.EventType.LOGOUT,
            user        = request.user,
            description = "User logged out and refresh token blacklisted.",
            request     = request,
        )

        return api_response(message="Logged out successfully.")


# ---------------------------------------------------------------------------
# Password Reset
# ---------------------------------------------------------------------------

class PasswordResetRequestView(APIView):
    """
    POST /auth/password/reset/request/

    Sends a password-reset OTP to the user's phone or email.
    """
    permission_classes = [AllowAny]
    throttle_scope     = "otp"

    def post(self, request):
        serializer = PasswordResetRequestSerializer(data=request.data)
        if not serializer.is_valid():
            return api_response(
                message     = "Could not initiate password reset.",
                errors      = serializer.errors,
                status_code = status.HTTP_400_BAD_REQUEST,
            )

        user: User = serializer.validated_data["_user"]
        OTPService.send_otp(user, OTPVerification.Purpose.PASSWORD_RESET)

        AuditService.log(
            event_type  = AuditLog.EventType.PASSWORD_RESET,
            user        = user,
            description = "Password reset OTP requested.",
            request     = request,
        )

        # Always return a vague success message to prevent user enumeration
        return api_response(
            message=(
                "If an account exists with the provided details, "
                "a reset code has been sent."
            )
        )


class PasswordResetConfirmView(APIView):
    """
    POST /auth/password/reset/confirm/

    Validates the OTP and sets the new password.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = PasswordResetConfirmSerializer(data=request.data)
        if not serializer.is_valid():
            return api_response(
                message     = "Password reset failed.",
                errors      = serializer.errors,
                status_code = status.HTTP_400_BAD_REQUEST,
            )

        user: User              = serializer.validated_data["_user"]
        otp: OTPVerification    = serializer.validated_data["_otp"]
        new_password: str       = serializer.validated_data["new_password"]
        code: str               = request.data.get("code")

        # Verify the submitted code against the stored plaintext OTP.
        success, message, verified_user = OTPService.verify(
            email=user.email,
            code=code,
            purpose=OTPVerification.Purpose.PASSWORD_RESET,
        )

        if not success:
            return api_response(
                message=message,
                errors={"code": message},
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        verified_user.set_password(new_password)
        verified_user.reset_login_attempts()
        verified_user.save()

        AuditService.log(
            event_type  = AuditLog.EventType.PASSWORD_RESET,
            user        = verified_user,
            description = "Password reset completed successfully.",
            request     = request,
        )

        return api_response(message="Password reset successful. You may now log in.")


# ---------------------------------------------------------------------------
# Profile
# ---------------------------------------------------------------------------

class ProfileView(APIView):
    """
    GET  /auth/profile/       — retrieve own profile
    PATCH /auth/profile/      — partial update own profile
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        serializer = UserSerializer(request.user)
        return api_response(
            data    = serializer.data,
            message = "Profile retrieved successfully.",
        )

    def patch(self, request):
        serializer = ProfileUpdateSerializer(
            instance = request.user,
            data     = request.data,
            partial  = True,
            context  = {"request": request},
        )
        if not serializer.is_valid():
            return api_response(
                message     = "Profile update failed.",
                errors      = serializer.errors,
                status_code = status.HTTP_400_BAD_REQUEST,
            )

        user = serializer.save()

        AuditService.log(
            event_type  = AuditLog.EventType.PROFILE_UPDATE,
            user        = user,
            description = "User updated their profile.",
            request     = request,
            metadata    = {"updated_fields": list(request.data.keys())},
        )

        return api_response(
            data    = UserSerializer(user).data,
            message = "Profile updated successfully.",
        )


class AdminUserDetailView(APIView):
    """
    GET   /auth/users/<pk>/     — admin: view any user profile
    PATCH /auth/users/<pk>/     — admin: update any user profile
    DELETE /auth/users/<pk>/    — admin: permanently delete a user account
    """
    permission_classes = [IsAuthenticated, IsAdminUser]

    def _get_user(self, pk: int) -> User | None:
        try:
            return User.objects.select_related(
                "patient_profile", "doctor_profile"
            ).get(pk=pk)
        except User.DoesNotExist:
            return None

    def get(self, request, pk: int):
        user = self._get_user(pk)
        if not user:
            return api_response(
                message     = "User not found.",
                status_code = status.HTTP_404_NOT_FOUND,
            )
        return api_response(
            data    = UserSerializer(user).data,
            message = "User retrieved successfully.",
        )

    def patch(self, request, pk: int):
        user = self._get_user(pk)
        if not user:
            return api_response(
                message     = "User not found.",
                status_code = status.HTTP_404_NOT_FOUND,
            )

        # Admin can toggle account active/inactive directly.
        # This is handled here (not in the shared serializer) so that the
        # public self-profile endpoint cannot modify a user's own active state.
        import copy
        data = copy.copy(request.data)
        if "is_active" in data:
            if user == request.user and str(data.get("is_active")).lower() != "true":
                return api_response(
                    message     = "Administrators cannot deactivate their own account.",
                    status_code = status.HTTP_400_BAD_REQUEST,
                )
            data.pop("is_active")

        serializer = ProfileUpdateSerializer(
            instance = user,
            data     = data,
            partial  = True,
        )
        if not serializer.is_valid():
            return api_response(
                message     = "Update failed.",
                errors      = serializer.errors,
                status_code = status.HTTP_400_BAD_REQUEST,
            )
        updated_user = serializer.save()

        # Apply active-state toggle (default: keep current value)
        if "is_active" in request.data:
            new_active = str(request.data.get("is_active")).lower() in ("true", "1")
            updated_user.is_active = new_active
            updated_user.save(update_fields=["is_active"])

        action = "reactivated" if updated_user.is_active else "deactivated"
        AuditService.log(
            event_type  = AuditLog.EventType.PROFILE_UPDATE,
            user        = request.user,
            description = f"Admin updated profile of user #{pk} ({action}).",
            request     = request,
            metadata    = {"target_user_id": pk, "is_active": updated_user.is_active},
        )

        return api_response(
            data    = UserSerializer(updated_user).data,
            message = "User updated successfully.",
        )

    def delete(self, request, pk: int):
        """Permanently delete a user account (hard delete)."""
        from django.db.models import Q

        if pk == request.user.pk:
            return api_response(
                message     = "Administrators cannot delete their own account through this endpoint.",
                status_code = status.HTTP_400_BAD_REQUEST,
            )

        # Protect the last remaining admin so the system is never locked out.
        if request.user.role == "admin":
            remaining_admins = User.objects.filter(
                role="admin", is_active=True
            ).count()
            target_is_admin = User.objects.filter(
                pk=pk, role="admin"
            ).exists()
            if target_is_admin and remaining_admins <= 1:
                return api_response(
                    message     = "Cannot delete the last admin account.",
                    status_code = status.HTTP_400_BAD_REQUEST,
                )

        user = self._get_user(pk)
        if not user:
            return api_response(
                message     = "User not found.",
                status_code = status.HTTP_404_NOT_FOUND,
            )

        username = user.username

        AuditService.log(
            event_type  = AuditLog.EventType.USER_DELETED,
            user        = request.user,
            description = f"Admin permanently deleted user account '{username}' (#{pk}).",
            request     = request,
            metadata    = {"target_user_id": pk, "action": "delete"},
        )

        try:
            user.delete()
        except Exception as exc:  # e.g. protected related records
            return api_response(
                message     = (
                    "This user has related records (appointments, queue entries, "
                    "etc.) and cannot be deleted directly. Deactivate the account "
                    "instead."
                ),
                errors      = {"detail": str(exc)},
                status_code = status.HTTP_400_BAD_REQUEST,
            )

        return api_response(message=f"User account '{username}' has been permanently deleted.")



class AdminUserListView(APIView):
    """
    GET /auth/users/?role=patient&search=john&is_active=true

    Paginated list of all users. Admin only.
    """
    permission_classes = [IsAuthenticated, IsAdminUser]

    def get(self, request):
        qs = User.objects.select_related(
            "patient_profile", "doctor_profile"
        ).order_by("-created_at")

        # Filter by role
        role = request.query_params.get("role")
        if role:
            qs = qs.filter(role=role)

        # Filter by active status
        is_active = request.query_params.get("is_active")
        if is_active is not None:
            qs = qs.filter(is_active=is_active.lower() == "true")

        # Search by name / username / phone
        search = request.query_params.get("search", "").strip()
        if search:
            from django.db.models import Q
            qs = qs.filter(
                Q(username__icontains=search)
                | Q(first_name__icontains=search)
                | Q(last_name__icontains=search)
                | Q(phone_number__icontains=search)
                | Q(email__icontains=search)
            )

        # Simple manual pagination (replace with DRF PageNumberPagination in settings)
        page_size = min(int(request.query_params.get("page_size", 20)), 100)
        page      = max(int(request.query_params.get("page", 1)), 1)
        offset    = (page - 1) * page_size
        total     = qs.count()
        users     = qs[offset : offset + page_size]

        return api_response(
            data={
                "count":    total,
                "page":     page,
                "pages":    -(-total // page_size),   # ceiling division
                "results":  UserSerializer(users, many=True).data,
            },
            message="Users retrieved successfully.",
        )


# ---------------------------------------------------------------------------
# Admin: create a user account directly (doctor / patient / admin)
# ---------------------------------------------------------------------------

class AdminCreateUserView(APIView):
    """
    POST /auth/admin/users/

    Creates a fully-active, verified account on the platform on behalf of
    an admin. Primarily used to add doctors. No OTP is required because the
    admin sets the account up directly.
    """
    permission_classes = [IsAuthenticated, IsAdminUser]

    def post(self, request):
        serializer = AdminCreateUserSerializer(
            data=request.data,
            context={"request": request},
        )
        if not serializer.is_valid():
            return api_response(
                message="Could not create user. Please fix the errors below.",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        user = serializer.save()

        AuditService.log(
            event_type  = AuditLog.EventType.REGISTER,
            user        = user,
            description = f"Admin created {user.role} account for {user.get_full_name()}.",
            request     = request,
            metadata    = {"created_by_admin": True, "role": user.role},
        )

        return api_response(
            data=UserSerializer(user).data,
            message=(
                f"{user.get_full_name() or user.username} ({user.role}) account created successfully. "
                f"They can now log in with the credentials you supplied."
            ),
            status_code=status.HTTP_201_CREATED,
        )


# ---------------------------------------------------------------------------
# Admin: dashboard system overview stats
# ---------------------------------------------------------------------------

class AdminDashboardStatsView(APIView):
    """
    GET /auth/admin/dashboard/stats/

    Aggregated counts for the admin dashboard "System Overview":
      - total users, by role (patients / doctors / admins)
      - active users
      - total appointments, by status
      - total emergency requests, by status
    """

    permission_classes = [IsAuthenticated, IsAdminUser]

    def get(self, request):
        users = User.objects.all()
        appointments = Appointment.objects.all()
        emergencies = EmergencyRequest.objects.all()

        def count_by_role(qs, role):
            return qs.filter(role=role).count()

        data = {
            "total_users":        users.count(),
            "active_users":       users.filter(is_active=True).count(),
            "patients":           count_by_role(users, "patient"),
            "doctors":            count_by_role(users, "doctor"),
            "admins":             count_by_role(users, "admin"),
            "total_appointments": appointments.count(),
            "appointment_status": {
                "pending":    appointments.filter(status="pending").count(),
                "confirmed":  appointments.filter(status="confirmed").count(),
                "completed":  appointments.filter(status="completed").count(),
                "cancelled":  appointments.filter(status="cancelled").count(),
                "no_show":    appointments.filter(status="no_show").count(),
                "rescheduled": appointments.filter(status="rescheduled").count(),
            },
            "total_emergencies":  emergencies.count(),
            "emergency_status": {
                "pending":     emergencies.filter(status="pending").count(),
                "dispatched":  emergencies.filter(status="dispatched").count(),
                "resolved":    emergencies.filter(status="resolved").count(),
                "cancelled":   emergencies.filter(status="cancelled").count(),
                "false_alarm": emergencies.filter(status="false_alarm").count(),
            },
        }

        return api_response(
            data=data,
            message="Dashboard system overview stats retrieved.",
        )


# ---------------------------------------------------------------------------
# Token Refresh  (overrides simplejwt default to match envelope)
# ---------------------------------------------------------------------------

class TokenRefreshEnvelopeView(TokenRefreshView):
    """
    POST /auth/token/refresh/

    Wraps simplejwt's default response in our standard envelope.
    """

    def post(self, request, *args, **kwargs):
        from rest_framework_simplejwt.exceptions import InvalidToken
        try:
            response = super().post(request, *args, **kwargs)
        except InvalidToken as exc:
            return api_response(
                message     = "Token refresh failed.",
                errors      = {"detail": str(exc.args[0]) if exc.args else str(exc)},
                status_code = status.HTTP_401_UNAUTHORIZED,
            )
        if response.status_code == status.HTTP_200_OK:
            return api_response(
                data    = response.data,
                message = "Token refreshed successfully.",
            )
        return api_response(
            message     = "Token refresh failed.",
            errors      = response.data,
            status_code = response.status_code,
        )
        

        