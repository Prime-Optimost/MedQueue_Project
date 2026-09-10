"""
accounts/serializers.py

All request/response serializers for the accounts module.
Each serializer has an explicit `fields` list (no `__all__`) so the API
surface is intentional and safe against field-level data leaks.
"""

from django.contrib.auth import authenticate
from django.contrib.auth.password_validation import validate_password
from django.utils import timezone
from rest_framework import serializers
from rest_framework_simplejwt.tokens import RefreshToken
from django.db import transaction
from .services import SlotService

from .models import (
    AuditLog,
    DoctorProfile,
    OTPVerification,
    PatientProfile,
    User,
    UserRole,
    Appointment,
    AppointmentStatus,
    DoctorAvailability,
    DoctorAvailabilityOverride,
    DoctorSchedule,
    SlotStatus,
    TimeSlot,
    QueueEntry,
    QueueEntryStatus,
    QueuePauseLog,
    QueueSession,
    QueueSessionStatus,
    EmergencyContact,
    EmergencyRequest,
    EmergencyStatus,
    EmergencyStatusLog,
    EmergencyType,
    Notification,
    NotificationType,
    VALID_STATUS_TRANSITIONS,
)


"""
appointments/serializers.py

Serializers for Module 2: Appointment Booking & Management.

Serializer map:
  DoctorListSerializer        — FR-2.1: browse/filter doctors
  TimeSlotSerializer          — FR-2.2: real-time slot availability
  BookAppointmentSerializer   — FR-2.3: create booking (write)
  AppointmentSerializer       — FR-2.3/2.7/2.8: read appointment detail
  AppointmentListSerializer   — FR-2.8: history list (lightweight)
  CancelAppointmentSerializer — FR-2.5: cancel with reason
  RescheduleSerializer        — FR-2.6: swap to a new slot
  DoctorStatusSerializer      — FR-2.7: mark complete / no-show
  DoctorScheduleSerializer    — FR-7.2: admin schedule CRUD
  AdminAppointmentSerializer  — FR-2.10: admin override
"""

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _get_tokens(user: User) -> dict:
    """Return a fresh JWT token pair for the given user."""
    refresh = RefreshToken.for_user(user)
    # Embed role in token payload for Flutter-side routing
    refresh["role"] = user.role
    refresh["full_name"] = user.get_full_name()
    return {
        "refresh": str(refresh),
        "access": str(refresh.access_token),
    }


# ---------------------------------------------------------------------------
# Profile sub-serializers  (nested, read-write)
# ---------------------------------------------------------------------------

class PatientProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = PatientProfile
        fields = [
            "blood_group",
            "allergies",
            "emergency_contact_name",
            "emergency_contact_phone",
            "medical_history",
        ]


class DoctorProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = DoctorProfile
        fields = [
            "specialization",
            "medical_license_number",
            "hospital_name",
            "consultation_fee",
            "years_of_experience",
            "is_accepting_patients",
            "bio",
            "avg_consultation_minutes",
        ]


# ---------------------------------------------------------------------------
# User read serializer  (safe public representation)
# ---------------------------------------------------------------------------

class UserSerializer(serializers.ModelSerializer):
    """
    Read-only representation returned after login / profile fetch.
    Role-specific profile is included only when it exists.
    """
    patient_profile = PatientProfileSerializer(read_only=True)
    doctor_profile  = DoctorProfileSerializer(read_only=True)
    full_name       = serializers.SerializerMethodField()
    profile_picture_url = serializers.SerializerMethodField()
    class Meta:
        model  = User
        fields = [
            "id",
            "username",
            "email",
            "first_name",
            "last_name",
            "full_name",
            "role",
            "phone_number",
            "date_of_birth",
            "gender",
            "address",
            "profile_picture_url",
            "is_active",
            "is_phone_verified",
            "is_email_verified",
            "whatsapp_number",
            "whatsapp_linked",
            "notif_push",
            "notif_sms",
            "notif_whatsapp",
            "patient_profile",
            "doctor_profile",
            "created_at",
        ]
        read_only_fields = fields  # this serializer is strictly read-only
    def get_profile_picture_url(self, obj: User) -> str | None:
        # Replace 'profile_picture' with the exact name of the ImageField on your User model
        if hasattr(obj, 'profile_picture') and obj.profile_picture:
            request = self.context.get('request')
            if request is not None:
                return request.build_absolute_uri(obj.profile_picture.url)
            return obj.profile_picture.url
        return None
    def get_full_name(self, obj: User) -> str:
        return obj.get_full_name() or obj.username


# ---------------------------------------------------------------------------
# Registration
# ---------------------------------------------------------------------------

class RegisterSerializer(serializers.Serializer):
    """
    Handles new user sign-up for all roles.
    Doctor-specific fields are optional at registration and can be
    completed later via the profile update endpoint.
    """

    # --- Core identity ---
    username        = serializers.CharField(max_length=150)
    email           = serializers.EmailField()
    phone_number    = serializers.CharField(max_length=20)
    whatsapp_number = serializers.CharField(max_length=20, required=False, allow_blank=True, default="")
    password        = serializers.CharField(
        write_only=True,
        style={"input_type": "password"},
    )
    password_confirm = serializers.CharField(
        write_only=True,
        style={"input_type": "password"},
    )
    first_name      = serializers.CharField(max_length=150)
    last_name       = serializers.CharField(max_length=150)
    role            = serializers.ChoiceField(choices=UserRole.choices)
    gender          = serializers.CharField(max_length=15, required=False, default="unspecified")
    date_of_birth   = serializers.DateField(required=False, allow_null=True)
    address         = serializers.CharField(required=False, default="")
    profile_picture = serializers.ImageField(required=False, allow_null=True)

    # --- Doctor-only (ignored for patients) ---
    specialization          = serializers.CharField(required=False, default="")
    medical_license_number  = serializers.CharField(required=False, default="")
    hospital_name           = serializers.CharField(required=False, default="")
    consultation_fee        = serializers.DecimalField(
        max_digits=10, decimal_places=2, required=False, default=0
    )

    # --- Patient-only (ignored for doctors) ---
    blood_group             = serializers.CharField(required=False, default="")
    emergency_contact_name  = serializers.CharField(required=False, default="")
    emergency_contact_phone = serializers.CharField(required=False, default="")

    def validate_username(self, value: str) -> str:
        if User.objects.filter(username__iexact=value).exists():
            raise serializers.ValidationError("This username is already taken.")
        return value

    def validate_email(self, value: str) -> str:
        if User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError("An account with this email already exists.")
        return value

    def validate_phone_number(self, value: str) -> str:
        if User.objects.filter(phone_number=value).exists():
            raise serializers.ValidationError("An account with this phone number already exists.")
        return value

    def validate_password(self, value: str) -> str:
        validate_password(value)  # runs Django's built-in password validators
        return value

    def validate(self, attrs: dict) -> dict:
        if attrs["password"] != attrs.pop("password_confirm"):
            raise serializers.ValidationError({"password_confirm": "Passwords do not match."})

        # Prevent patients from self-assigning admin role
        if attrs["role"] == UserRole.ADMIN:
            request = self.context.get("request")
            if not (request and request.user.is_authenticated and request.user.is_admin_user):
                raise serializers.ValidationError(
                    {"role": "Admin accounts must be created by an existing administrator."}
                )
        return attrs

    def create(self, validated_data: dict) -> User:
        # --- Extract profile-specific fields before User creation ---
        doctor_fields = {
            "specialization":           validated_data.pop("specialization", ""),
            "medical_license_number":   validated_data.pop("medical_license_number", ""),
            "hospital_name":            validated_data.pop("hospital_name", ""),
            "consultation_fee":         validated_data.pop("consultation_fee", 0),
        }
        patient_fields = {
            "blood_group":              validated_data.pop("blood_group", ""),
            "emergency_contact_name":   validated_data.pop("emergency_contact_name", ""),
            "emergency_contact_phone":  validated_data.pop("emergency_contact_phone", ""),
        }

        whatsapp_number = validated_data.pop("whatsapp_number", "")
        profile_picture = validated_data.pop("profile_picture", None)

        password = validated_data.pop("password")
        user = User(**validated_data)
        user.set_password(password)
        # New accounts are inactive until OTP verification
        user.is_active = True          # active but phone not verified
        user.is_phone_verified = False
        user.whatsapp_number = whatsapp_number or ""
        user.whatsapp_linked = bool((whatsapp_number or "").strip())
        if profile_picture is not None:
            user.profile_picture = profile_picture
        user.save()

        # Create role-specific profile
        if user.role == UserRole.DOCTOR:
            DoctorProfile.objects.create(user=user, **doctor_fields)
        elif user.role == UserRole.PATIENT:
            PatientProfile.objects.create(user=user, **patient_fields)

        return user


# ---------------------------------------------------------------------------
# Admin: create a user account directly (no OTP required)
# ---------------------------------------------------------------------------

class AdminCreateUserSerializer(serializers.Serializer):
    """
    Creates a fully-active, phone-verified account on behalf of an admin.
    The admin already verified the person's identity, so no OTP is dispatched.

    Supports role: doctor, patient, or admin (admins require an admin caller).
    Doctor-specific profile fields are accepted when role == "doctor".
    """
    username            = serializers.CharField(max_length=150)
    email               = serializers.EmailField(required=False, allow_blank=True, default="")
    phone_number        = serializers.CharField(max_length=20, required=False, allow_blank=True, default="")
    password            = serializers.CharField(write_only=True, style={"input_type": "password"})
    first_name          = serializers.CharField(max_length=150, required=False, default="")
    last_name           = serializers.CharField(max_length=150, required=False, default="")
    role                = serializers.ChoiceField(choices=UserRole.choices)
    gender              = serializers.CharField(max_length=15, required=False, default="unspecified")
    address             = serializers.CharField(required=False, default="")

    # Doctor-only
    specialization          = serializers.CharField(required=False, default="")
    medical_license_number  = serializers.CharField(required=False, default="")
    hospital_name           = serializers.CharField(required=False, default="")
    consultation_fee        = serializers.DecimalField(
        max_digits=10, decimal_places=2, required=False, default=0
    )

    def validate_username(self, value: str) -> str:
        if User.objects.filter(username__iexact=value).exists():
            raise serializers.ValidationError("This username is already taken.")
        return value

    def validate_email(self, value: str) -> str:
        if value and User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError("An account with this email already exists.")
        return value

    def validate_phone_number(self, value: str) -> str:
        if value and User.objects.filter(phone_number=value).exists():
            raise serializers.ValidationError("An account with this phone number already exists.")
        return value

    def validate_password(self, value: str) -> str:
        validate_password(value)
        return value

    def validate(self, attrs: dict) -> dict:
        if not attrs.get("phone_number") and not attrs.get("email"):
            raise serializers.ValidationError(
                {"phone_number": "Provide at least an email or phone number."}
            )
        return attrs

    def create(self, validated_data: dict) -> User:
        doctor_fields = {
            "specialization":          validated_data.pop("specialization", ""),
            "medical_license_number":  validated_data.pop("medical_license_number", ""),
            "hospital_name":           validated_data.pop("hospital_name", ""),
            "consultation_fee":        validated_data.pop("consultation_fee", 0),
        }

        password = validated_data.pop("password")
        user = User(**validated_data)
        user.set_password(password)
        user.is_active = True
        user.is_phone_verified = bool(user.phone_number)
        user.is_email_verified = bool(user.email)
        user.save()

        if user.role == UserRole.DOCTOR:
            DoctorProfile.objects.create(
                user=user,
                **doctor_fields,
                is_accepting_patients=True,
            )
        elif user.role == UserRole.PATIENT:
            PatientProfile.objects.create(user=user)

        return user


# ---------------------------------------------------------------------------
# OTP
# ---------------------------------------------------------------------------

class SendOTPSerializer(serializers.Serializer):
    """Request a new OTP for a given phone number."""
    phone_number = serializers.CharField(max_length=20)
    purpose      = serializers.ChoiceField(
        choices=OTPVerification.Purpose.choices,
        default=OTPVerification.Purpose.PHONE_REGISTRATION,
    )

    def validate_phone_number(self, value: str) -> str:
        if not User.objects.filter(phone_number=value).exists():
            raise serializers.ValidationError("No account found with this phone number.")
        return value


class VerifyOTPSerializer(serializers.Serializer):
    """Submit an OTP code to verify phone ownership."""
    phone_number = serializers.CharField(max_length=20)
    code         = serializers.CharField(min_length=4, max_length=6)
    purpose      = serializers.ChoiceField(
        choices=OTPVerification.Purpose.choices,
        default=OTPVerification.Purpose.PHONE_REGISTRATION,
    )

    @staticmethod
    def _resolve_user(identifier: str) -> User:
        user = User.objects.filter(phone_number=identifier).first()
        if user is None:
            user = User.objects.filter(email__iexact=identifier).first()
        if user is None:
            raise User.DoesNotExist
        return user

    def validate(self, attrs: dict) -> dict:
        phone_number = attrs["phone_number"]
        purpose      = attrs["purpose"]

        try:
            user = self._resolve_user(phone_number)
        except User.DoesNotExist:
            raise serializers.ValidationError({"phone_number": "No account found."})

        otp = (
            OTPVerification.objects
            .filter(
                user=user,
                purpose=purpose,
                is_used=False,
            )
            .order_by("-created_at")
            .first()
        )

        if otp is None:
            raise serializers.ValidationError({"code": "No active OTP session found. Request a new code."})
        if not otp.is_valid:
            raise serializers.ValidationError({"code": "OTP has expired. Please request a new one."})

        attrs["_user"] = user
        attrs["_otp"]  = otp
        return attrs


# ---------------------------------------------------------------------------
# Login
# ---------------------------------------------------------------------------

class LoginSerializer(serializers.Serializer):
    """
    Accepts login via username OR phone_number plus password.
    Returns JWT token pair + user representation on success.
    """
    login    = serializers.CharField(
        help_text="Username, email, or phone number"
    )
    password = serializers.CharField(
        write_only=True,
        style={"input_type": "password"},
    )

    def validate(self, attrs: dict) -> dict:
        login    = attrs["login"].strip()
        password = attrs["password"]

        # Resolve the user by username, email, or phone
        user = self._resolve_user(login)

        if user is None:
            raise serializers.ValidationError(
                {"login": "No account found with these credentials."}
            )

        # Check lockout BEFORE attempting authentication
        if user.is_locked_out:
            unlock_at = user.lockout_until.strftime("%H:%M")
            raise serializers.ValidationError(
                {
                    "non_field_errors": (
                        f"Account locked after too many failed attempts. "
                        f"Try again after {unlock_at}."
                    )
                }
            )

        # Authenticate
        authenticated_user = authenticate(
            request=self.context.get("request"),
            username=user.username,
            password=password,
        )

        if authenticated_user is None:
            user.record_failed_login()
            remaining = max(0, 3 - user.failed_login_attempts)
            msg = "Incorrect password."
            if remaining == 0:
                msg = (
                    f"Account locked for {15} minutes due to too many "
                    "failed login attempts."
                )
            elif remaining <= 2:
                msg = f"Incorrect password. {remaining} attempt(s) remaining before lockout."
            raise serializers.ValidationError({"password": msg})

        if not authenticated_user.is_active:
            raise serializers.ValidationError(
                {"non_field_errors": "This account has been deactivated."}
            )

        # Success — reset counter, generate tokens
        authenticated_user.reset_login_attempts()

        attrs["user"]   = authenticated_user
        attrs["tokens"] = _get_tokens(authenticated_user)
        return attrs

    @staticmethod
    def _resolve_user(login: str):
        """Find User by username, email, or phone number. Returns None if the
        identifier is empty, ambiguous, or matches nothing."""
        if not login:
            return None
        for field in ("username", "email", "phone_number"):
            try:
                return User.objects.get(**{field: login})
            except (User.DoesNotExist, User.MultipleObjectsReturned):
                continue
        return None


# ---------------------------------------------------------------------------
# Password Reset
# ---------------------------------------------------------------------------

class PasswordResetRequestSerializer(serializers.Serializer):
    """Request a password-reset OTP via phone or email."""
    phone_number = serializers.CharField(max_length=20, required=False)
    email        = serializers.EmailField(required=False)

    def validate(self, attrs: dict) -> dict:
        phone = attrs.get("phone_number")
        email = attrs.get("email")
        if not phone and not email:
            raise serializers.ValidationError(
                "Provide either phone_number or email."
            )
        user = None
        if phone:
            user = User.objects.filter(phone_number=phone).first()
        if not user and email:
            user = User.objects.filter(email__iexact=email).first()
        if not user:
            raise serializers.ValidationError(
                "No account found with the provided details."
            )
        attrs["_user"] = user
        return attrs


class PasswordResetConfirmSerializer(serializers.Serializer):
    """Consume OTP + set new password."""
    phone_number     = serializers.CharField(max_length=20)
    code             = serializers.CharField(min_length=4, max_length=4)
    new_password     = serializers.CharField(
        write_only=True, style={"input_type": "password"}
    )
    confirm_password = serializers.CharField(
        write_only=True, style={"input_type": "password"}
    )

    def validate_new_password(self, value: str) -> str:
        validate_password(value)
        return value

    def validate(self, attrs: dict) -> dict:
        if attrs["new_password"] != attrs["confirm_password"]:
            raise serializers.ValidationError(
                {"confirm_password": "Passwords do not match."}
            )

        identifier = attrs["phone_number"]
        user = User.objects.filter(phone_number=identifier).first()
        if user is None:
            user = User.objects.filter(email__iexact=identifier).first()
        if user is None:
            raise serializers.ValidationError({"phone_number": "No account found."})

        otp_data = VerifyOTPSerializer(
            data={
                "phone_number": user.phone_number,
                "code": attrs["code"],
                "purpose": OTPVerification.Purpose.PASSWORD_RESET,
            }
        )
        otp_data.is_valid(raise_exception=True)
        attrs["_user"] = otp_data.validated_data["_user"]
        attrs["_otp"]  = otp_data.validated_data["_otp"]
        return attrs


# ---------------------------------------------------------------------------
# Profile Update
# ---------------------------------------------------------------------------

class ProfileUpdateSerializer(serializers.ModelSerializer):
    """
    Partial update of the User record + nested role profile.
    Only fields that are sent get updated (PATCH semantics).
    """
    patient_profile = PatientProfileSerializer(required=False)
    doctor_profile  = DoctorProfileSerializer(required=False)
    profile_picture_url = serializers.URLField(required=False, allow_blank=True, allow_null=True)
    class Meta:
        model  = User
        fields = [
            "first_name",
            "last_name",
            "email",
            "phone_number",
            "date_of_birth",
            "gender",
            "address",
            "profile_picture",
            "profile_picture_url",
            "whatsapp_number",
            "notif_push",
            "notif_sms",
            "notif_whatsapp",
            "patient_profile",
            "doctor_profile",
        ]

    def _allowed_fields(self) -> set[str]:
        role = getattr(self.instance, "role", None)
        if role == UserRole.DOCTOR:
            return {
                "first_name",
                "last_name",
                "email",
                "phone_number",
                "profile_picture",
                "profile_picture_url",
                "whatsapp_number",
                "notif_push",
                "notif_sms",
                "notif_whatsapp",
                "doctor_profile",
            }
        if role == UserRole.PATIENT:
            return {
                "first_name",
                "last_name",
                "email",
                "phone_number",
                "date_of_birth",
                "gender",
                "address",
                "profile_picture_url",
                "profile_picture",
                "whatsapp_number",
                "notif_push",
                "notif_sms",
                "notif_whatsapp",
                "patient_profile",
            }
        return {
            "first_name",
            "last_name",
            "email",
            "phone_number",
            "date_of_birth",
            "gender",
            "address",
            "profile_picture_url",
            "profile_picture",
            "whatsapp_number",
            "notif_push",
            "notif_sms",
            "notif_whatsapp",
            "patient_profile",
            "doctor_profile",
        }

    def _nested_allowed_fields(self) -> dict[str, set[str]]:
        role = getattr(self.instance, "role", None)
        patient_fields = {
            "blood_group",
            "allergies",
            "emergency_contact_name",
            "emergency_contact_phone",
            "medical_history",
        }
        doctor_fields = {
            "specialization",
            "medical_license_number",
            "hospital_name",
            "consultation_fee",
            "years_of_experience",
            "is_accepting_patients",
            "bio",
            "avg_consultation_minutes",
        }
        if role == UserRole.DOCTOR:
            return {"doctor_profile": doctor_fields}
        if role == UserRole.PATIENT:
            return {"patient_profile": patient_fields}
        return {"patient_profile": patient_fields, "doctor_profile": doctor_fields}

    def validate_email(self, value: str) -> str:
        qs = User.objects.filter(email__iexact=value)
        if self.instance:
            qs = qs.exclude(pk=self.instance.pk)
        if qs.exists():
            raise serializers.ValidationError("An account with this email already exists.")
        return value

    def validate_phone_number(self, value: str) -> str:
        qs = User.objects.filter(phone_number=value)
        if self.instance:
            qs = qs.exclude(pk=self.instance.pk)
        if qs.exists():
            raise serializers.ValidationError("An account with this phone number already exists.")
        return value

    def validate(self, attrs: dict) -> dict:
        submitted_fields = set(self.initial_data.keys())
        allowed_fields = self._allowed_fields()
        disallowed = sorted(submitted_fields - allowed_fields)
        if disallowed:
            raise serializers.ValidationError(
                {field: "You are not allowed to update this field." for field in disallowed}
            )

        nested_allowed = self._nested_allowed_fields()
        for nested_field, nested_value in attrs.items():
            if nested_field not in nested_allowed or nested_value is None:
                continue
            invalid_nested = sorted(set(nested_value.keys()) - nested_allowed[nested_field])
            if invalid_nested:
                raise serializers.ValidationError(
                    {
                        nested_field: {
                            field: "You are not allowed to update this field."
                            for field in invalid_nested
                        }
                    }
                )

        # Ensure at least one notification channel remains active
        user = self.instance
        push      = attrs.get("notif_push",     user.notif_push)
        sms       = attrs.get("notif_sms",      user.notif_sms)
        whatsapp  = attrs.get("notif_whatsapp", user.notif_whatsapp)
        if not any([push, sms, whatsapp]):
            raise serializers.ValidationError(
                "At least one notification channel must remain enabled."
            )
        return attrs

    def update(self, instance: User, validated_data: dict) -> User:
        # Handle nested profiles
        patient_data = validated_data.pop("patient_profile", None)
        doctor_data  = validated_data.pop("doctor_profile", None)
        whatsapp_number = validated_data.get("whatsapp_number")

        for attr, value in validated_data.items():
            setattr(instance, attr, value)

        if whatsapp_number is not None:
            instance.whatsapp_linked = bool(str(whatsapp_number).strip())
        instance.save()

        if patient_data and instance.is_patient:
            profile, _ = PatientProfile.objects.get_or_create(user=instance)
            for attr, value in patient_data.items():
                setattr(profile, attr, value)
            profile.save()

        if doctor_data and instance.is_doctor:
            profile, _ = DoctorProfile.objects.get_or_create(user=instance)
            for attr, value in doctor_data.items():
                setattr(profile, attr, value)
            profile.save()

        return instance


# ---------------------------------------------------------------------------
# Token refresh (thin wrapper — mainly for Swagger documentation)
# ---------------------------------------------------------------------------

class TokenRefreshResponseSerializer(serializers.Serializer):
    access = serializers.CharField(read_only=True)


# ---------------------------------------------------------------------------
# Audit Log read serializer
# ---------------------------------------------------------------------------

class AuditLogSerializer(serializers.ModelSerializer):
    user_display = serializers.StringRelatedField(source="user", read_only=True)

    class Meta:
        model  = AuditLog
        fields = [
            "id",
            "user_display",
            "event_type",
            "description",
            "ip_address",
            "metadata",
            "created_at",
        ]
        read_only_fields = fields
        


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

def user_brief(user: User, request=None) -> dict:
    """Minimal user representation used in nested reads."""
    brief = {
        "id":         user.id,
        "full_name":  user.get_full_name() or user.username,
        "phone":      user.phone_number or "",
        "email":      user.email or "",
        "whatsapp_number": user.whatsapp_number or "",
        "whatsapp_linked": bool(user.whatsapp_linked and (user.whatsapp_number or "").strip()),
    }
    if hasattr(user, "profile_picture") and user.profile_picture:
        if request is not None:
            brief["profile_picture_url"] = request.build_absolute_uri(
                user.profile_picture.url
            )
        else:
            brief["profile_picture_url"] = user.profile_picture.url
    else:
        brief["profile_picture_url"] = None
    return brief


# Back-compat alias used by older code paths
_user_brief = user_brief


# ---------------------------------------------------------------------------
# Doctor listing  (FR-2.1)
# ---------------------------------------------------------------------------

class DoctorProfileBriefSerializer(serializers.Serializer):
    """Read-only doctor card shown during browse."""
    id                    = serializers.IntegerField(source="pk")
    full_name             = serializers.SerializerMethodField()
    specialization        = serializers.CharField(source="doctor_profile.specialization", default="")
    hospital_name         = serializers.CharField(source="doctor_profile.hospital_name",  default="")
    consultation_fee      = serializers.DecimalField(
        source="doctor_profile.consultation_fee",
        max_digits=10, decimal_places=2, default=0,
    )
    years_of_experience   = serializers.IntegerField(source="doctor_profile.years_of_experience", default=0)
    avg_consultation_minutes = serializers.IntegerField(
        source="doctor_profile.avg_consultation_minutes", default=15
    )
    is_accepting_patients = serializers.BooleanField(
        source="doctor_profile.is_accepting_patients", default=True
    )
    whatsapp_number       = serializers.SerializerMethodField()
    whatsapp_linked       = serializers.SerializerMethodField()
    profile_picture_url    = serializers.URLField(source="profile_picture", default="")

    def get_full_name(self, obj: User) -> str:
        return obj.get_full_name() or obj.username

    def get_whatsapp_number(self, obj: User) -> str:
        return obj.whatsapp_number or ""

    def get_whatsapp_linked(self, obj: User) -> bool:
        return bool(obj.whatsapp_linked and (obj.whatsapp_number or "").strip())


# ---------------------------------------------------------------------------
# Time Slot  (FR-2.2)
# ---------------------------------------------------------------------------

class TimeSlotSerializer(serializers.ModelSerializer):
    is_available = serializers.SerializerMethodField()

    class Meta:
        model  = TimeSlot
        fields = [
            "id",
            "date",
            "start_time",
            "end_time",
            "status",
            "is_available",
        ]
        read_only_fields = fields

    def get_is_available(self, obj: TimeSlot) -> bool:
        return obj.status == SlotStatus.AVAILABLE


# ---------------------------------------------------------------------------
# Book Appointment  (FR-2.3)  — write serializer
# ---------------------------------------------------------------------------

class BookAppointmentSerializer(serializers.Serializer):
    """
    Patient books an appointment.
    Validates slot availability; the actual booking transaction
    lives in AppointmentService.book() to keep the serializer thin.
    """
    slot_id = serializers.PrimaryKeyRelatedField(
        queryset=TimeSlot.objects.filter(status=SlotStatus.AVAILABLE),
        help_text="ID of an available TimeSlot",
    )
    reason  = serializers.CharField(
        max_length=1000,
        required=False,
        allow_blank=True,
        default="",
    )

    def validate_slot_id(self, slot: TimeSlot) -> TimeSlot:
        # Extra freshness check — the queryset filter above may be stale
        # (another request grabbed the slot between queryset eval and now)
        slot.refresh_from_db()
        if slot.status != SlotStatus.AVAILABLE:
            raise serializers.ValidationError(
                "This slot is no longer available. Please choose another."
            )
        # Prevent booking in the past
        slot_dt = timezone.make_aware(
            timezone.datetime.combine(slot.date, slot.start_time)
        )
        if slot_dt < timezone.now():
            raise serializers.ValidationError(
                "Cannot book an appointment in the past."
            )
        return slot

    def validate(self, attrs: dict) -> dict:
        request = self.context["request"]
        slot: TimeSlot = attrs["slot_id"]

        # Prevent the same patient booking the same doctor on the same day twice
        if Appointment.objects.filter(
            patient      = request.user,
            doctor       = slot.doctor,
            appointment_date = slot.date,
            status__in   = [AppointmentStatus.PENDING, AppointmentStatus.CONFIRMED],
        ).exists():
            raise serializers.ValidationError(
                "You already have an active appointment with this doctor on this date."
            )
        return attrs


# ---------------------------------------------------------------------------
# Appointment read  (FR-2.3 / 2.7 / 2.8)
# ---------------------------------------------------------------------------

class AppointmentSerializer(serializers.ModelSerializer):
    """Full detail view of an appointment."""
    patient_detail = serializers.SerializerMethodField()
    doctor_detail  = serializers.SerializerMethodField()
    slot_detail    = TimeSlotSerializer(source="slot", read_only=True)
    can_cancel     = serializers.SerializerMethodField()
    can_reschedule = serializers.SerializerMethodField()

    class Meta:
        model  = Appointment
        fields = [
            "id",
            "patient_detail",
            "doctor_detail",
            "slot_detail",
            "appointment_date",
            "appointment_time",
            "status",
            "reason",
            "notes",
            "rescheduled_from",
            "cancellation_reason",
            "reminder_24h_sent",
            "reminder_30m_sent",
            "can_cancel",
            "can_reschedule",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields

    def get_patient_detail(self, obj: Appointment) -> dict:
        request = self.context.get("request")
        return user_brief(obj.patient, request=request)

    def get_doctor_detail(self, obj: Appointment) -> dict:
        request = self.context.get("request")
        d = user_brief(obj.doctor, request=request)
        try:
            d["specialization"] = obj.doctor.doctor_profile.specialization
        except Exception:
            d["specialization"] = ""
        return d

    def get_can_cancel(self, obj: Appointment) -> bool:
        request = self.context.get("request")
        user    = request.user if request else None
        allowed, _ = obj.can_cancel(by_user=user)
        return allowed

    def get_can_reschedule(self, obj: Appointment) -> bool:
        allowed, _ = obj.can_reschedule()
        return allowed


class AppointmentListSerializer(serializers.ModelSerializer):
    """Lightweight list item used in history endpoint."""
    doctor_name    = serializers.CharField(source="doctor.get_full_name")
    patient_name   = serializers.CharField(source="patient.get_full_name")
    specialization = serializers.CharField(
        source="doctor.doctor_profile.specialization", default=""
    )
    patient_detail    = serializers.SerializerMethodField()
    doctor_detail     = serializers.SerializerMethodField()

    class Meta:
        model  = Appointment
        fields = [
            "id",
            "patient_detail",
            "doctor_detail",
            "patient_name",
            "doctor_name",
            "specialization",
            "appointment_date",
            "appointment_time",
            "status",
            "reason",
            "created_at",
        ]
        read_only_fields = fields

    def get_patient_detail(self, obj: Appointment) -> dict:
        request = self.context.get("request")
        return user_brief(obj.patient, request=request)

    def get_doctor_detail(self, obj: Appointment) -> dict:
        request = self.context.get("request")
        d = user_brief(obj.doctor, request=request)
        try:
            d["specialization"] = obj.doctor.doctor_profile.specialization
        except Exception:
            d["specialization"] = ""
        return d

# ---------------------------------------------------------------------------
# Cancel  (FR-2.5)
# ---------------------------------------------------------------------------

class CancelAppointmentSerializer(serializers.Serializer):
    cancellation_reason = serializers.CharField(
        max_length=500,
        required=False,
        allow_blank=True,
        default="",
    )


# ---------------------------------------------------------------------------
# Reschedule  (FR-2.6)
# ---------------------------------------------------------------------------

class RescheduleSerializer(serializers.Serializer):
    """
    Patient reschedules to a different slot.
    The old appointment is marked RESCHEDULED; a new appointment is created.
    """
    new_slot_id = serializers.PrimaryKeyRelatedField(
        queryset=TimeSlot.objects.filter(status=SlotStatus.AVAILABLE),
        help_text="ID of the new available TimeSlot to move to",
    )
    reason      = serializers.CharField(
        max_length=1000,
        required=False,
        allow_blank=True,
        default="",
    )

    def validate_new_slot_id(self, slot: TimeSlot) -> TimeSlot:
        slot.refresh_from_db()
        if slot.status != SlotStatus.AVAILABLE:
            raise serializers.ValidationError(
                "The selected slot is no longer available."
            )
        slot_dt = timezone.make_aware(
            timezone.datetime.combine(slot.date, slot.start_time)
        )
        if slot_dt < timezone.now():
            raise serializers.ValidationError("Cannot reschedule to a slot in the past.")
        return slot


# ---------------------------------------------------------------------------
# Doctor: mark complete / no-show  (FR-2.7 / FR-2.9)
# ---------------------------------------------------------------------------

class DoctorStatusUpdateSerializer(serializers.Serializer):
    """
    Doctor marks an appointment as COMPLETED or NO_SHOW.
    Optionally attaches notes.
    """
    STATUS_CHOICES = [
        (AppointmentStatus.COMPLETED, "Completed"),
        (AppointmentStatus.NO_SHOW,   "No Show"),
    ]
    new_status = serializers.ChoiceField(choices=STATUS_CHOICES)
    notes      = serializers.CharField(
        max_length=5000,
        required=False,
        allow_blank=True,
        default="",
        help_text="Doctor's post-consultation notes",
    )


# ---------------------------------------------------------------------------
# Doctor Schedule  (FR-7.2, admin CRUD)
# ---------------------------------------------------------------------------

class DoctorScheduleSerializer(serializers.ModelSerializer):
    doctor_name = serializers.CharField(source="doctor.get_full_name", read_only=True)

    class Meta:
        model  = DoctorSchedule
        fields = [
            "id",
            "doctor",
            "doctor_name",
            "day_of_week",
            "start_time",
            "end_time",
            "slot_duration_minutes",
            "max_patients_per_day",
            "is_active",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "doctor_name", "created_at", "updated_at"]

    def validate(self, attrs: dict) -> dict:
        doctor = attrs.get("doctor", getattr(self.instance, "doctor", None))
        day_of_week = attrs.get("day_of_week", getattr(self.instance, "day_of_week", None))
        start = attrs.get("start_time", getattr(self.instance, "start_time", None))
        end   = attrs.get("end_time",   getattr(self.instance, "end_time",   None))
        if start and end and start >= end:
            raise serializers.ValidationError(
                {"end_time": "end_time must be after start_time."}
            )

        if doctor is not None and day_of_week is not None:
            qs = DoctorSchedule.objects.filter(
                doctor=doctor,
                day_of_week=day_of_week,
                is_active=True,
            )
            if self.instance is not None:
                qs = qs.exclude(pk=self.instance.pk)
            if qs.exists():
                raise serializers.ValidationError(
                    {"day_of_week": "An active schedule already exists for this doctor and day."}
                )
        return attrs


class DoctorAvailabilityOverrideSerializer(serializers.ModelSerializer):
    doctor_name = serializers.CharField(source="doctor.get_full_name", read_only=True)

    class Meta:
        model = DoctorAvailabilityOverride
        fields = [
            "id",
            "doctor",
            "doctor_name",
            "date",
            "override_type",
            "start_time",
            "end_time",
            "slot_duration_minutes",
            "max_patients_per_day",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "doctor_name", "created_at", "updated_at"]

    def validate(self, attrs: dict) -> dict:
        start = attrs.get("start_time")
        end = attrs.get("end_time")
        if start and end and start >= end:
            raise serializers.ValidationError(
                {"end_time": "end_time must be after start_time."}
            )
        return attrs


# ---------------------------------------------------------------------------
# Admin override  (FR-2.10)
# ---------------------------------------------------------------------------

class AdminAppointmentOverrideSerializer(serializers.Serializer):
    """
    Admins can create, edit, or delete appointments on behalf of any user.
    """
    patient_id  = serializers.PrimaryKeyRelatedField(
        queryset=User.objects.filter(role="patient"),
        required=False,
    )
    doctor_id   = serializers.PrimaryKeyRelatedField(
        queryset=User.objects.filter(role="doctor"),
        required=False,
    )
    slot_id     = serializers.PrimaryKeyRelatedField(
        queryset=TimeSlot.objects.filter(status=SlotStatus.AVAILABLE),
        required=False,
    )
    new_status  = serializers.ChoiceField(
        choices=AppointmentStatus.choices,
        required=False,
    )
    reason      = serializers.CharField(required=False, allow_blank=True, default="")
    notes       = serializers.CharField(required=False, allow_blank=True, default="")
    override_note = serializers.CharField(
        required=False,
        allow_blank=True,
        default="",
        help_text="Admin's reason for the override (logged in audit trail)",
    )      
    
    
"""
queue/serializers.py

Serializers for Module 3: Virtual Queuing System.

Serializer map:
  QueueEntryPatientSerializer    — FR-3.2: patient's own position view
  QueueSessionDoctorSerializer   — FR-3.5: doctor's full queue view
  QueueEntryDoctorSerializer     — FR-3.5: one entry row in doctor view
  PauseQueueSerializer           — FR-3.5: pause input
  ResumeQueueSerializer          — FR-3.5: resume (no body needed, kept for consistency)
  LeaveQueueSerializer           — FR-3.6: patient voluntary leave
  AdminQueueOverviewSerializer   — FR-7.3: admin live monitoring
  DailyStatsSerializer           — FR-3.7: per-doctor daily stats
  AggregateStatsSerializer       — FR-3.7: date-range analytics
"""


# ---------------------------------------------------------------------------
# Patient view (FR-3.2)
# ---------------------------------------------------------------------------

class QueueEntryPatientSerializer(serializers.ModelSerializer):
    """
    What a patient sees on their home screen.
    Includes their ticket number, position, wait estimate, and session state.
    """
    positions_ahead       = serializers.IntegerField(read_only=True)
    estimated_wait_mins   = serializers.IntegerField(
        source="estimated_wait_minutes", read_only=True
    )
    doctor_name           = serializers.CharField(
        source="session.doctor.get_full_name", read_only=True
    )
    session_status        = serializers.CharField(
        source="session.status", read_only=True
    )
    pause_reason          = serializers.SerializerMethodField()
    current_position      = serializers.IntegerField(
        source="session.current_position", read_only=True
    )
    avg_consult_mins      = serializers.IntegerField(
        source="session.avg_consultation_minutes", read_only=True
    )

    class Meta:
        model  = QueueEntry
        fields = [
            "id",
            "queue_number",
            "status",
            "positions_ahead",
            "estimated_wait_mins",
            "avg_consult_mins",
            "current_position",
            "doctor_name",
            "session_status",
            "pause_reason",
            "notified_2away",
            "called_at",
            "created_at",
        ]
        read_only_fields = fields

    def get_pause_reason(self, obj: QueueEntry) -> str:
        if obj.session.is_paused:
            return obj.session.pause_reason
        return ""


# ---------------------------------------------------------------------------
# Doctor view — single entry row  (FR-3.5)
# ---------------------------------------------------------------------------

class QueueEntryDoctorSerializer(serializers.ModelSerializer):
    patient_name   = serializers.CharField(source="patient.get_full_name", read_only=True)
    patient_phone  = serializers.CharField(source="patient.phone_number",  read_only=True)
    visit_reason   = serializers.SerializerMethodField()
    positions_ahead= serializers.IntegerField(read_only=True)

    class Meta:
        model  = QueueEntry
        fields = [
            "id",
            "queue_number",
            "patient_name",
            "patient_phone",
            "visit_reason",
            "status",
            "positions_ahead",
            "called_at",
            "completed_at",
            "created_at",
        ]
        read_only_fields = fields

    def get_visit_reason(self, obj: QueueEntry) -> str:
        """Pull reason from the linked appointment if available."""
        try:
            return obj.appointment.reason or ""
        except Exception:
            return ""


# ---------------------------------------------------------------------------
# Doctor view — full session  (FR-3.5)
# ---------------------------------------------------------------------------

class QueueSessionDoctorSerializer(serializers.ModelSerializer):
    entries        = serializers.SerializerMethodField()
    waiting_count  = serializers.IntegerField(read_only=True)
    served_count   = serializers.IntegerField(read_only=True)
    avg_consult_mins = serializers.IntegerField(
        source="avg_consultation_minutes", read_only=True
    )

    class Meta:
        model  = QueueSession
        fields = [
            "id",
            "date",
            "status",
            "current_position",
            "next_number",
            "waiting_count",
            "served_count",
            "avg_consult_mins",
            "pause_reason",
            "total_pause_minutes",
            "entries",
            "updated_at",
        ]
        read_only_fields = fields

    def get_entries(self, obj: QueueSession) -> list:
        entries = obj.entries.select_related("patient", "appointment").order_by("queue_number")
        return QueueEntryDoctorSerializer(entries, many=True).data


# ---------------------------------------------------------------------------
# Pause / Resume  (FR-3.5)
# ---------------------------------------------------------------------------

class PauseQueueSerializer(serializers.Serializer):
    pause_reason = serializers.CharField(
        max_length=300,
        required=False,
        allow_blank=True,
        default="",
        help_text="Optional reason communicated to waiting patients",
    )


# ---------------------------------------------------------------------------
# Patient: leave queue  (FR-3.6)
# ---------------------------------------------------------------------------

class LeaveQueueSerializer(serializers.Serializer):
    """No fields required — the action is self-describing. Kept for consistency."""
    pass


# ---------------------------------------------------------------------------
# Admin: live overview  (FR-7.3)
# ---------------------------------------------------------------------------

class AdminQueueOverviewSerializer(serializers.Serializer):
    """Read-only serializer for the admin live monitor. Data comes from QueueAnalyticsService."""
    session_id       = serializers.IntegerField()
    doctor_id        = serializers.IntegerField()
    doctor_name      = serializers.CharField()
    specialization   = serializers.CharField()
    status           = serializers.CharField()
    current_position = serializers.IntegerField()
    waiting_count    = serializers.IntegerField()
    served_count     = serializers.IntegerField()
    is_paused        = serializers.BooleanField()
    pause_reason     = serializers.CharField()
    total_pause_mins = serializers.IntegerField()
    avg_consult_mins = serializers.IntegerField()


# ---------------------------------------------------------------------------
# FR-3.7 Analytics
# ---------------------------------------------------------------------------

class DailyStatsSerializer(serializers.Serializer):
    doctor                  = serializers.CharField()
    date                    = serializers.CharField()
    session_status          = serializers.CharField()
    total_in_queue          = serializers.IntegerField()
    total_served            = serializers.IntegerField()
    total_no_shows          = serializers.IntegerField()
    total_left              = serializers.IntegerField()
    currently_waiting       = serializers.IntegerField()
    avg_actual_consult_min  = serializers.IntegerField(allow_null=True)
    avg_configured_consult  = serializers.IntegerField()
    total_pause_minutes     = serializers.IntegerField()
    pause_count             = serializers.IntegerField()
    current_position        = serializers.IntegerField()


class AggregateStatsSerializer(serializers.Serializer):
    from_date               = serializers.CharField()
    to_date                 = serializers.CharField()
    doctor                  = serializers.CharField()
    total_queue_entries     = serializers.IntegerField()
    total_served            = serializers.IntegerField()
    total_no_shows          = serializers.IntegerField()
    total_left_queue        = serializers.IntegerField()
    no_show_rate_pct        = serializers.FloatField()
    avg_consultation_mins   = serializers.IntegerField(allow_null=True)


# ---------------------------------------------------------------------------
# Pause log  (for doctor / admin history)
# ---------------------------------------------------------------------------

class QueuePauseLogSerializer(serializers.ModelSerializer):
    duration_minutes = serializers.IntegerField(read_only=True)

    class Meta:
        model  = QueuePauseLog
        fields = ["id", "paused_at", "resumed_at", "reason", "duration_minutes"]
        read_only_fields = fields      
        
        

"""
emergency/serializers.py

Serializers for Module 5: Emergency SOS & Ambulance Request.

Map:
  TriggerSOSSerializer            — FR-5.3 / FR-5.4: patient triggers SOS
  EmergencyRequestSerializer      — FR-5.7: full detail read
  EmergencyRequestListSerializer  — FR-5.8: lightweight history list item
  UpdateEmergencyStatusSerializer — FR-5.7: admin/doctor updates status
  CancelSOSSerializer             — patient cancels pending SOS
  EmergencyStatusLogSerializer    — FR-5.7 / FR-7.6: status change audit trail
  EmergencyContactSerializer      — admin CRUD on hospital contacts
  EmergencySummaryStatsSerializer — FR-7.6: admin dashboard stats
"""

# ---------------------------------------------------------------------------
# Status log
# ---------------------------------------------------------------------------

class EmergencyStatusLogSerializer(serializers.ModelSerializer):
    changed_by_name = serializers.CharField(
        source="changed_by.get_full_name", default="System", read_only=True
    )

    class Meta:
        model  = EmergencyStatusLog
        fields = [
            "id",
            "previous_status",
            "new_status",
            "changed_by_name",
            "notes",
            "created_at",
        ]
        read_only_fields = fields


# ---------------------------------------------------------------------------
# Full detail  (FR-5.7)
# ---------------------------------------------------------------------------

class EmergencyRequestSerializer(serializers.ModelSerializer):
    patient_name     = serializers.CharField(source="patient.get_full_name", read_only=True)
    patient_phone    = serializers.CharField(source="patient.phone_number",  read_only=True)
    handled_by_name  = serializers.CharField(
        source="handled_by.get_full_name", default=None, read_only=True
    )
    maps_url         = serializers.CharField(read_only=True)
    is_active        = serializers.BooleanField(read_only=True)
    status_logs      = EmergencyStatusLogSerializer(many=True, read_only=True)
    allowed_next_statuses = serializers.SerializerMethodField()

    class Meta:
        model  = EmergencyRequest
        fields = [
            "id",
            "patient_name",
            "patient_phone",
            "latitude",
            "longitude",
            "gps_accuracy_meters",
            "maps_url",
            "emergency_type",
            "description",
            "status",
            "is_active",
            "confirmed_at",
            "dispatched_at",
            "resolved_at",
            "response_time_seconds",
            "handled_by_name",
            "ambulance_plate",
            "ambulance_eta_minutes",
            "resolution_notes",
            "admin_notified",
            "patient_ack_sent",
            "allowed_next_statuses",
            "status_logs",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields

    def get_allowed_next_statuses(self, obj: EmergencyRequest) -> list:
        return list(VALID_STATUS_TRANSITIONS.get(obj.status, set()))


# ---------------------------------------------------------------------------
# Lightweight list item  (FR-5.8)
# ---------------------------------------------------------------------------

class EmergencyRequestListSerializer(serializers.ModelSerializer):
    patient_name  = serializers.CharField(source="patient.get_full_name", read_only=True)
    maps_url      = serializers.CharField(read_only=True)

    class Meta:
        model  = EmergencyRequest
        fields = [
            "id",
            "patient_name",
            "emergency_type",
            "status",
            "maps_url",
            "confirmed_at",
            "response_time_seconds",
            "ambulance_eta_minutes",
        ]
        read_only_fields = fields


# ---------------------------------------------------------------------------
# FR-5.3 / FR-5.4  Trigger SOS  (patient write)
# ---------------------------------------------------------------------------

class TriggerSOSSerializer(serializers.Serializer):
    """
    Patient submits GPS coordinates and optional context after the
    5-second countdown (FR-5.2 is handled client-side in Flutter).
    """
    latitude       = serializers.DecimalField(
        max_digits=10,
        decimal_places=7,
        required=False,
        allow_null=True,
        help_text="Device GPS latitude. Nullable if GPS unavailable.",
    )
    longitude      = serializers.DecimalField(
        max_digits=10,
        decimal_places=7,
        required=False,
        allow_null=True,
        help_text="Device GPS longitude.",
    )
    gps_accuracy   = serializers.DecimalField(
        max_digits=8,
        decimal_places=2,
        required=False,
        allow_null=True,
        help_text="GPS accuracy in metres as reported by the device.",
    )
    emergency_type = serializers.ChoiceField(
        choices=EmergencyType.choices,
        default=EmergencyType.MEDICAL,
        required=False,
    )
    description    = serializers.CharField(
        max_length=1000,
        required=False,
        allow_blank=True,
        default="",
        help_text="Optional description of the emergency.",
    )

    def validate(self, attrs):
        request = self.context.get("request")

        # Idempotency: warn if patient already has an active SOS
        if request:
            from .services import EmergencyService
            existing = EmergencyService.get_active_request(request.user)
            if existing:
                raise serializers.ValidationError(
                    {
                        "non_field_errors": (
                            f"You already have an active emergency request (#{existing.pk}, "
                            f"status: {existing.status}). "
                            "Cancel it before submitting a new one."
                        )
                    }
                )
        return attrs


# ---------------------------------------------------------------------------
# FR-5.7  Update status  (admin / doctor)
# ---------------------------------------------------------------------------

class UpdateEmergencyStatusSerializer(serializers.Serializer):
    new_status    = serializers.ChoiceField(choices=EmergencyStatus.choices)
    notes         = serializers.CharField(
        max_length=1000,
        required=False,
        allow_blank=True,
        default="",
        help_text="Internal notes on the status change.",
    )
    ambulance_plate = serializers.CharField(
        max_length=20,
        required=False,
        allow_blank=True,
        default="",
        help_text="Required when dispatching an ambulance.",
    )
    ambulance_eta_minutes = serializers.IntegerField(
        required=False,
        allow_null=True,
        min_value=1,
        max_value=180,
        help_text="ETA in minutes from dispatch. Set when status → dispatched.",
    )
    resolution_notes = serializers.CharField(
        max_length=2000,
        required=False,
        allow_blank=True,
        default="",
        help_text="Outcome notes when resolving or marking false alarm.",
    )

    def validate(self, attrs):
        request_obj = self.context.get("emergency_request")
        if request_obj is None:
            return attrs

        new_status = attrs["new_status"]
        allowed    = VALID_STATUS_TRANSITIONS.get(request_obj.status, set())

        if new_status not in allowed:
            raise serializers.ValidationError(
                {
                    "new_status": (
                        f"Invalid transition: '{request_obj.status}' → '{new_status}'. "
                        f"Allowed next states: {list(allowed) or ['none (terminal)']}."
                    )
                }
            )
        return attrs


# ---------------------------------------------------------------------------
# Cancel SOS (patient only)
# ---------------------------------------------------------------------------

class CancelSOSSerializer(serializers.Serializer):
    """No fields required — self-describing action."""
    pass


# ---------------------------------------------------------------------------
# Emergency Contact  (admin CRUD)
# ---------------------------------------------------------------------------

class EmergencyContactSerializer(serializers.ModelSerializer):

    class Meta:
        model  = EmergencyContact
        fields = [
            "id",
            "name",
            "contact_type",
            "phone_number",
            "whatsapp_number",
            "fcm_token",
            "email",
            "is_active",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]

    def validate_phone_number(self, value: str) -> str:
        if not value.startswith("+"):
            raise serializers.ValidationError(
                "Phone number must be in E.164 format (e.g. +233301234567)."
            )
        return value


# ---------------------------------------------------------------------------
# Summary stats  (FR-7.6)
# ---------------------------------------------------------------------------

class EmergencySummaryStatsSerializer(serializers.Serializer):
    total                = serializers.IntegerField()
    pending              = serializers.IntegerField()
    dispatched           = serializers.IntegerField()
    resolved             = serializers.IntegerField()
    cancelled            = serializers.IntegerField()
    false_alarms         = serializers.IntegerField()
    avg_response_seconds = serializers.IntegerField(allow_null=True)
    type_breakdown       = serializers.DictField(child=serializers.IntegerField())


# ---------------------------------------------------------------------------
# In-App Notifications
# ---------------------------------------------------------------------------

class NotificationSerializer(serializers.ModelSerializer):
    recipient_id  = serializers.IntegerField(read_only=True)
    type          = serializers.CharField(read_only=True)

    class Meta:
        model = Notification
        fields = [
            "id",
            "recipient_id",
            "type",
            "title",
            "message",
            "is_read",
            "action_url",
            "metadata",
            "created_at",
        ]
        read_only_fields = fields        