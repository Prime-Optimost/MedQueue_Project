"""
accounts/models.py

Custom User model for MedQueue GH.
Extends AbstractUser to preserve Django's built-in auth machinery
(permissions, admin integration, password hashing) while adding:
  - Role-based access (Patient / Doctor / Admin)
  - Phone number + OTP verification
  - Account lockout after 3 failed login attempts
  - Extended profiles per role (PatientProfile, DoctorProfile)
"""

from datetime import timedelta

from django.contrib.auth.models import AbstractUser
from django.core.exceptions import ValidationError
from django.db import models
from django.db.models import Q
from django.utils import timezone
from django.utils.translation import gettext_lazy as _


"""
appointments/models.py

Models for Module 2: Appointment Booking & Management.

Entity hierarchy:
  DoctorSchedule  →  defines which days/hours a doctor works
  TimeSlot        →  individual 15/20/30-min bookable slots per doctor per day
  Appointment     →  a patient's confirmed booking on a TimeSlot
  AppointmentNote →  doctor's post-consultation notes (separate for audit trail)

Design decisions:
  - TimeSlot is the atomic unit; Appointment points at one TimeSlot.
    This guarantees no double-booking at the DB level via a UniqueConstraint.
  - `SELECT FOR UPDATE` is used in the booking service to prevent race conditions
    under concurrent requests (two patients grabbing the same slot simultaneously).
  - All status transitions are guarded in the model's `transition_status()` method
    so invalid moves (e.g., cancelled → completed) are impossible.
  - Soft-cancel: slots are freed on cancellation by clearing the FK on TimeSlot,
    NOT by deleting the Appointment record (audit trail preserved).
"""

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

class UserRole(models.TextChoices):
    PATIENT = "patient", _("Patient")
    DOCTOR  = "doctor",  _("Doctor")
    ADMIN   = "admin",   _("Admin")


class Gender(models.TextChoices):
    MALE        = "male",        _("Male")
    FEMALE      = "female",      _("Female")
    OTHER       = "other",       _("Other")
    UNSPECIFIED = "unspecified", _("Prefer not to say")


MAX_FAILED_ATTEMPTS = 3
LOCKOUT_DURATION_MINUTES = 15
OTP_EXPIRY_MINUTES = 5          # SRS specifies 30 s for registration OTP;
                                 # we use 5 min for usability on slow networks


# ---------------------------------------------------------------------------
# User
# ---------------------------------------------------------------------------

class User(AbstractUser):
    """
    Central auth model.  Username is kept for Django admin compatibility
    but phone_number is the primary login credential alongside email.
    """

    # --- Identity ---
    role          = models.CharField(
        max_length=10,
        choices=UserRole.choices,
        default=UserRole.PATIENT,
        db_index=True,
    )
    phone_number  = models.CharField(
        max_length=20,
        unique=True,
        null=True,
        blank=True,
        help_text=_("E.164 format recommended, e.g. +233201234567"),
    )
    date_of_birth = models.DateField(null=True, blank=True)
    gender        = models.CharField(
        max_length=15,
        choices=Gender.choices,
        default=Gender.UNSPECIFIED,
    )
    address       = models.TextField(blank=True, default="")
    profile_picture = models.ImageField(
        upload_to="profile_pictures/",
        blank=True,
        null=True,
        help_text=_("User profile picture"),
    )

    # --- Verification ---
    is_phone_verified = models.BooleanField(default=False)
    is_email_verified = models.BooleanField(default=False)

    # WhatsApp opt-in
    whatsapp_number = models.CharField(max_length=20, blank=True, default="")
    whatsapp_linked  = models.BooleanField(default=False)

    # --- Account Lockout ---
    failed_login_attempts = models.PositiveSmallIntegerField(default=0)
    lockout_until         = models.DateTimeField(null=True, blank=True)

    # Notification preferences (bitmask stored as individual booleans for
    # clarity and queryability)
    notif_push      = models.BooleanField(default=True)
    notif_sms       = models.BooleanField(default=True)
    notif_whatsapp  = models.BooleanField(default=False)

    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    USERNAME_FIELD  = "username"
    REQUIRED_FIELDS = ["email"]

    class Meta:
        verbose_name        = _("User")
        verbose_name_plural = _("Users")
        ordering            = ["-created_at"]

    # ------------------------------------------------------------------
    # Lockout helpers
    # ------------------------------------------------------------------

    @property
    def is_locked_out(self) -> bool:
        """Returns True if the account is currently locked."""
        if self.lockout_until and timezone.now() < self.lockout_until:
            return True
        return False

    def record_failed_login(self) -> None:
        """Increment failure counter; lock account after MAX_FAILED_ATTEMPTS."""
        self.failed_login_attempts += 1
        if self.failed_login_attempts >= MAX_FAILED_ATTEMPTS:
            self.lockout_until = timezone.now() + timedelta(
                minutes=LOCKOUT_DURATION_MINUTES
            )
        self.save(update_fields=["failed_login_attempts", "lockout_until"])

    def reset_login_attempts(self) -> None:
        """Clear failure counter on successful authentication."""
        if self.failed_login_attempts != 0 or self.lockout_until is not None:
            self.failed_login_attempts = 0
            self.lockout_until = None
            self.save(update_fields=["failed_login_attempts", "lockout_until"])

    # ------------------------------------------------------------------
    # Role helpers
    # ------------------------------------------------------------------

    @property
    def is_patient(self) -> bool:
        return self.role == UserRole.PATIENT

    @property
    def is_doctor(self) -> bool:
        return self.role == UserRole.DOCTOR

    @property
    def is_admin_user(self) -> bool:
        return self.role == UserRole.ADMIN

    def __str__(self) -> str:
        return f"{self.get_full_name() or self.username} [{self.role}]"


# ---------------------------------------------------------------------------
# OTP
# ---------------------------------------------------------------------------

import random


class OTPVerification(models.Model):
    """
    Short-lived OTP record.  One active OTP per user per purpose.
    The `purpose` field allows reuse for registration, password reset, etc.
    Code is generated and verified locally; Brevo is only used as the
    email delivery transport.
    """

    class Purpose(models.TextChoices):
        PHONE_REGISTRATION = "phone_reg",    _("Phone Registration")
        PASSWORD_RESET     = "password_reset", _("Password Reset")
        LOGIN_2FA          = "login_2fa",    _("Login 2FA")

    user       = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="otp_records",
    )
    purpose    = models.CharField(
        max_length=20,
        choices=Purpose.choices,
        default=Purpose.PHONE_REGISTRATION,
    )
    code       = models.CharField(
        max_length=6,
        help_text=_("Plaintext 6-digit OTP code"),
    )
    is_used    = models.BooleanField(default=False)
    expires_at = models.DateTimeField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name        = _("OTP Verification")
        verbose_name_plural = _("OTP Verifications")
        ordering            = ["-created_at"]
        indexes             = [
            models.Index(fields=["user", "purpose", "is_used"]),
        ]

    @classmethod
    def generate_for(
        cls,
        user: User,
        purpose: str = Purpose.PHONE_REGISTRATION,
    ) -> "OTPVerification":
        """
        Invalidate any existing active OTPs for this user+purpose,
        generate a fresh 6-digit code, and create a new record.
        """
        cls.objects.filter(
            user=user,
            purpose=purpose,
            is_used=False,
        ).update(is_used=True)           # soft-invalidate old codes

        code = f"{random.randint(0, 999999):06d}"

        return cls.objects.create(
            user=user,
            purpose=purpose,
            code=code,
            expires_at=timezone.now() + timedelta(minutes=OTP_EXPIRY_MINUTES),
        )

    @property
    def is_valid(self) -> bool:
        return not self.is_used and timezone.now() <= self.expires_at

    def consume(self) -> bool:
        """Mark as used. Returns False if already used or expired."""
        if not self.is_valid:
            return False
        self.is_used = True
        self.save(update_fields=["is_used"])
        return True

    def __str__(self) -> str:
        return f"OTP({self.purpose}) for {self.user.username} — {'valid' if self.is_valid else 'expired/used'}"
# ---------------------------------------------------------------------------
# Role-specific profiles  (1-to-1 with User)
# ---------------------------------------------------------------------------

class PatientProfile(models.Model):
    """Extended data for patients only."""

    user              = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name="patient_profile",
        limit_choices_to={"role": UserRole.PATIENT},
    )
    blood_group       = models.CharField(max_length=5, blank=True, default="")
    allergies         = models.TextField(
        blank=True,
        default="",
        help_text=_("Comma-separated list of known allergies"),
    )
    emergency_contact_name  = models.CharField(max_length=100, blank=True, default="")
    emergency_contact_phone = models.CharField(max_length=20,  blank=True, default="")
    medical_history         = models.TextField(blank=True, default="")

    class Meta:
        verbose_name = _("Patient Profile")

    def __str__(self) -> str:
        return f"PatientProfile — {self.user}"


class DoctorProfile(models.Model):
    """Extended data for doctors only."""

    user                  = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name="doctor_profile",
        limit_choices_to={"role": UserRole.DOCTOR},
    )
    specialization        = models.CharField(max_length=100, blank=True, default="")
    medical_license_number= models.CharField(max_length=50,  blank=True, default="")
    hospital_name         = models.CharField(max_length=150, blank=True, default="")
    consultation_fee      = models.DecimalField(
        max_digits=10, decimal_places=2, default=0.00,
        help_text=_("Fee in GHS"),
    )
    years_of_experience   = models.PositiveSmallIntegerField(default=0)
    is_accepting_patients = models.BooleanField(default=True)
    bio                   = models.TextField(blank=True, default="")

    # Average consultation duration used by the queue wait-time algorithm
    avg_consultation_minutes = models.PositiveSmallIntegerField(
        default=15,
        help_text=_("Used to compute estimated wait times"),
    )

    class Meta:
        verbose_name = _("Doctor Profile")

    def __str__(self) -> str:
        return f"DoctorProfile — {self.user} ({self.specialization})"


# ---------------------------------------------------------------------------
# Audit Log  (used by multiple modules; defined here as a core model)
# ---------------------------------------------------------------------------

class AuditLog(models.Model):
    """Immutable event log for security and compliance (FR-7.7)."""

    class EventType(models.TextChoices):
        LOGIN           = "login",           _("Login")
        LOGOUT          = "logout",          _("Logout")
        FAILED_LOGIN    = "failed_login",    _("Failed Login")
        LOCKOUT         = "lockout",         _("Account Lockout")
        REGISTER        = "register",        _("Registration")
        PASSWORD_RESET  = "password_reset",  _("Password Reset")
        ROLE_CHANGE     = "role_change",     _("Role Change")
        PROFILE_UPDATE  = "profile_update",  _("Profile Update")
        USER_DELETED    = "user_deleted",    _("User Deleted")
        BOOKING         = "booking",         _("Appointment Booked")
        CANCELLATION    = "cancellation",    _("Appointment Cancelled")
        EMERGENCY       = "emergency",       _("Emergency SOS")

    user       = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="audit_logs",
    )
    event_type = models.CharField(max_length=30, choices=EventType.choices, db_index=True)
    description= models.TextField(blank=True, default="")
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.CharField(max_length=256, blank=True, default="")
    metadata   = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        verbose_name        = _("Audit Log")
        verbose_name_plural = _("Audit Logs")
        ordering            = ["-created_at"]
        # Audit logs are never updated, only inserted
        default_permissions = ("view",)

    def __str__(self) -> str:
        return f"[{self.event_type}] {self.user} at {self.created_at:%Y-%m-%d %H:%M:%S}"
    
    
# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

class AppointmentStatus(models.TextChoices):
    PENDING    = "pending",    _("Pending")
    CONFIRMED  = "confirmed",  _("Confirmed")
    COMPLETED  = "completed",  _("Completed")
    CANCELLED  = "cancelled",  _("Cancelled")
    NO_SHOW    = "no_show",    _("No Show")
    RESCHEDULED= "rescheduled",_("Rescheduled")


class SlotStatus(models.TextChoices):
    AVAILABLE = "available", _("Available")
    BOOKED    = "booked",    _("Booked")
    BLOCKED   = "blocked",   _("Blocked")   # admin/doctor manually blocked


class DoctorAvailability(models.TextChoices):
    AVAILABLE = "available", _("Available")
    BUSY      = "busy",      _("Busy")
    ON_LEAVE  = "on_leave",  _("On Leave")


# Valid status transitions: key → set of states it may move to
VALID_TRANSITIONS = {
    AppointmentStatus.PENDING:     {AppointmentStatus.CONFIRMED, AppointmentStatus.CANCELLED},
    AppointmentStatus.CONFIRMED:   {AppointmentStatus.COMPLETED, AppointmentStatus.CANCELLED,
                                    AppointmentStatus.NO_SHOW,  AppointmentStatus.RESCHEDULED},
    AppointmentStatus.COMPLETED:   set(),          # terminal
    AppointmentStatus.CANCELLED:   set(),          # terminal
    AppointmentStatus.NO_SHOW:     set(),          # terminal
    AppointmentStatus.RESCHEDULED: set(),          # terminal (new appt created)
}


# ---------------------------------------------------------------------------
# Doctor Schedule  (which days of week and what hours a doctor is available)
# ---------------------------------------------------------------------------

class DoctorSchedule(models.Model):
    """
    Defines a doctor's recurring weekly availability.
    Admin creates / edits these. TimeSlots are generated from them daily
    by a Celery beat task (or on-demand when a patient browses slots).

    day_of_week: 0 = Monday … 6 = Sunday  (Python's weekday() convention)
    """

    DAYS_OF_WEEK = [
        (0, _("Monday")),
        (1, _("Tuesday")),
        (2, _("Wednesday")),
        (3, _("Thursday")),
        (4, _("Friday")),
        (5, _("Saturday")),
        (6, _("Sunday")),
    ]

    doctor       = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="schedules",
        limit_choices_to={"role": "doctor"},
    )
    day_of_week  = models.PositiveSmallIntegerField(choices=DAYS_OF_WEEK)
    start_time   = models.TimeField(help_text=_("Clinic start time, e.g. 08:00"))
    end_time     = models.TimeField(help_text=_("Clinic end time, e.g. 17:00"))
    slot_duration_minutes = models.PositiveSmallIntegerField(
        default=15,
        help_text=_("Duration of each bookable slot in minutes"),
    )
    max_patients_per_day  = models.PositiveSmallIntegerField(
        default=20,
        help_text=_("Hard cap on daily appointments (FR-7.2)"),
    )
    is_active    = models.BooleanField(default=True)
    created_at   = models.DateTimeField(auto_now_add=True)
    updated_at   = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name        = _("Doctor Schedule")
        verbose_name_plural = _("Doctor Schedules")
        ordering            = ["doctor", "day_of_week", "start_time"]
        constraints         = [
            models.UniqueConstraint(
                fields=["doctor", "day_of_week"],
                condition=Q(is_active=True),
                name="unique_active_doctor_day_schedule",
            ),
        ]

    def clean(self):
        if self.start_time >= self.end_time:
            raise ValidationError(_("start_time must be before end_time."))

    def __str__(self):
        return (
            f"Dr. {self.doctor.get_full_name()} — "
            f"{self.get_day_of_week_display()} "
            f"{self.start_time:%H:%M}–{self.end_time:%H:%M}"
        )


class DoctorAvailabilityOverride(models.Model):
    """
    Date-specific override for a doctor's availability.
    When an override exists for a date, only overrides determine availability.
    This allows doctors to add or remove specific dates from their schedule.
    """
    OVERRIDE_CHOICES = [
        ("available", "Available"),
        ("unavailable", "Unavailable"),
    ]

    doctor = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="availability_overrides",
        limit_choices_to={"role": "doctor"},
    )
    date = models.DateField(db_index=True)
    override_type = models.CharField(
        max_length=15,
        choices=OVERRIDE_CHOICES,
        default="available",
    )
    start_time = models.TimeField(
        null=True,
        blank=True,
        help_text=_("Optional custom start time for this date (uses schedule default if blank)"),
    )
    end_time = models.TimeField(
        null=True,
        blank=True,
        help_text=_("Optional custom end time for this date (uses schedule default if blank)"),
    )
    slot_duration_minutes = models.PositiveSmallIntegerField(
        default=15,
        help_text=_("Slot duration for this date override"),
    )
    max_patients_per_day = models.PositiveSmallIntegerField(
        default=20,
        help_text=_("Max patients for this date override"),
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = _("Doctor Availability Override")
        verbose_name_plural = _("Doctor Availability Overrides")
        ordering = ["doctor", "date"]
        constraints = [
            models.UniqueConstraint(
                fields=["doctor", "date"],
                name="unique_doctor_date_override",
            ),
        ]

    def __str__(self):
        return (
            f"Override — Dr. {self.doctor.get_full_name()} — "
            f"{self.date} [{self.override_type}]"
        )


# ---------------------------------------------------------------------------
# Time Slot  (concrete bookable slot for a specific date)
# ---------------------------------------------------------------------------

class TimeSlot(models.Model):
    """
    One bookable 15/20/30-min window for a specific doctor on a specific date.

    Generated either:
      (a) By a nightly Celery task that pre-creates next-N-days' slots, or
      (b) On-demand in SlotService.get_or_create_slots() when a patient browses.

    The `status` field is the source of truth for availability.
    A slot becomes BOOKED when an Appointment is created pointing to it.
    It returns to AVAILABLE when that appointment is cancelled.
    """

    doctor       = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="time_slots",
        limit_choices_to={"role": "doctor"},
    )
    date         = models.DateField(db_index=True)
    start_time   = models.TimeField()
    end_time     = models.TimeField()
    status       = models.CharField(
        max_length=10,
        choices=SlotStatus.choices,
        default=SlotStatus.AVAILABLE,
        db_index=True,
    )
    created_at   = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name        = _("Time Slot")
        verbose_name_plural = _("Time Slots")
        # DB-level guarantee: no two slots for same doctor at same date+time
        unique_together     = ("doctor", "date", "start_time")
        ordering            = ["date", "start_time"]
        indexes             = [
            models.Index(fields=["doctor", "date", "status"]),
        ]

    def __str__(self):
        return (
            f"Slot [{self.status}] — Dr. {self.doctor.get_full_name()} — "
            f"{self.date} {self.start_time:%H:%M}"
        )


# ---------------------------------------------------------------------------
# Appointment
# ---------------------------------------------------------------------------

class Appointment(models.Model):
    """
    Core booking record.

    Key constraints:
      - One slot can have at most one non-cancelled appointment
        (enforced by unique_together on TimeSlot + conditional at service layer).
      - Rescheduling creates a NEW appointment; the old one is marked RESCHEDULED.
        This preserves the full audit history.
      - Cancellation deadline: 1 hour before appointment (FR-2.5).
      - Doctor notes are stored here (post-consultation).

    SRS DB schema (section 7.4) maps to this model 1-to-1.
    """

    # Core relations
    patient      = models.ForeignKey(
        User,
        on_delete=models.PROTECT,
        related_name="patient_appointments",
        limit_choices_to={"role": "patient"},
    )
    doctor       = models.ForeignKey(
        User,
        on_delete=models.PROTECT,
        related_name="doctor_appointments",
        limit_choices_to={"role": "doctor"},
    )
    slot         = models.OneToOneField(
        TimeSlot,
        on_delete=models.PROTECT,
        related_name="appointment",
        null=True,
        blank=True,
        help_text=_(
            "Set to NULL on cancellation so the slot can be re-used. "
            "The appointment record itself is kept for audit."
        ),
    )

    # Booking details
    appointment_date = models.DateField(db_index=True)
    appointment_time = models.TimeField()
    status           = models.CharField(
        max_length=15,
        choices=AppointmentStatus.choices,
        default=AppointmentStatus.PENDING,
        db_index=True,
    )
    reason           = models.TextField(
        blank=True,
        default="",
        help_text=_("Patient's stated reason for visit"),
    )

    # Doctor's post-consultation notes (FR-2.7)
    notes            = models.TextField(
        blank=True,
        default="",
        help_text=_("Doctor's post-consultation notes (visible to doctor and admin only)"),
    )

    # Rescheduling chain
    rescheduled_from = models.ForeignKey(
        "self",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="rescheduled_to",
        help_text=_("Points to the original appointment this one replaced"),
    )

    # Cancellation metadata
    cancelled_by     = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="cancelled_appointments",
        help_text=_("Who cancelled this appointment (patient, doctor, or admin)"),
    )
    cancellation_reason = models.TextField(blank=True, default="")
    booked_by_reception = models.BooleanField(
        default=False,
        help_text=_("True if this appointment was booked by receptionist/admin via phone call"),
    )

    # Reminder flags (set by Celery notification tasks)
    reminder_24h_sent = models.BooleanField(default=False)
    reminder_30m_sent = models.BooleanField(default=False)

    # Timestamps
    created_at  = models.DateTimeField(auto_now_add=True)
    updated_at  = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name        = _("Appointment")
        verbose_name_plural = _("Appointments")
        ordering            = ["-appointment_date", "-appointment_time"]
        indexes             = [
            models.Index(fields=["patient", "status"]),
            models.Index(fields=["doctor",  "appointment_date", "status"]),
        ]

    # ------------------------------------------------------------------
    # Business rules
    # ------------------------------------------------------------------

    def can_cancel(self, by_user: User | None = None) -> tuple[bool, str]:
        """
        FR-2.5: Patients can cancel up to 1 hour before the appointment.
        Doctors and admins can cancel at any time.
        Returns (allowed: bool, reason: str).
        """
        if self.status in (
            AppointmentStatus.CANCELLED,
            AppointmentStatus.COMPLETED,
            AppointmentStatus.NO_SHOW,
            AppointmentStatus.RESCHEDULED,
        ):
            return False, f"Cannot cancel an appointment with status '{self.status}'."

        # Admin and doctor bypass the time restriction
        if by_user and (by_user.is_admin_user or by_user.is_doctor):
            return True, "OK"

        # Patient: must be more than 1 hour away
        appt_dt = timezone.make_aware(
            timezone.datetime.combine(self.appointment_date, self.appointment_time)
        )
        one_hour_before = appt_dt - timezone.timedelta(hours=1)
        if timezone.now() > one_hour_before:
            return False, (
                "Appointments can only be cancelled at least 1 hour in advance. "
                "Please contact the hospital directly for last-minute changes."
            )
        return True, "OK"

    def can_reschedule(self) -> tuple[bool, str]:
        """FR-2.6: Only PENDING or CONFIRMED appointments can be rescheduled."""
        if self.status not in (AppointmentStatus.PENDING, AppointmentStatus.CONFIRMED):
            return False, f"Cannot reschedule an appointment with status '{self.status}'."
        return True, "OK"

    def transition_status(self, new_status: str) -> None:
        """
        Guard against invalid status transitions.
        Raises ValueError for illegal moves.
        """
        allowed = VALID_TRANSITIONS.get(self.status, set())
        if new_status not in allowed:
            raise ValueError(
                f"Invalid transition: '{self.status}' → '{new_status}'. "
                f"Allowed next states: {[s for s in allowed] or 'none (terminal)'}."
            )
        self.status = new_status

    def __str__(self):
        return (
            f"Appt #{self.pk} — {self.patient.get_full_name()} → "
            f"Dr. {self.doctor.get_full_name()} — "
            f"{self.appointment_date} {self.appointment_time:%H:%M} [{self.status}]"
        )    
        
        
"""
queue/models.py

Models for Module 3: Virtual Queuing System.

Entity hierarchy:
  QueueSession   — one queue per doctor per date (the "room")
  QueueEntry     — one row per patient in that queue (their "ticket")
  QueuePauseLog  — audit record every time a doctor pauses/resumes

Design decisions:
  - QueueSession is the container. It holds the current_position pointer and
    the pause state. Advancing the queue = incrementing current_position on the
    session, NOT mutating every patient's row.

  - QueueEntry.queue_number is the patient's immutable ticket number (1, 2, 3…).
    QueueEntry.status tracks whether they are waiting / called / completed /
    skipped / left.  These are independent axes.

  - Firebase is the real-time transport. PostgreSQL is the source of truth.
    On every state change we write to Postgres first, then push a snapshot to
    Firebase (in services.py). If Firebase is unavailable, the DB record is
    still correct — Firebase re-syncs on next write.

  - Wait-time algorithm (FR-3.8):
      estimated_wait = (queue_number - current_position) × avg_consultation_minutes
    avg_consultation_minutes comes from DoctorProfile and is updated nightly
    by a Celery task that averages the last 30 completed consultations.

  - Position "ahead" = patients with an EARLIER queue_number who are still
    WAITING or CALLED, not completed/left/skipped.
"""


# ---------------------------------------------------------------------------
# Choices
# ---------------------------------------------------------------------------

class QueueSessionStatus(models.TextChoices):
    ACTIVE   = "active",   _("Active")
    PAUSED   = "paused",   _("Paused")
    CLOSED   = "closed",   _("Closed")


class QueueEntryStatus(models.TextChoices):
    WAITING   = "waiting",   _("Waiting")
    CALLED    = "called",    _("Called — please proceed to room")
    IN_CONSULT= "in_consult",_("In Consultation")
    COMPLETED = "completed", _("Completed")
    SKIPPED   = "skipped",   _("Skipped / No-Show")
    LEFT      = "left",      _("Left Queue Voluntarily")


# ---------------------------------------------------------------------------
# Queue Session  (one per doctor per day)
# ---------------------------------------------------------------------------

class QueueSession(models.Model):
    """
    Represents the day's queue for a single doctor.
    Created automatically when the first appointment is confirmed (via signal),
    or on-demand by QueueService.get_or_create_session().

    current_position: the queue_number of the patient currently being seen
    (or the last one called). Patients with queue_number > current_position
    are still waiting.
    """

    doctor           = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="queue_sessions",
        limit_choices_to={"role": "doctor"},
    )
    date             = models.DateField(db_index=True)
    status           = models.CharField(
        max_length=10,
        choices=QueueSessionStatus.choices,
        default=QueueSessionStatus.ACTIVE,
        db_index=True,
    )
    current_position = models.PositiveSmallIntegerField(
        default=0,
        help_text=_("Queue number currently being served (0 = none called yet)"),
    )
    # Running counter — next entry gets this value, then it increments
    next_number      = models.PositiveSmallIntegerField(
        default=1,
        help_text=_("Next queue number to assign"),
    )
    # Pause metadata
    pause_reason     = models.CharField(max_length=300, blank=True, default="")
    paused_at        = models.DateTimeField(null=True, blank=True)
    total_pause_minutes = models.PositiveSmallIntegerField(
        default=0,
        help_text=_("Cumulative minutes the queue was paused today (FR-3.7)"),
    )

    created_at       = models.DateTimeField(auto_now_add=True)
    updated_at       = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name        = _("Queue Session")
        verbose_name_plural = _("Queue Sessions")
        unique_together     = ("doctor", "date")
        ordering            = ["-date", "doctor"]
        indexes             = [
            models.Index(fields=["date", "status"]),
        ]

    # ------------------------------------------------------------------
    # Computed properties
    # ------------------------------------------------------------------

    @property
    def is_paused(self) -> bool:
        return self.status == QueueSessionStatus.PAUSED

    @property
    def waiting_count(self) -> int:
        return self.entries.filter(
            status__in=[QueueEntryStatus.WAITING, QueueEntryStatus.CALLED]
        ).count()

    @property
    def served_count(self) -> int:
        return self.entries.filter(status=QueueEntryStatus.COMPLETED).count()

    @property
    def avg_consultation_minutes(self) -> int:
        """Pull from DoctorProfile; fallback to 15."""
        try:
            return self.doctor.doctor_profile.avg_consultation_minutes or 15
        except Exception:
            return 15

    def __str__(self):
        return (
            f"Queue [{self.status}] — Dr. {self.doctor.get_full_name()} "
            f"— {self.date} (pos {self.current_position}/{self.next_number - 1})"
        )


# ---------------------------------------------------------------------------
# Queue Entry  (one per patient in a session)
# ---------------------------------------------------------------------------

class QueueEntry(models.Model):
    """
    A patient's place in a QueueSession.
    Created automatically when an appointment is confirmed via
    QueueService.assign_queue_number().

    The combination (session, queue_number) is the patient's "ticket".
    queue_number is immutable after assignment.
    """

    session       = models.ForeignKey(
        QueueSession,
        on_delete=models.CASCADE,
        related_name="entries",
    )
    patient       = models.ForeignKey(
        User,
        on_delete=models.PROTECT,
        related_name="queue_entries",
        limit_choices_to={"role": "patient"},
    )
    # Link back to the appointment so Module 2 ↔ Module 3 stay in sync
    appointment   = models.OneToOneField(
        "Appointment",
        on_delete=models.CASCADE,
        related_name="queue_entry",
        null=True,
        blank=True,
    )
    queue_number  = models.PositiveSmallIntegerField(
        help_text=_("Patient's immutable ticket number for this session"),
    )
    status        = models.CharField(
        max_length=12,
        choices=QueueEntryStatus.choices,
        default=QueueEntryStatus.WAITING,
        db_index=True,
    )

    # Timing fields (for wait-time analytics and FR-3.8)
    called_at     = models.DateTimeField(null=True, blank=True)
    completed_at  = models.DateTimeField(null=True, blank=True)

    # 2-positions-away notification flag (FR-3.3)
    notified_2away  = models.BooleanField(
        default=False,
        help_text=_("True once the '2 positions away' push notification has been sent"),
    )

    created_at    = models.DateTimeField(auto_now_add=True)
    updated_at    = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name        = _("Queue Entry")
        verbose_name_plural = _("Queue Entries")
        unique_together     = ("session", "queue_number")
        ordering            = ["queue_number"]
        indexes             = [
            models.Index(fields=["session", "status"]),
            models.Index(fields=["patient", "status"]),
        ]

    # ------------------------------------------------------------------
    # Computed
    # ------------------------------------------------------------------

    @property
    def positions_ahead(self) -> int:
        """
        Number of patients ahead in the queue who are still WAITING or CALLED.
        FR-3.2: "number of patients ahead".
        """
        return self.session.entries.filter(
            queue_number__lt=self.queue_number,
            status__in=[QueueEntryStatus.WAITING, QueueEntryStatus.CALLED],
        ).count()

    @property
    def estimated_wait_minutes(self) -> int:
        """
        FR-3.8: estimated_wait = positions_ahead × avg_consultation_minutes
        Returns 0 if the patient is currently being called.
        """
        if self.status == QueueEntryStatus.CALLED:
            return 0
        avg = self.session.avg_consultation_minutes
        return self.positions_ahead * avg

    @property
    def actual_consultation_minutes(self) -> int | None:
        """Actual duration if completed. Used for updating avg_consultation_minutes."""
        if self.called_at and self.completed_at:
            delta = self.completed_at - self.called_at
            return max(1, int(delta.total_seconds() / 60))
        return None

    def __str__(self):
        return (
            f"#{self.queue_number} — {self.patient.get_full_name()} "
            f"[{self.status}] in {self.session}"
        )


# ---------------------------------------------------------------------------
# Queue Pause Log  (FR-3.5, FR-3.7)
# ---------------------------------------------------------------------------

class QueuePauseLog(models.Model):
    """
    Immutable record of every pause/resume event on a session.
    Used by FR-3.7 analytics to compute total_pause_duration.
    """

    session    = models.ForeignKey(
        QueueSession,
        on_delete=models.CASCADE,
        related_name="pause_logs",
    )
    doctor     = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        related_name="pause_logs",
    )
    paused_at  = models.DateTimeField()
    resumed_at = models.DateTimeField(null=True, blank=True)
    reason     = models.CharField(max_length=300, blank=True, default="")

    class Meta:
        verbose_name        = _("Queue Pause Log")
        verbose_name_plural = _("Queue Pause Logs")
        ordering            = ["-paused_at"]

    @property
    def duration_minutes(self) -> int | None:
        if self.resumed_at:
            delta = self.resumed_at - self.paused_at
            return max(0, int(delta.total_seconds() / 60))
        return None   # still paused

    def __str__(self):
        return (
            f"Pause — {self.session} — "
            f"{self.paused_at:%H:%M} → "
            f"{self.resumed_at:%H:%M if self.resumed_at else 'ongoing'}"
        )     
        
        

"""
emergency/models.py

Models for Module 5: Emergency SOS & Ambulance Request.

Entity hierarchy:
  EmergencyContact   — hospital/admin contacts who receive SOS alerts (setup by admin)
  EmergencyRequest   — the core SOS record created when a patient triggers the button
  EmergencyStatusLog — immutable audit trail of every status change on a request

Design decisions:
  - EmergencyRequest is append-only in spirit; status changes are tracked in
    EmergencyStatusLog so the full timeline is preserved.
  - GPS coordinates are stored as separate lat/lng DecimalFields (not PostGIS)
    for compatibility with SQLite in dev and easy Firebase sync.
    A `maps_url` property builds the Google Maps deep-link on the fly (FR-5.5).
  - Status flow: pending → dispatched → resolved | cancelled (patient or admin)
  - `confirmed_at` captures when the patient survived the 5-second countdown
    (FR-5.2). This is distinct from `created_at` which is the DB insert time.
  - `response_time_seconds` is computed on status change to `dispatched` and
    stored for FR-7.6 / admin analytics.
  - EmergencyContact uses a `contact_type` enum so admins can designate
    specific roles (hospital duty, ambulance dispatch, head doctor on call).
"""

# ---------------------------------------------------------------------------
# Choices
# ---------------------------------------------------------------------------

class EmergencyStatus(models.TextChoices):
    PENDING    = "pending",    _("Pending — Awaiting Response")
    DISPATCHED = "dispatched", _("Dispatched — Help On the Way")
    RESOLVED   = "resolved",   _("Resolved")
    CANCELLED  = "cancelled",  _("Cancelled by Patient")
    FALSE_ALARM= "false_alarm",_("False Alarm")


class EmergencyType(models.TextChoices):
    MEDICAL    = "medical",    _("Medical Emergency")
    AMBULANCE  = "ambulance",  _("Ambulance Request")
    CARDIAC    = "cardiac",    _("Cardiac / Chest Pain")
    ACCIDENT   = "accident",   _("Accident / Trauma")
    MATERNITY  = "maternity",  _("Maternity Emergency")
    OTHER      = "other",      _("Other")


class ContactType(models.TextChoices):
    ADMIN         = "admin",          _("Hospital Admin")
    AMBULANCE     = "ambulance",      _("Ambulance Dispatch")
    DUTY_DOCTOR   = "duty_doctor",    _("Duty Doctor")
    EMERGENCY_LINE = "emergency_line",_("Emergency Hotline")


# Status flow map: key → allowed next states
VALID_STATUS_TRANSITIONS = {
    EmergencyStatus.PENDING:    {EmergencyStatus.DISPATCHED, EmergencyStatus.CANCELLED,
                                 EmergencyStatus.FALSE_ALARM},
    EmergencyStatus.DISPATCHED: {EmergencyStatus.RESOLVED,   EmergencyStatus.FALSE_ALARM},
    EmergencyStatus.RESOLVED:   set(),   # terminal
    EmergencyStatus.CANCELLED:  set(),   # terminal
    EmergencyStatus.FALSE_ALARM:set(),   # terminal
}


# ---------------------------------------------------------------------------
# Emergency Contact  (admin-managed, notified on every SOS)
# ---------------------------------------------------------------------------

class EmergencyContact(models.Model):
    """
    Hospital staff / numbers that receive immediate alerts (FR-5.5).
    Admin creates and manages these via the admin dashboard.
    Multiple contacts can exist; all active ones receive the alert.
    """

    name         = models.CharField(max_length=150)
    contact_type = models.CharField(
        max_length=20,
        choices=ContactType.choices,
        default=ContactType.ADMIN,
        db_index=True,
    )
    phone_number = models.CharField(
        max_length=20,
        help_text=_("E.164 format e.g. +233301234567"),
    )
    whatsapp_number = models.CharField(
        max_length=20,
        blank=True,
        default="",
        help_text=_("WhatsApp number if different from phone"),
    )
    fcm_token    = models.TextField(
        blank=True,
        default="",
        help_text=_("Firebase Cloud Messaging device token for push alerts"),
    )
    email        = models.EmailField(blank=True, default="")
    is_active    = models.BooleanField(default=True)
    created_at   = models.DateTimeField(auto_now_add=True)
    updated_at   = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name        = _("Emergency Contact")
        verbose_name_plural = _("Emergency Contacts")
        ordering            = ["contact_type", "name"]

    def __str__(self):
        return f"{self.name} [{self.get_contact_type_display()}] — {self.phone_number}"


# ---------------------------------------------------------------------------
# Emergency Request  (core SOS record)
# ---------------------------------------------------------------------------

class EmergencyRequest(models.Model):
    """
    Created the moment a patient confirms the SOS (post 5-second countdown).
    FR-5.4: stores patient_id, timestamp, GPS, description, initial status.
    """

    patient      = models.ForeignKey(
        User,
        on_delete=models.PROTECT,
        related_name="emergency_requests",
        limit_choices_to={"role": "patient"},
    )
    # FR-5.3: GPS coordinates captured from device
    latitude     = models.DecimalField(
        max_digits=10,
        decimal_places=7,
        null=True,
        blank=True,
        help_text=_("Latitude from device GPS"),
    )
    longitude    = models.DecimalField(
        max_digits=10,
        decimal_places=7,
        null=True,
        blank=True,
        help_text=_("Longitude from device GPS"),
    )
    gps_accuracy_meters = models.DecimalField(
        max_digits=8,
        decimal_places=2,
        null=True,
        blank=True,
        help_text=_("GPS accuracy in metres reported by device"),
    )

    # Type and free-text description
    emergency_type = models.CharField(
        max_length=20,
        choices=EmergencyType.choices,
        default=EmergencyType.MEDICAL,
        db_index=True,
    )
    description  = models.TextField(
        blank=True,
        default="",
        help_text=_("Optional patient description of the emergency"),
    )

    # Status
    status       = models.CharField(
        max_length=15,
        choices=EmergencyStatus.choices,
        default=EmergencyStatus.PENDING,
        db_index=True,
    )

    # Timing
    confirmed_at = models.DateTimeField(
        help_text=_("When patient confirmed SOS (after 5-second countdown, FR-5.2)"),
    )
    dispatched_at = models.DateTimeField(null=True, blank=True)
    resolved_at   = models.DateTimeField(null=True, blank=True)

    # Response time analytics (seconds from confirmed_at → dispatched_at)
    response_time_seconds = models.PositiveIntegerField(
        null=True,
        blank=True,
        help_text=_("Seconds between SOS confirmation and dispatch"),
    )

    # Who handled it
    handled_by   = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="handled_emergencies",
        limit_choices_to={"role__in": ["admin", "doctor"]},
        help_text=_("Admin or doctor who updated the status to dispatched/resolved"),
    )
    resolution_notes = models.TextField(blank=True, default="")

    # Ambulance details (if applicable)
    ambulance_plate  = models.CharField(max_length=20, blank=True, default="")
    ambulance_eta_minutes = models.PositiveSmallIntegerField(
        null=True,
        blank=True,
        help_text=_("Estimated ambulance arrival in minutes, set on dispatch"),
    )

    # Notification flags
    admin_notified   = models.BooleanField(default=False)
    patient_ack_sent = models.BooleanField(default=False)

    created_at  = models.DateTimeField(auto_now_add=True)
    updated_at  = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name        = _("Emergency Request")
        verbose_name_plural = _("Emergency Requests")
        ordering            = ["-confirmed_at"]
        indexes             = [
            models.Index(fields=["patient", "status"]),
            models.Index(fields=["status", "confirmed_at"]),
        ]

    # ------------------------------------------------------------------
    # Computed properties
    # ------------------------------------------------------------------

    @property
    def maps_url(self) -> str:
        """
        FR-5.5: Google Maps deep-link sent to admin in the alert.
        Format: https://maps.google.com/?q=lat,lng
        """
        if self.latitude is not None and self.longitude is not None:
            return f"https://maps.google.com/?q={self.latitude},{self.longitude}"
        return ""

    @property
    def is_active(self) -> bool:
        return self.status in (EmergencyStatus.PENDING, EmergencyStatus.DISPATCHED)

    # ------------------------------------------------------------------
    # Status transition guard
    # ------------------------------------------------------------------

    def transition_status(self, new_status: str, by_user: User) -> None:
        """
        Guard against invalid transitions. Raises ValueError on illegal moves.
        Also sets timing fields and computes response_time_seconds.
        """
        allowed = VALID_STATUS_TRANSITIONS.get(self.status, set())
        if new_status not in allowed:
            raise ValueError(
                f"Invalid transition: '{self.status}' → '{new_status}'. "
                f"Allowed: {list(allowed) or 'none (terminal state)'}."
            )

        now = timezone.now()
        self.status     = new_status
        self.handled_by = by_user

        if new_status == EmergencyStatus.DISPATCHED:
            self.dispatched_at = now
            if self.confirmed_at:
                delta = now - self.confirmed_at
                self.response_time_seconds = int(delta.total_seconds())

        elif new_status in (EmergencyStatus.RESOLVED, EmergencyStatus.FALSE_ALARM):
            self.resolved_at = now

    def __str__(self):
        return (
            f"SOS #{self.pk} — {self.patient.get_full_name()} "
            f"[{self.status}] @ {self.confirmed_at:%Y-%m-%d %H:%M}"
        )


# ---------------------------------------------------------------------------
# Emergency Status Log  (immutable audit trail, FR-5.7 / FR-7.6)
# ---------------------------------------------------------------------------

class EmergencyStatusLog(models.Model):
    """
    One row per status change on an EmergencyRequest.
    Provides the full history: when the status changed, who changed it, and any notes.
    Never mutated — only inserted.
    """

    request       = models.ForeignKey(
        EmergencyRequest,
        on_delete=models.CASCADE,
        related_name="status_logs",
    )
    previous_status = models.CharField(max_length=15, choices=EmergencyStatus.choices)
    new_status      = models.CharField(max_length=15, choices=EmergencyStatus.choices)
    changed_by      = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="emergency_status_changes",
    )
    notes           = models.TextField(blank=True, default="")
    created_at      = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name        = _("Emergency Status Log")
        verbose_name_plural = _("Emergency Status Logs")
        ordering            = ["created_at"]
        default_permissions = ("view",)   # immutable — no add/change/delete via admin

    def __str__(self):
        return (
            f"SOS #{self.request_id} | "
            f"{self.previous_status} → {self.new_status} "
            f"by {self.changed_by} @ {self.created_at:%H:%M:%S}"
        )        


# ---------------------------------------------------------------------------
# In-App Notifications
# ---------------------------------------------------------------------------

class NotificationType(models.TextChoices):
    APPOINTMENT = "appointment", _("Appointment")
    QUEUE       = "queue",       _("Queue")
    EMERGENCY   = "emergency",   _("Emergency")
    MESSAGE     = "message",     _("Message")
    REMINDER    = "reminder",    _("Reminder")


class Notification(models.Model):
    """
    Persistent in-app notification record.
    Dispatched whenever a relevant event occurs (queue called, appointment
    booked/cancelled/rescheduled, emergency status change, reminders, etc.)
    so the patient/doctor/admin can see it in the app notification inbox.
    """

    recipient   = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="notifications",
    )
    type        = models.CharField(
        max_length=20,
        choices=NotificationType.choices,
        default=NotificationType.APPOINTMENT,
    )
    title       = models.CharField(max_length=255)
    message     = models.TextField()
    is_read     = models.BooleanField(default=False)
    action_url  = models.CharField(max_length=255, blank=True, default="")
    metadata    = models.JSONField(default=dict, blank=True)
    created_at  = models.DateTimeField(auto_now_add=True)
    updated_at  = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name        = _("Notification")
        verbose_name_plural = _("Notifications")
        ordering            = ["-created_at"]
        indexes = [
            models.Index(fields=["recipient", "is_read"]),
            models.Index(fields=["recipient", "-created_at"]),
        ]

    def __str__(self):
        return f"{self.recipient} — {self.title}"        