"""
accounts/services.py

Business logic layer — keeps views thin and logic testable.
All external I/O (OTP dispatch, notifications) is isolated here so
real SMS/WhatsApp providers can be swapped in without touching views.
"""

import datetime
import logging
import os

from django.utils import timezone
from .models import AuditLog, OTPVerification, User
from django.db.models import Avg, Count, Q
from django.db import transaction
from django.db.models import Q

from .models import (
    User,
    Appointment,
    AppointmentStatus,
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
    NotificationType,
    VALID_STATUS_TRANSITIONS,
)

logger = logging.getLogger(__name__)


"""
queue/services.py

Business logic for Module 3: Virtual Queuing System.
All state mutations are atomic transactions.
Firebase sync is a best-effort side-effect — DB is always written first.

Services:
  QueueService        — core queue lifecycle (assign, advance, call, pause, leave)
  FirebaseQueueSync   — pushes queue snapshots to Firebase Realtime DB
  QueueAnalyticsService — FR-3.7 admin statistics
  WaitTimeService     — FR-3.8 algorithm + nightly avg update
"""

# ---------------------------------------------------------------------------
# OTP Service
# ---------------------------------------------------------------------------

class OTPService:
    """
    Generates OTPs locally and dispatches them via Brevo Transactional Email API.
    Brevo only sends the email content — it has no server-side OTP
    generation/verification, so the code itself is generated and checked here.
    """

    BREVO_EMAIL_SEND_URL = "https://api.brevo.com/v3/smtp/email"
    BREVO_SMS_SEND_URL   = "https://api.brevo.com/v3/transactionalSMS/sms"

    @staticmethod
    def send_otp(user: User, purpose: str = OTPVerification.Purpose.PHONE_REGISTRATION) -> OTPVerification:
        otp = OTPVerification.generate_for(user, purpose)
        OTPService._dispatch_brevo(user, otp.code, purpose)
        OTPService._dispatch_sms(user, otp.code, purpose)
        return otp

    @staticmethod
    def _dispatch_brevo(user: User, code: str, purpose: str) -> bool:
        """
        Sends OTP email via Brevo Transactional Email API.
        Returns True on success, False on failure.
        """
        import requests

        email = user.email
        if not email:
            logger.warning("Cannot send OTP: user %s has no email address", user.username)
            return False

        api_key      = os.environ.get("BREVO_API_KEY")
        sender_email = os.environ.get("BREVO_SENDER_EMAIL")
        sender_name  = os.environ.get("BREVO_SENDER_NAME", "MedQueue")

        if not api_key or not sender_email:
            logger.warning(
                "Brevo credentials not configured, falling back to mock. "
                "Set BREVO_API_KEY and BREVO_SENDER_EMAIL."
            )
            OTPService._mock_send(user, code, purpose)
            return False

        headers = {
            "api-key":      api_key,
            "Content-Type": "application/json",
            "Accept":       "application/json",
        }
        payload = {
            "sender":      {"name": sender_name, "email": sender_email},
            "to":          [{"email": email}],
            "subject":     "Your MedQueue verification code",
            "htmlContent": (
                f"<p>Your MedQueue verification code is <strong>{code}</strong>.</p>"
                f"<p>This code will expire shortly. If you didn't request this, "
                f"you can ignore this email.</p>"
            ),
            "tags": [purpose],
        }

        try:
            response = requests.post(
                OTPService.BREVO_EMAIL_SEND_URL,
                json=payload,
                headers=headers,
                timeout=30,
            )
            if response.status_code in (200, 201):
                logger.info("OTP sent via Brevo email to %s for purpose: %s", email, purpose)
                OTPService._mock_send(user, code, purpose)
                return True
            else:
                logger.error(
                    "Brevo OTP email send failed %s: %s",
                    response.status_code,
                    response.text,
                )
                OTPService._mock_send(user, code, purpose)
        except Exception as exc:
            logger.error("Failed to send OTP via Brevo email to %s: %s", email, exc)
            OTPService._mock_send(user, code, purpose)

        return False

    @staticmethod
    def _dispatch_sms(user: User, code: str, purpose: str) -> bool:
        """
        Sends the OTP code via Brevo Transactional SMS, if configured.

        Requires an approved SMS sender in Brevo plus SMS credits on the
        account. Set BREVO_SMS_SENDER in .env (approved sender name/id).
        Failures are logged but never crash the flow.
        """
        import requests

        phone = (user.phone_number or "").strip()
        if not phone:
            logger.warning(
                "Cannot SMS OTP: user %s has no phone number", user.username
            )
            return False

        api_key = os.environ.get("BREVO_API_KEY")
        sender  = os.environ.get("BREVO_SMS_SENDER")

        if not api_key or not sender:
            logger.warning(
                "Brevo SMS not configured (set BREVO_SMS_SENDER in .env); "
                "OTP for %s delivered via email/console only.", phone
            )
            return False

        headers = {
            "api-key":      api_key,
            "Content-Type": "application/json",
            "Accept":       "application/json",
        }
        payload = {
            "recipient":       phone,
            "sender":          sender,
            "type":            "transactional",
            "unicodeEnabled":  False,
            "content":         f"Your MedQueue verification code is {code}.",
            "webUrl":          "https://medqueue.gh/sms",
            "tag":             purpose,
        }

        try:
            response = requests.post(
                OTPService.BREVO_SMS_SEND_URL,
                json=payload,
                headers=headers,
                timeout=30,
            )
            if response.status_code in (200, 201):
                logger.info(
                    "OTP sent via Brevo SMS to %s for purpose: %s",
                    phone, purpose,
                )
                return True
            logger.error(
                "Brevo SMS send failed %s: %s",
                response.status_code,
                response.text,
            )
        except Exception as exc:
            logger.error("Failed to send OTP via Brevo SMS to %s: %s", phone, exc)

        return False

    @staticmethod
    def _mock_send(user: User, code: str, purpose: str) -> None:
        """Console mock for development when Brevo not configured."""
        logger.info("[OTP MOCK] Sending %s OTP to %s", purpose, user.email)
        print(f"\n{'='*50}", flush=True)
        print(f"  OTP SEND TO ->  {user.email}", flush=True)
        print(f"  Purpose     ->  {purpose}", flush=True)
        print(f"  Code        ->  {code}", flush=True)
        print(f"{'='*50}\n", flush=True)

    @staticmethod
    def resend_otp(user: User, purpose: str = OTPVerification.Purpose.PHONE_REGISTRATION) -> OTPVerification | None:
        """
        Resend OTP. Since Brevo has no server-side OTP session to resend against,
        this re-sends the existing unused code if still valid, otherwise
        generates a fresh one.
        """
        email = user.email
        if not email:
            logger.warning("Cannot resend OTP: user %s has no email address", user.username)
            return None

        existing = (
            OTPVerification.objects
            .filter(user=user, purpose=purpose, is_used=False)
            .order_by("-created_at")
            .first()
        )

        if existing and existing.is_valid:
            OTPService._dispatch_brevo(user, existing.code, purpose)
            OTPService._dispatch_sms(user, existing.code, purpose)
            return existing

        # No valid existing OTP — issue a new one
        return OTPService.send_otp(user, purpose)

    @staticmethod
    def verify(email: str, code: str, purpose: str) -> tuple[bool, str, User | None]:
        """
        Verify OTP locally against the stored plaintext code
        (Brevo does not verify codes itself).
        Returns (success: bool, message: str, user: User | None)
        """
        try:
            user = User.objects.filter(email__iexact=email).first()
            if user is None:
                user = User.objects.filter(phone_number=email).first()
        except User.DoesNotExist:
            return False, "No account with this email address.", None

        otp = (
            OTPVerification.objects
            .filter(user=user, purpose=purpose, is_used=False)
            .order_by("-created_at")
            .first()
        )
        if otp is None:
            return False, "No active OTP session found. Please request a new code.", None
        if not otp.is_valid:
            return False, "OTP has expired.", None

        if otp.code != code:
            return False, "Invalid OTP code.", None

        otp.consume()
        return True, "OTP verified successfully.", user
# ---------------------------------------------------------------------------
# Audit Service
# ---------------------------------------------------------------------------

class AuditService:
    """
    Thin wrapper around AuditLog.objects.create.
    Centralises IP / user-agent extraction from requests.
    """

    @staticmethod
    def log(
        event_type: str,
        user: User | None = None,
        description: str = "",
        request=None,
        metadata: dict | None = None,
    ) -> AuditLog:
        ip         = None
        user_agent = ""

        if request is not None:
            ip         = AuditService._get_client_ip(request)
            user_agent = request.META.get("HTTP_USER_AGENT", "")[:256]

        return AuditLog.objects.create(
            user        = user,
            event_type  = event_type,
            description = description,
            ip_address  = ip,
            user_agent  = user_agent,
            metadata    = metadata or {},
        )

    @staticmethod
    def _get_client_ip(request) -> str | None:
        """
        Handles X-Forwarded-For header set by Nginx / load balancers.
        Takes the first (leftmost) IP which is the original client.
        """
        x_forwarded = request.META.get("HTTP_X_FORWARDED_FOR")
        if x_forwarded:
            return x_forwarded.split(",")[0].strip()
        return request.META.get("REMOTE_ADDR")


# ---------------------------------------------------------------------------
# Account Lockout Notification
# ---------------------------------------------------------------------------

def notify_lockout(user: User) -> None:
    """
    Inform the user their account has been locked.
    Mock implementation — wire up to FCM / SMS in production.
    """
    logger.warning(
        "[LOCKOUT] Account locked for user %s until %s",
        user.username,
        user.lockout_until,
    )


# ---------------------------------------------------------------------------
# Slot Service
# ---------------------------------------------------------------------------

class SlotService:
    """
    Responsible for generating and serving TimeSlot objects.

    Slot generation strategy:
      Slots are created on-demand when a patient browses a doctor's availability
      for a given date (lazy generation).  A Celery beat task can also call
      `generate_slots_for_date()` nightly to pre-generate the next 30 days.
    """

    @staticmethod
    def get_available_slots(doctor: User, date: datetime.date) -> list[TimeSlot]:
        """
        FR-2.2: Return all AVAILABLE slots for a doctor on a given date.
        Generates slots first if none exist yet.
        """
        # Ensure slots exist for this date
        SlotService.generate_slots_for_date(doctor, date)

        return list(
            TimeSlot.objects.filter(
                doctor=doctor,
                date=date,
                status=SlotStatus.AVAILABLE,
            ).order_by("start_time")
        )

    @staticmethod
    def generate_slots_for_date(doctor: User, date: datetime.date) -> int:
        """
        Creates TimeSlot rows for a doctor on `date` based on their DoctorSchedule.
        Idempotent: skips slots that already exist (uses get_or_create).
        Returns the number of slots newly created.
        """
        day_of_week = date.weekday()   # 0 = Monday

        # Check for date-specific override first
        override = DoctorAvailabilityOverride.objects.filter(
            doctor=doctor,
            date=date,
        ).first()

        if override:
            if override.override_type == "unavailable":
                logger.debug(
                    "Dr. %s is marked unavailable on %s (override)", doctor.username, date
                )
                return 0
            # Available override. If the doctor gave custom hours we use the
            # override's own duration/cap; otherwise the override mirrors the
            # weekly schedule completely (hours AND slot duration AND cap).
            if not override.start_time and not override.end_time:
                try:
                    schedule = DoctorSchedule.objects.get(
                        doctor=doctor,
                        day_of_week=day_of_week,
                        is_active=True,
                    )
                    start_time = schedule.start_time
                    end_time = schedule.end_time
                    slot_duration = schedule.slot_duration_minutes
                    max_patients = schedule.max_patients_per_day
                except DoctorSchedule.DoesNotExist:
                    return 0
            else:
                start_time = override.start_time
                end_time = override.end_time
                slot_duration = override.slot_duration_minutes
                max_patients = override.max_patients_per_day

                # Fill in any missing side (e.g. only start_time given)
                if not start_time or not end_time:
                    try:
                        schedule = DoctorSchedule.objects.get(
                            doctor=doctor,
                            day_of_week=day_of_week,
                            is_active=True,
                        )
                        start_time = start_time or schedule.start_time
                        end_time = end_time or schedule.end_time
                        slot_duration = slot_duration or schedule.slot_duration_minutes
                        max_patients = max_patients or schedule.max_patients_per_day
                    except DoctorSchedule.DoesNotExist:
                        return 0
        else:
            # No override — use regular schedule
            try:
                schedule = DoctorSchedule.objects.get(
                    doctor=doctor,
                    day_of_week=day_of_week,
                    is_active=True,
                )
            except DoctorSchedule.DoesNotExist:
                logger.debug(
                    "No schedule for Dr. %s on day %d (%s)", doctor.username, day_of_week, date
                )
                return 0
            start_time = schedule.start_time
            end_time = schedule.end_time
            slot_duration = schedule.slot_duration_minutes
            max_patients = schedule.max_patients_per_day

        # Check daily patient cap
        existing_booked = TimeSlot.objects.filter(
            doctor=doctor, date=date, status=SlotStatus.BOOKED
        ).count()
        if existing_booked >= max_patients:
            logger.info("Daily cap reached for Dr. %s on %s", doctor.username, date)
            return 0

        # Walk start_time → end_time in slot_duration steps
        created_count = 0
        slot_start = start_time
        duration = datetime.timedelta(minutes=slot_duration)

        while True:
            slot_end_dt = (
                datetime.datetime.combine(date, slot_start) + duration
            )
            slot_end = slot_end_dt.time()

            if slot_end > end_time:
                break

            _, created = TimeSlot.objects.get_or_create(
                doctor     = doctor,
                date       = date,
                start_time = slot_start,
                defaults   = {
                    "end_time": slot_end,
                    "status":   SlotStatus.AVAILABLE,
                },
            )
            if created:
                created_count += 1

            slot_start = slot_end
            if slot_start >= end_time:
                break

        logger.info(
            "Generated %d new slot(s) for Dr. %s on %s",
            created_count, doctor.username, date,
        )
        return created_count

    @staticmethod
    def date_has_slots(doctor: User, date: datetime.date) -> bool:
        """
        True if `generate_slots_for_date(doctor, date)` would produce slots.
        Pure read-only check (no rows created) — used to grey out dates in the
        patient booking calendar (FR-2.2).
        """
        override = DoctorAvailabilityOverride.objects.filter(
            doctor=doctor,
            date=date,
        ).first()
        if override:
            if override.override_type == "unavailable":
                return False
            # Available override mirrors the weekly schedule unless custom
            # hours were provided (mirror of generate_slots_for_date).
            if not override.start_time and not override.end_time:
                return DoctorSchedule.objects.filter(
                    doctor=doctor,
                    day_of_week=date.weekday(),
                    is_active=True,
                ).exists()
            return True
        return DoctorSchedule.objects.filter(
            doctor=doctor,
            day_of_week=date.weekday(),
            is_active=True,
        ).exists()

    @staticmethod
    def available_dates(doctor: User, start: datetime.date, end: datetime.date) -> list[datetime.date]:
        """Return sorted list of dates in [start, end] that have bookable slots."""
        result: list[datetime.date] = []
        current = start
        while current <= end:
            if SlotService.date_has_slots(doctor, current):
                result.append(current)
            current = current + datetime.timedelta(days=1)
        return result

    @staticmethod
    def block_slot(slot: TimeSlot) -> None:
        """Admin manually blocks a slot (FR-7.2)."""
        if slot.status == SlotStatus.BOOKED:
            raise ValueError("Cannot block an already-booked slot.")
        slot.status = SlotStatus.BLOCKED
        slot.save(update_fields=["status"])

    @staticmethod
    def release_slot(slot: TimeSlot) -> None:
        """Return a slot to AVAILABLE (called on cancellation/reschedule)."""
        if slot.status == SlotStatus.AVAILABLE:
            return  # idempotent
        slot.status = SlotStatus.AVAILABLE
        slot.save(update_fields=["status"])


# ---------------------------------------------------------------------------
# Appointment Service
# ---------------------------------------------------------------------------

class AppointmentService:
    """
    All appointment lifecycle operations.
    Every public method is wrapped in `transaction.atomic()` so partial
    failures never leave the database in an inconsistent state.
    """

    # ------------------------------------------------------------------
    # Book (FR-2.3)
    # ------------------------------------------------------------------

    @staticmethod
    @transaction.atomic
    def book(patient: User, slot: TimeSlot, reason: str = "") -> Appointment:
        """
        Book an appointment for `patient` on `slot`.

        Uses SELECT FOR UPDATE to lock the slot row so concurrent requests
        for the same slot are serialised at the DB level (FR-2.2 anti-double-booking).
        """
        # Lock the slot row to prevent concurrent booking
        slot = (
            TimeSlot.objects.select_for_update()
            .get(pk=slot.pk)
        )

        if slot.status != SlotStatus.AVAILABLE:
            raise ValueError(
                "This slot was just taken by another patient. Please choose another."
            )

        # Mark slot as booked
        slot.status = SlotStatus.BOOKED
        slot.save(update_fields=["status"])

        # Create appointment
        appointment = Appointment.objects.create(
            patient          = patient,
            doctor           = slot.doctor,
            slot             = slot,
            appointment_date = slot.date,
            appointment_time = slot.start_time,
            status           = AppointmentStatus.CONFIRMED,
            reason           = reason,
        )

        logger.info(
            "Appointment #%d booked: patient=%s doctor=%s slot=%s",
            appointment.pk, patient.username, slot.doctor.username, slot.pk,
        )

        # Fire notifications (stub — Module 6 wires this up)
        AppointmentNotificationService.on_booked(appointment)

        return appointment

    # ------------------------------------------------------------------
    # Cancel (FR-2.5)
    # ------------------------------------------------------------------

    @staticmethod
    @transaction.atomic
    def cancel(
        appointment: Appointment,
        by_user: User,
        reason: str = "",
    ) -> Appointment:
        """Cancel an appointment and release its slot."""
        allowed, msg = appointment.can_cancel(by_user=by_user)
        if not allowed:
            raise ValueError(msg)

        appointment.transition_status(AppointmentStatus.CANCELLED)
        appointment.cancelled_by       = by_user
        appointment.cancellation_reason= reason

        # Release the slot so other patients can book it
        if appointment.slot:
            SlotService.release_slot(appointment.slot)
            appointment.slot = None   # detach FK

        appointment.save()

        logger.info(
            "Appointment #%d cancelled by %s. Reason: %s",
            appointment.pk, by_user.username, reason or "(none)",
        )

        # Fire notifications
        AppointmentNotificationService.on_cancelled(appointment, by_user)

        return appointment

    # ------------------------------------------------------------------
    # Reschedule (FR-2.6)
    # ------------------------------------------------------------------

    @staticmethod
    @transaction.atomic
    def reschedule(
        old_appointment: Appointment,
        new_slot: TimeSlot,
        by_user: User,
        reason: str = "",
    ) -> Appointment:
        """
        Reschedule to a new slot.
        Strategy:
          1. Validate old appointment is reschedulable.
          2. Lock and validate new slot.
          3. Release old slot.
          4. Mark old appointment RESCHEDULED.
          5. Create new appointment pointing to new slot.
        """
        allowed, msg = old_appointment.can_reschedule()
        if not allowed:
            raise ValueError(msg)

        # Block rescheduling for phone/call-in appointments
        if old_appointment.booked_by_reception:
            raise ValueError(
                "Phone/call-in appointments cannot be rescheduled online. "
                "Please contact the hospital directly to reschedule."
            )

        # Lock and validate new slot
        new_slot = (
            TimeSlot.objects.select_for_update()
            .get(pk=new_slot.pk)
        )
        if new_slot.status != SlotStatus.AVAILABLE:
            raise ValueError(
                "The selected slot is no longer available. Please choose another."
            )

        # Prevent same patient booking same doctor on same day (unless it's the same appointment being rescheduled)
        existing = Appointment.objects.filter(
            patient=old_appointment.patient,
            doctor=new_slot.doctor,
            appointment_date=new_slot.date,
            status__in=[AppointmentStatus.PENDING, AppointmentStatus.CONFIRMED],
        ).exclude(pk=old_appointment.pk).first()
        if existing:
            raise ValueError(
                "You already have an active appointment with this doctor on this date."
            )

        # Release old slot
        if old_appointment.slot:
            SlotService.release_slot(old_appointment.slot)

        # Mark old appointment as rescheduled
        old_appointment.transition_status(AppointmentStatus.RESCHEDULED)
        old_appointment.slot = None
        old_appointment.save()

        # Book new slot
        new_slot.status = SlotStatus.BOOKED
        new_slot.save(update_fields=["status"])

        new_appointment = Appointment.objects.create(
            patient           = old_appointment.patient,
            doctor            = new_slot.doctor,
            slot              = new_slot,
            appointment_date  = new_slot.date,
            appointment_time  = new_slot.start_time,
            status            = AppointmentStatus.CONFIRMED,
            reason            = reason or old_appointment.reason,
            rescheduled_from  = old_appointment,
        )

        logger.info(
            "Appointment #%d rescheduled → new Appointment #%d by %s",
            old_appointment.pk, new_appointment.pk, by_user.username,
        )

        # Fire notifications
        AppointmentNotificationService.on_rescheduled(old_appointment, new_appointment)

        return new_appointment

    # ------------------------------------------------------------------
    # Doctor: mark complete / no-show  (FR-2.7, FR-2.9)
    # ------------------------------------------------------------------

    @staticmethod
    @transaction.atomic
    def mark_status(
        appointment: Appointment,
        new_status: str,
        doctor: User,
        notes: str = "",
    ) -> Appointment:
        """
        Doctor marks appointment COMPLETED or NO_SHOW.
        Triggers queue advancement (Module 3 will hook here).
        """
        appointment.transition_status(new_status)
        if notes:
            appointment.notes = notes
        appointment.save()

        logger.info(
            "Appointment #%d marked '%s' by Dr. %s",
            appointment.pk, new_status, doctor.username,
        )

        # Notify and advance queue
        if new_status == AppointmentStatus.COMPLETED:
            AppointmentNotificationService.on_completed(appointment)
        elif new_status == AppointmentStatus.NO_SHOW:
            AppointmentNotificationService.on_no_show(appointment)

        # Signal to queue module (will be implemented in Module 3)
        _advance_queue_signal(appointment)

        return appointment

    # ------------------------------------------------------------------
    # Admin override  (FR-2.10)
    # ------------------------------------------------------------------

    @staticmethod
    @transaction.atomic
    def admin_create(
        patient: User,
        slot: TimeSlot,
        reason: str = "",
    ) -> Appointment:
        """Admin creates an appointment on behalf of a patient."""
        return AppointmentService.book(patient, slot, reason)

    @staticmethod
    @transaction.atomic
    def admin_update_status(
        appointment: Appointment,
        new_status: str,
        admin: User,
        notes: str = "",
    ) -> Appointment:
        """Admin forces a status change on any appointment."""
        # Admin bypasses the normal transition guard for overrides
        appointment.status = new_status
        if notes:
            appointment.notes = notes
        appointment.save()

        logger.warning(
            "Admin %s forced Appointment #%d to status '%s'.",
            admin.username, appointment.pk, new_status,
        )
        return appointment


# ---------------------------------------------------------------------------
# Queue signal stub
# ---------------------------------------------------------------------------

def _advance_queue_signal(appointment: Appointment) -> None:
    """
    Notifies the queue module that a consultation ended.
    Module 3 will import and override this.
    In Django, use django.dispatch.Signal for decoupled signalling.
    """
    logger.debug(
        "[QueueSignal] Consultation ended for Appointment #%d — "
        "Module 3 should advance the queue.",
        appointment.pk,
    )


# ---------------------------------------------------------------------------
# Notification Service stub  (Module 6 wires the real implementations)
# ---------------------------------------------------------------------------

class NotificationDispatcher:
    """
    Creates persistent in-app Notification records.
    Every notification event calls one of these helpers; the recipient
    sees the result immediately in their in-app notification inbox.
    """

    @staticmethod
    def _create(recipient: User, ntype: str, title: str, message: str,
                action_url: str = "", metadata: dict | None = None) -> None:
        from .models import Notification, NotificationType

        try:
            Notification.objects.create(
                recipient=recipient,
                type=ntype,
                title=title,
                message=message,
                action_url=action_url,
                metadata=metadata or {},
            )
        except Exception as exc:
            # A notification failure must never break the core transaction.
            logger.error("[Notification] create failed: %s", exc)

    # ------------------------------------------------------------------
    # Appointment events
    # ------------------------------------------------------------------
    @staticmethod
    def appointment_booked(appointment: Appointment) -> None:
        NotificationDispatcher._create(
            appointment.patient,
            NotificationType.APPOINTMENT,
            "Appointment Confirmed",
            f"Your appointment with Dr. {appointment.doctor.get_full_name()} "
            f"on {appointment.appointment_date} at {appointment.appointment_time} "
            f"has been confirmed.",
            action_url="/patient/appointments-history",
            metadata={"appointment_id": appointment.pk},
        )
        NotificationDispatcher._create(
            appointment.doctor,
            NotificationType.APPOINTMENT,
            "New Appointment",
            f"{appointment.patient.get_full_name()} booked an appointment "
            f"on {appointment.appointment_date} at {appointment.appointment_time}.",
            action_url="/doctor-home",
            metadata={"appointment_id": appointment.pk},
        )

    @staticmethod
    def appointment_cancelled(appointment: Appointment, by_user: User) -> None:
        NotificationDispatcher._create(
            appointment.patient,
            NotificationType.APPOINTMENT,
            "Appointment Cancelled",
            f"Your appointment with Dr. {appointment.doctor.get_full_name()} "
            f"on {appointment.appointment_date} at {appointment.appointment_time} "
            f"was cancelled.",
            action_url="/patient/appointments-history",
            metadata={"appointment_id": appointment.pk},
        )
        NotificationDispatcher._create(
            appointment.doctor,
            NotificationType.APPOINTMENT,
            "Appointment Cancelled",
            f"{appointment.patient.get_full_name()} cancelled the appointment "
            f"on {appointment.appointment_date} at {appointment.appointment_time}.",
            action_url="/doctor-home",
            metadata={"appointment_id": appointment.pk},
        )

    @staticmethod
    def appointment_rescheduled(old: Appointment, new: Appointment) -> None:
        NotificationDispatcher._create(
            old.patient,
            NotificationType.APPOINTMENT,
            "Appointment Rescheduled",
            f"Your appointment with Dr. {old.doctor.get_full_name()} was moved "
            f"from {old.appointment_date} {old.appointment_time} to "
            f"{new.appointment_date} {new.appointment_time}.",
            action_url="/patient/appointments-history",
            metadata={"appointment_id": new.pk},
        )
        NotificationDispatcher._create(
            old.doctor,
            NotificationType.APPOINTMENT,
            "Appointment Rescheduled",
            f"{old.patient.get_full_name()}'s appointment was moved "
            f"to {new.appointment_date} {new.appointment_time}.",
            action_url="/doctor-home",
            metadata={"appointment_id": new.pk},
        )

    @staticmethod
    def appointment_completed(appointment: Appointment) -> None:
        NotificationDispatcher._create(
            appointment.patient,
            NotificationType.APPOINTMENT,
            "Consultation Completed",
            f"Your consultation with Dr. {appointment.doctor.get_full_name()} "
            f"has been completed.",
            action_url="/patient/appointments-history",
            metadata={"appointment_id": appointment.pk},
        )

    @staticmethod
    def appointment_no_show(appointment: Appointment) -> None:
        NotificationDispatcher._create(
            appointment.patient,
            NotificationType.APPOINTMENT,
            "Appointment Missed",
            f"You were marked as a no-show for your appointment with "
            f"Dr. {appointment.doctor.get_full_name()} on "
            f"{appointment.appointment_date} at {appointment.appointment_time}. "
            f"Please contact the clinic if this was a mistake.",
            action_url="/patient/appointments-history",
            metadata={"appointment_id": appointment.pk},
        )

    # ------------------------------------------------------------------
    # Queue events
    # ------------------------------------------------------------------
    @staticmethod
    def queue_called(entry: QueueEntry) -> None:
        NotificationDispatcher._create(
            entry.patient,
            NotificationType.QUEUE,
            "It's Your Turn!",
            "Please proceed to the consultation room now.",
            action_url="/queue-tracker",
            metadata={"queue_entry_id": entry.pk, "queue_number": entry.queue_number},
        )

    @staticmethod
    def queue_2away(entry: QueueEntry) -> None:
        NotificationDispatcher._create(
            entry.patient,
            NotificationType.QUEUE,
            "You're Almost There",
            "You are 2 patients away. Please make your way to the clinic.",
            action_url="/queue-tracker",
            metadata={"queue_entry_id": entry.pk, "queue_number": entry.queue_number},
        )

    @staticmethod
    def queue_paused(session: QueueSession, reason: str) -> None:
        entries = session.entries.filter(status=QueueEntryStatus.WAITING)
        for entry in entries:
            NotificationDispatcher._create(
                entry.patient,
                NotificationType.QUEUE,
                "Queue Paused",
                f"The queue for Dr. {session.doctor.get_full_name()} is temporarily "
                f"paused. {reason or 'Please stay nearby.'}",
                action_url="/queue-tracker",
                metadata={"session_id": session.pk},
            )

    @staticmethod
    def queue_resumed(session: QueueSession) -> None:
        entries = session.entries.filter(status=QueueEntryStatus.WAITING)
        for entry in entries:
            NotificationDispatcher._create(
                entry.patient,
                NotificationType.QUEUE,
                "Queue Resumed",
                f"The queue for Dr. {session.doctor.get_full_name()} has resumed.",
                action_url="/queue-tracker",
                metadata={"session_id": session.pk},
            )

    # ------------------------------------------------------------------
    # Emergency events
    # ------------------------------------------------------------------
    @staticmethod
    def emergency_acknowledged(request: EmergencyRequest) -> None:
        NotificationDispatcher._create(
            request.patient,
            NotificationType.EMERGENCY,
            "Emergency Received",
            "🚑 Emergency request received. Our team has been alerted and "
            "help is on the way. Please stay calm and remain at your location.",
            action_url="/emergency-sos",
            metadata={"emergency_id": request.pk},
        )

    @staticmethod
    def emergency_status_changed(request: EmergencyRequest) -> None:
        messages = {
            EmergencyStatus.DISPATCHED: (
                f"🚑 Help is on the way! "
                f"{'Ambulance ' + request.ambulance_plate + ' has been dispatched. ' if request.ambulance_plate else ''}"
                f"{'ETA: ' + str(request.ambulance_eta_minutes) + ' minutes.' if request.ambulance_eta_minutes else ''}"
            ).strip(),
            EmergencyStatus.RESOLVED: (
                "✅ Your emergency request has been resolved. "
                "Please contact the hospital if you need further assistance."
            ),
            EmergencyStatus.FALSE_ALARM: (
                "Your emergency request has been closed as a false alarm. "
                "If you need help, please submit a new SOS."
            ),
            EmergencyStatus.CANCELLED: (
                "Your emergency request has been cancelled."
            ),
        }
        msg = messages.get(
            request.status, f"SOS status updated to: {request.status}"
        )
        title = "Emergency Update"
        if request.status == EmergencyStatus.DISPATCHED:
            title = "Help is on the Way"
        elif request.status == EmergencyStatus.RESOLVED:
            title = "Emergency Resolved"
        NotificationDispatcher._create(
            request.patient,
            NotificationType.EMERGENCY,
            title,
            msg,
            action_url="/emergency-sos",
            metadata={"emergency_id": request.pk},
        )

    @staticmethod
    def emergency_cancelled(request: EmergencyRequest) -> None:
        NotificationDispatcher._create(
            request.patient,
            NotificationType.EMERGENCY,
            "SOS Cancelled",
            "Your emergency request has been cancelled.",
            action_url="/emergency-sos",
            metadata={"emergency_id": request.pk},
        )

    # ------------------------------------------------------------------
    # Reminders
    # ------------------------------------------------------------------
    @staticmethod
    def appointment_reminder(appointment: Appointment, *, hours_before: int) -> None:
        NotificationDispatcher._create(
            appointment.patient,
            NotificationType.REMINDER,
            "Appointment Reminder",
            f"Reminder: your appointment with Dr. {appointment.doctor.get_full_name()} "
            f"is in {hours_before} hour{'s' if hours_before != 1 else ''} "
            f"({appointment.appointment_date} at {appointment.appointment_time}).",
            action_url="/patient/appointments-history",
            metadata={"appointment_id": appointment.pk},
        )


class AppointmentNotificationService:
    """
    Dispatches in-app notifications for appointment events and keeps the
    log output for external channels (SMS/WhatsApp wired in Module 6).
    """

    @staticmethod
    def on_booked(appointment: Appointment) -> None:
        NotificationDispatcher.appointment_booked(appointment)
        logger.info(
            "[NOTIFY] Booking confirmed → patient %s | doctor %s | %s %s",
            appointment.patient.phone_number,
            appointment.doctor.phone_number,
            appointment.appointment_date,
            appointment.appointment_time,
        )

    @staticmethod
    def on_cancelled(appointment: Appointment, by_user: User) -> None:
        NotificationDispatcher.appointment_cancelled(appointment, by_user)
        logger.info(
            "[NOTIFY] Cancellation alert → patient %s | doctor %s | cancelled by %s",
            appointment.patient.phone_number,
            appointment.doctor.phone_number,
            by_user.username,
        )

    @staticmethod
    def on_rescheduled(old: Appointment, new: Appointment) -> None:
        NotificationDispatcher.appointment_rescheduled(old, new)
        logger.info(
            "[NOTIFY] Reschedule → patient %s | old=%s new=%s",
            old.patient.phone_number,
            f"{old.appointment_date} {old.appointment_time}",
            f"{new.appointment_date} {new.appointment_time}",
        )

    @staticmethod
    def on_completed(appointment: Appointment) -> None:
        NotificationDispatcher.appointment_completed(appointment)
        logger.info(
            "[NOTIFY] Consultation completed → Appointment #%d", appointment.pk
        )

    @staticmethod
    def on_no_show(appointment: Appointment) -> None:
        NotificationDispatcher.appointment_no_show(appointment)
        logger.info(
            "[NOTIFY] No-show alert → patient %s for Appointment #%d",
            appointment.patient.phone_number,
            appointment.pk,
        )    


# ---------------------------------------------------------------------------
# Firebase Sync  (real-time transport, FR-3.2)
# ---------------------------------------------------------------------------

class FirebaseQueueSync:
    """
    Pushes a queue snapshot to Firebase Realtime Database every time
    the queue state changes.  Flutter clients subscribe to:
      /queues/{doctor_id}/{date}/

    Structure pushed:
    {
      "session_status": "active",
      "current_position": 3,
      "waiting_count": 7,
      "updated_at": "2026-06-10T08:32:00Z",
      "entries": {
        "1": {"patient_name": "...", "status": "completed", "queue_number": 1},
        "3": {"patient_name": "...", "status": "called",    "queue_number": 3},
        ...
      }
    }

    MOCK implementation — replace firebase_admin call block with real SDK
    in production (firebase_admin is in requirements.txt).
    """

    @staticmethod
    def push_session(session: QueueSession) -> None:
        """Push the full session snapshot to Firebase."""
        try:
            snapshot = FirebaseQueueSync._build_snapshot(session)
            path = f"queues/{session.doctor_id}/{session.date}"
            FirebaseQueueSync._write(path, snapshot)
        except Exception as exc:
            # Firebase failure must NEVER break the core DB transaction
            logger.error("[Firebase] Push failed for session %d: %s", session.pk, exc)

    @staticmethod
    def push_entry(entry: QueueEntry) -> None:
        """Push a single entry update (faster than full session re-push)."""
        try:
            session = entry.session
            path    = f"queues/{session.doctor_id}/{session.date}/entries/{entry.queue_number}"
            FirebaseQueueSync._write(path, {
                "queue_number":         entry.queue_number,
                "patient_id":           entry.patient_id,
                "patient_name":         entry.patient.get_full_name(),
                "status":               entry.status,
                "positions_ahead":      entry.positions_ahead,
                "estimated_wait_mins":  entry.estimated_wait_minutes,
                "notified_2away":       entry.notified_2away,
            })
        except Exception as exc:
            logger.error("[Firebase] Entry push failed for entry %d: %s", entry.pk, exc)

    @staticmethod
    def _build_snapshot(session: QueueSession) -> dict:
        entries = session.entries.select_related("patient").order_by("queue_number")
        return {
            "session_id":       session.pk,
            "doctor_id":        session.doctor_id,
            "doctor_name":      session.doctor.get_full_name(),
            "date":             str(session.date),
            "status":           session.status,
            "current_position": session.current_position,
            "waiting_count":    session.waiting_count,
            "served_count":     session.served_count,
            "is_paused":        session.is_paused,
            "pause_reason":     session.pause_reason,
            "updated_at":       timezone.now().isoformat(),
            "entries": {
                str(e.queue_number): {
                    "queue_number":        e.queue_number,
                    "patient_id":          e.patient_id,
                    "patient_name":        e.patient.get_full_name(),
                    "status":              e.status,
                    "positions_ahead":     e.positions_ahead,
                    "estimated_wait_mins": e.estimated_wait_minutes,
                }
                for e in entries
            },
        }

    @staticmethod
    def _write(path: str, data: dict) -> None:
        """
        MOCK: logs what would be written to Firebase.
        Production replacement:
            import firebase_admin
            from firebase_admin import db as firebase_db
            ref = firebase_db.reference(path)
            ref.set(data)
        """
        logger.info("[Firebase MOCK] SET %s → %d entries", path, len(data.get("entries", {})))


# ---------------------------------------------------------------------------
# Core Queue Service
# ---------------------------------------------------------------------------

class QueueService:
    """All queue state mutations. Every method is @transaction.atomic."""

    # ------------------------------------------------------------------
    # FR-3.1  Auto-assign queue number on booking
    # ------------------------------------------------------------------

    @staticmethod
    @transaction.atomic
    def assign_queue_number(appointment) -> QueueEntry:
        """
        Called by the appointment booking signal (or directly from
        AppointmentService.book() after the appointment is saved).

        Creates the QueueSession for today if it doesn't exist,
        then creates a QueueEntry with the next available number.

        Uses SELECT FOR UPDATE on QueueSession to serialise concurrent
        bookings for the same doctor on the same day.
        """
        from base.models import Appointment  # local import avoids circular

        session, _ = QueueSession.objects.select_for_update().get_or_create(
            doctor=appointment.doctor,
            date=appointment.appointment_date,
            defaults={"status": QueueSessionStatus.ACTIVE, "next_number": 1},
        )

        queue_number   = session.next_number
        session.next_number += 1
        session.save(update_fields=["next_number", "updated_at"])

        entry = QueueEntry.objects.create(
            session      = session,
            patient      = appointment.patient,
            appointment  = appointment,
            queue_number = queue_number,
            status       = QueueEntryStatus.WAITING,
        )

        logger.info(
            "Queue #%d assigned to patient %s (Dr. %s, %s)",
            queue_number,
            appointment.patient.get_full_name(),
            appointment.doctor.get_full_name(),
            appointment.appointment_date,
        )

        # Push to Firebase
        FirebaseQueueSync.push_session(session)

        # Fire 2-away notification check for existing waiters
        QueueService._check_2away_notifications(session)

        return entry

    # ------------------------------------------------------------------
    # FR-3.5  Doctor calls next patient
    # ------------------------------------------------------------------

    @staticmethod
    @transaction.atomic
    def call_next(session: QueueSession, doctor: User) -> QueueEntry | None:
        """
        Doctor calls the next WAITING patient.
        Sets the called patient's status to CALLED and updates current_position.
        Returns the QueueEntry that was called, or None if queue is empty.
        """
        if session.is_paused:
            raise ValueError(
                "Queue is currently paused. Resume the queue before calling the next patient."
            )

        # Lock session row
        session = QueueSession.objects.select_for_update().get(pk=session.pk)

        next_entry = (
            QueueEntry.objects
            .select_for_update()
            .select_related("patient", "appointment")
            .filter(session=session, status=QueueEntryStatus.WAITING)
            .order_by("queue_number")
            .first()
        )

        if next_entry is None:
            logger.info("No waiting patients in session %d", session.pk)
            return None

        next_entry.status    = QueueEntryStatus.CALLED
        next_entry.called_at = timezone.now()
        next_entry.save(update_fields=["status", "called_at", "updated_at"])

        session.current_position = next_entry.queue_number
        session.save(update_fields=["current_position", "updated_at"])

        logger.info(
            "Called queue #%d (%s) in session %d",
            next_entry.queue_number,
            next_entry.patient.get_full_name(),
            session.pk,
        )

        # Notify called patient
        QueueNotificationService.on_called(next_entry)

        # Push full snapshot (all positions shift)
        FirebaseQueueSync.push_session(session)

        # Check who is now 2 away
        QueueService._check_2away_notifications(session)

        return next_entry

    # ------------------------------------------------------------------
    # FR-3.4  Advance queue after consultation complete
    # ------------------------------------------------------------------

    @staticmethod
    @transaction.atomic
    def mark_entry_complete(entry: QueueEntry, doctor: User) -> QueueEntry:
        """
        Doctor marks the current consultation as done.
        Transitions entry: CALLED / IN_CONSULT → COMPLETED.
        Automatically calls the next patient.
        Also marks the linked appointment as COMPLETED so queue and appointment
        state stay in sync.
        """
        if entry.status not in (QueueEntryStatus.CALLED, QueueEntryStatus.IN_CONSULT):
            raise ValueError(
                f"Cannot complete entry with status '{entry.status}'. "
                "Only CALLED or IN_CONSULT entries can be completed."
            )

        entry.status       = QueueEntryStatus.COMPLETED
        entry.completed_at = timezone.now()
        entry.save(update_fields=["status", "completed_at", "updated_at"])

        # Update avg_consultation_minutes on DoctorProfile
        WaitTimeService.update_avg_consultation(doctor, entry)

        if entry.appointment_id:
            appointment = entry.appointment
            if appointment.status == AppointmentStatus.CONFIRMED:
                AppointmentService.mark_status(
                    appointment=appointment,
                    new_status=AppointmentStatus.COMPLETED,
                    doctor=doctor,
                    notes=appointment.notes,
                )

        session = QueueSession.objects.select_for_update().get(pk=entry.session_id)
        FirebaseQueueSync.push_session(session)

        logger.info(
            "Queue entry #%d completed by Dr. %s",
            entry.queue_number, doctor.get_full_name(),
        )

        return entry

    # ------------------------------------------------------------------
    # FR-3.5  Doctor: pause / resume queue
    # ------------------------------------------------------------------

    @staticmethod
    @transaction.atomic
    def pause_queue(session: QueueSession, doctor: User, reason: str = "") -> QueueSession:
        """Pause the queue and log the event."""
        if session.is_paused:
            raise ValueError("Queue is already paused.")

        now = timezone.now()
        session.status     = QueueSessionStatus.PAUSED
        session.pause_reason = reason
        session.paused_at  = now
        session.save(update_fields=["status", "pause_reason", "paused_at", "updated_at"])

        QueuePauseLog.objects.create(
            session   = session,
            doctor    = doctor,
            paused_at = now,
            reason    = reason,
        )

        # Notify all waiting patients of the delay
        QueueNotificationService.on_queue_paused(session, reason)
        FirebaseQueueSync.push_session(session)

        logger.info("Queue session %d paused by Dr. %s. Reason: %s",
                    session.pk, doctor.get_full_name(), reason or "(none)")
        return session

    @staticmethod
    @transaction.atomic
    def resume_queue(session: QueueSession, doctor: User) -> QueueSession:
        """Resume a paused queue and update cumulative pause duration."""
        if not session.is_paused:
            raise ValueError("Queue is not paused.")

        now = timezone.now()

        # Close the open pause log
        open_log = (
            QueuePauseLog.objects
            .filter(session=session, resumed_at__isnull=True)
            .order_by("-paused_at")
            .first()
        )
        if open_log:
            open_log.resumed_at = now
            open_log.save(update_fields=["resumed_at"])
            if open_log.duration_minutes:
                session.total_pause_minutes += open_log.duration_minutes

        session.status      = QueueSessionStatus.ACTIVE
        session.pause_reason = ""
        session.paused_at   = None
        session.save(update_fields=[
            "status", "pause_reason", "paused_at",
            "total_pause_minutes", "updated_at"
        ])

        QueueNotificationService.on_queue_resumed(session)
        FirebaseQueueSync.push_session(session)

        logger.info("Queue session %d resumed by Dr. %s", session.pk, doctor.get_full_name())
        return session

    # ------------------------------------------------------------------
    # FR-3.6  Patient leaves queue voluntarily
    # ------------------------------------------------------------------

    @staticmethod
    @transaction.atomic
    def patient_leave_queue(entry: QueueEntry) -> QueueEntry:
        """
        Patient voluntarily leaves the queue.
        Only WAITING entries can be left (not already-called ones).
        Releases the appointment slot (mirrors cancellation logic).
        """
        if entry.status != QueueEntryStatus.WAITING:
            raise ValueError(
                f"Cannot leave queue from status '{entry.status}'. "
                "Only patients currently WAITING can leave the queue."
            )

        entry.status = QueueEntryStatus.LEFT
        entry.save(update_fields=["status", "updated_at"])

        # Also cancel the linked appointment so the slot is freed
        if entry.appointment_id:
            try:
                from appointments.services import AppointmentService
                from appointments.models import AppointmentStatus
                appt = entry.appointment
                if appt.status not in (
                    AppointmentStatus.CANCELLED,
                    AppointmentStatus.COMPLETED,
                    AppointmentStatus.RESCHEDULED,
                ):
                    AppointmentService.cancel(
                        appointment=appt,
                        by_user=entry.patient,
                        reason="Patient left the queue voluntarily.",
                    )
            except Exception as exc:
                logger.error(
                    "Failed to cancel appointment for queue leave (entry %d): %s",
                    entry.pk, exc
                )

        session = entry.session
        FirebaseQueueSync.push_session(session)

        logger.info(
            "Patient %s left queue session %d (entry #%d)",
            entry.patient.get_full_name(), session.pk, entry.queue_number,
        )
        return entry

    # ------------------------------------------------------------------
    # FR-3.5  Doctor: close queue for the day
    # ------------------------------------------------------------------

    @staticmethod
    @transaction.atomic
    def close_session(session: QueueSession, doctor: User) -> QueueSession:
        """Mark the session CLOSED at end of day."""
        session.status = QueueSessionStatus.CLOSED
        session.save(update_fields=["status", "updated_at"])
        FirebaseQueueSync.push_session(session)
        logger.info("Queue session %d closed by Dr. %s", session.pk, doctor.get_full_name())
        return session

    # ------------------------------------------------------------------
    # Helper: 2-positions-away notification  (FR-3.3)
    # ------------------------------------------------------------------

    @staticmethod
    def _check_2away_notifications(session: QueueSession) -> None:
        """
        Find patients who are now exactly 2 positions away from being called
        and haven't been notified yet. Fire their notification.
        """
        waiting = (
            QueueEntry.objects
            .filter(session=session, status=QueueEntryStatus.WAITING, notified_2away=False)
            .select_related("patient")
            .order_by("queue_number")
        )

        for entry in waiting:
            if entry.positions_ahead == 2:
                QueueNotificationService.on_2away(entry)
                entry.notified_2away = True
                entry.save(update_fields=["notified_2away"])

    # ------------------------------------------------------------------
    # Session / Entry lookup helpers
    # ------------------------------------------------------------------

    @staticmethod
    def get_or_create_session(doctor: User, date: datetime.date) -> QueueSession:
        session, _ = QueueSession.objects.get_or_create(
            doctor=doctor,
            date=date,
            defaults={"status": QueueSessionStatus.ACTIVE},
        )
        return session

    @staticmethod
    def get_patient_entry(patient: User, date: datetime.date) -> QueueEntry | None:
        """Return the patient's active queue entry for a given date, if any."""
        return (
            QueueEntry.objects
            .select_related("session", "session__doctor")
            .filter(
                patient=patient,
                session__date=date,
                status__in=[QueueEntryStatus.WAITING, QueueEntryStatus.CALLED,
                            QueueEntryStatus.IN_CONSULT],
            )
            .first()
        )


# ---------------------------------------------------------------------------
# Wait Time Service  (FR-3.8)
# ---------------------------------------------------------------------------

class WaitTimeService:
    """
    FR-3.8: estimated_wait = positions_ahead × avg_consultation_minutes
    Also handles nightly recalculation of avg_consultation_minutes per doctor.
    """

    @staticmethod
    def calculate(entry: QueueEntry) -> dict:
        """Return a dict with current wait estimate and position info."""
        return {
            "queue_number":        entry.queue_number,
            "positions_ahead":     entry.positions_ahead,
            "estimated_wait_mins": entry.estimated_wait_minutes,
            "avg_consult_mins":    entry.session.avg_consultation_minutes,
            "is_called":           entry.status == QueueEntryStatus.CALLED,
            "session_is_paused":   entry.session.is_paused,
            "pause_reason":        entry.session.pause_reason if entry.session.is_paused else "",
        }

    @staticmethod
    def update_avg_consultation(doctor: User, completed_entry: QueueEntry) -> None:
        """
        Recalculate avg_consultation_minutes for a doctor based on
        the last 30 completed entries.  Called after every consultation.
        """
        actual = completed_entry.actual_consultation_minutes
        if actual is None:
            return

        try:
            profile = doctor.doctor_profile
        except Exception:
            return

        # Rolling average over last 30 completed entries for this doctor
        recent = (
            QueueEntry.objects
            .filter(
                session__doctor=doctor,
                status=QueueEntryStatus.COMPLETED,
                called_at__isnull=False,
                completed_at__isnull=False,
            )
            .order_by("-completed_at")[:30]
        )

        durations = []
        for e in recent:
            d = e.actual_consultation_minutes
            if d:
                durations.append(d)

        if durations:
            new_avg = round(sum(durations) / len(durations))
            profile.avg_consultation_minutes = max(5, min(new_avg, 120))  # clamp 5–120
            profile.save(update_fields=["avg_consultation_minutes"])
            logger.info(
                "Updated avg_consultation_minutes for Dr. %s: %d min (from %d samples)",
                doctor.get_full_name(), new_avg, len(durations),
            )


# ---------------------------------------------------------------------------
# Queue Analytics Service  (FR-3.7)
# ---------------------------------------------------------------------------

class QueueAnalyticsService:
    """
    Admin dashboard statistics.
    All queries work on historical data in PostgreSQL.
    """

    @staticmethod
    def daily_stats(doctor: User, date: datetime.date) -> dict:
        """Per-doctor daily queue stats."""
        try:
            session = QueueSession.objects.prefetch_related("entries").get(
                doctor=doctor, date=date
            )
        except QueueSession.DoesNotExist:
            return {"error": "No queue session found for this doctor on this date."}

        entries = session.entries.all()

        completed  = entries.filter(status=QueueEntryStatus.COMPLETED)
        no_shows   = entries.filter(status=QueueEntryStatus.SKIPPED)
        left       = entries.filter(status=QueueEntryStatus.LEFT)
        waiting    = entries.filter(status__in=[QueueEntryStatus.WAITING, QueueEntryStatus.CALLED])

        # Avg actual consultation duration
        durations = [
            e.actual_consultation_minutes for e in completed
            if e.actual_consultation_minutes
        ]
        avg_actual = round(sum(durations) / len(durations)) if durations else None

        return {
            "doctor":                session.doctor.get_full_name(),
            "date":                  str(date),
            "session_status":        session.status,
            "total_in_queue":        entries.count(),
            "total_served":          completed.count(),
            "total_no_shows":        no_shows.count(),
            "total_left":            left.count(),
            "currently_waiting":     waiting.count(),
            "avg_actual_consult_min":avg_actual,
            "avg_configured_consult":session.avg_consultation_minutes,
            "total_pause_minutes":   session.total_pause_minutes,
            "pause_count":           session.pause_logs.count(),
            "current_position":      session.current_position,
        }

    @staticmethod
    def admin_overview(date: datetime.date) -> list[dict]:
        """
        FR-7.3: All active queues for admin live monitoring.
        Returns one row per doctor with an active session on the given date.
        """
        sessions = (
            QueueSession.objects
            .filter(date=date)
            .exclude(status=QueueSessionStatus.CLOSED)
            .select_related("doctor", "doctor__doctor_profile")
            .prefetch_related("entries")
            .order_by("doctor__first_name")
        )

        return [
            {
                "session_id":       s.pk,
                "doctor_id":        s.doctor_id,
                "doctor_name":      s.doctor.get_full_name(),
                "specialization":   getattr(s.doctor, "doctor_profile", None) and
                                    s.doctor.doctor_profile.specialization or "",
                "status":           s.status,
                "current_position": s.current_position,
                "waiting_count":    s.waiting_count,
                "served_count":     s.served_count,
                "is_paused":        s.is_paused,
                "pause_reason":     s.pause_reason,
                "total_pause_mins": s.total_pause_minutes,
                "avg_consult_mins": s.avg_consultation_minutes,
            }
            for s in sessions
        ]

    @staticmethod
    def aggregate_stats(
        from_date: datetime.date,
        to_date: datetime.date,
        doctor: User | None = None,
    ) -> dict:
        """
        FR-3.7: aggregate stats over a date range for export / reporting.
        """
        qs = QueueSession.objects.filter(date__range=(from_date, to_date))
        if doctor:
            qs = qs.filter(doctor=doctor)

        entry_qs = QueueEntry.objects.filter(session__in=qs)

        total_served   = entry_qs.filter(status=QueueEntryStatus.COMPLETED).count()
        total_no_shows = entry_qs.filter(status=QueueEntryStatus.SKIPPED).count()
        total_left     = entry_qs.filter(status=QueueEntryStatus.LEFT).count()
        total_patients = entry_qs.count()

        # Avg actual duration across all completed entries in range
        completed_with_times = entry_qs.filter(
            status=QueueEntryStatus.COMPLETED,
            called_at__isnull=False,
            completed_at__isnull=False,
        )
        durations = [
            e.actual_consultation_minutes for e in completed_with_times
            if e.actual_consultation_minutes
        ]
        avg_duration = round(sum(durations) / len(durations)) if durations else None

        no_show_rate = (
            round((total_no_shows / total_patients) * 100, 1)
            if total_patients else 0
        )

        return {
            "from_date":            str(from_date),
            "to_date":              str(to_date),
            "doctor":               doctor.get_full_name() if doctor else "All",
            "total_queue_entries":  total_patients,
            "total_served":         total_served,
            "total_no_shows":       total_no_shows,
            "total_left_queue":     total_left,
            "no_show_rate_pct":     no_show_rate,
            "avg_consultation_mins":avg_duration,
        }


# ---------------------------------------------------------------------------
# Notification stubs  (Module 6 replaces these)
# ---------------------------------------------------------------------------

class QueueNotificationService:
    """
    Dispatches in-app notifications for queue events and keeps log output for
    external channels (FCM/SMS/WhatsApp wired in Module 6).
    """

    @staticmethod
    def on_called(entry: QueueEntry) -> None:
        NotificationDispatcher.queue_called(entry)
        logger.info(
            "[QUEUE NOTIFY] Patient %s called (queue #%d).",
            entry.patient.get_full_name(), entry.queue_number,
        )

    @staticmethod
    def on_2away(entry: QueueEntry) -> None:
        NotificationDispatcher.queue_2away(entry)
        logger.info(
            "[QUEUE NOTIFY] Patient %s is 2 positions away (queue #%d).",
            entry.patient.get_full_name(), entry.queue_number,
        )

    @staticmethod
    def on_queue_paused(session: QueueSession, reason: str) -> None:
        NotificationDispatcher.queue_paused(session, reason)
        logger.info(
            "[QUEUE NOTIFY] Queue paused for Dr. %s — notifying all waiting patients. "
            "Reason: %s",
            session.doctor.get_full_name(), reason or "(none)",
        )

    @staticmethod
    def on_queue_resumed(session: QueueSession) -> None:
        NotificationDispatcher.queue_resumed(session)
        logger.info(
            "[QUEUE NOTIFY] Queue resumed for Dr. %s — notifying all waiting patients.",
            session.doctor.get_full_name(),
        )        
        
        

"""
emergency/services.py

Business logic for Module 5: Emergency SOS & Ambulance Request.

Services:
  EmergencyService         — create SOS, update status, cancel, history
  EmergencyNotificationService — alert admin/hospital + patient ACK (stubs → Module 6)
  EmergencyAnalyticsService    — FR-7.6 admin reporting
"""
# ---------------------------------------------------------------------------
# Emergency Service
# ---------------------------------------------------------------------------

class EmergencyService:

    # ------------------------------------------------------------------
    # FR-5.4  Create SOS request
    # ------------------------------------------------------------------

    @staticmethod
    @transaction.atomic
    def create_sos(
        patient: User,
        latitude: float | None,
        longitude: float | None,
        gps_accuracy: float | None = None,
        emergency_type: str = EmergencyType.MEDICAL,
        description: str = "",
    ) -> EmergencyRequest:
        """
        Called after the patient survives the 5-second countdown (FR-5.2).
        Creates the EmergencyRequest, fires admin alerts (FR-5.5),
        and sends the patient acknowledgement (FR-5.6).

        Idempotency guard: if the patient already has a PENDING or DISPATCHED
        request, return that one instead of creating a duplicate.
        """
        # Guard: prevent duplicate active SOS
        existing = EmergencyRequest.objects.filter(
            patient=patient,
            status__in=[EmergencyStatus.PENDING, EmergencyStatus.DISPATCHED],
        ).first()

        if existing:
            logger.warning(
                "Patient %s tried to create SOS but already has active request #%d",
                patient.username, existing.pk,
            )
            return existing

        request = EmergencyRequest.objects.create(
            patient         = patient,
            latitude        = latitude,
            longitude       = longitude,
            gps_accuracy_meters = gps_accuracy,
            emergency_type  = emergency_type,
            description     = description,
            status          = EmergencyStatus.PENDING,
            confirmed_at    = timezone.now(),
        )

        # Log initial status
        EmergencyStatusLog.objects.create(
            request         = request,
            previous_status = "",           # no prior state
            new_status      = EmergencyStatus.PENDING,
            changed_by      = patient,
            notes           = "Emergency SOS created by patient.",
        )

        logger.critical(
            "[SOS CREATED] Request #%d | Patient: %s | GPS: %s,%s | Type: %s",
            request.pk,
            patient.get_full_name(),
            latitude,
            longitude,
            emergency_type,
        )

        # FR-5.5: Notify admin / hospital immediately
        EmergencyNotificationService.alert_admin(request)

        # FR-5.6: Acknowledge patient
        EmergencyNotificationService.acknowledge_patient(request)

        return request

    # ------------------------------------------------------------------
    # FR-5.7  Update status (admin / doctor)
    # ------------------------------------------------------------------

    @staticmethod
    @transaction.atomic
    def update_status(
        request: EmergencyRequest,
        new_status: str,
        by_user: User,
        notes: str = "",
        ambulance_plate: str = "",
        ambulance_eta_minutes: int | None = None,
        resolution_notes: str = "",
    ) -> EmergencyRequest:
        """
        Admin / doctor updates the emergency request status.
        Guards transitions, logs the change, and notifies the patient.
        """
        old_status = request.status

        # Validate transition
        request.transition_status(new_status, by_user)

        # Ambulance details on dispatch
        if new_status == EmergencyStatus.DISPATCHED:
            if ambulance_plate:
                request.ambulance_plate = ambulance_plate
            if ambulance_eta_minutes is not None:
                request.ambulance_eta_minutes = ambulance_eta_minutes

        if resolution_notes:
            request.resolution_notes = resolution_notes

        request.save()

        # Immutable log entry
        EmergencyStatusLog.objects.create(
            request         = request,
            previous_status = old_status,
            new_status      = new_status,
            changed_by      = by_user,
            notes           = notes,
        )

        logger.info(
            "[SOS #%d] Status: %s → %s by %s",
            request.pk, old_status, new_status, by_user.username,
        )

        # Notify patient of status change (FR-5.6 real-time updates)
        EmergencyNotificationService.notify_patient_status_change(request, old_status)

        return request

    # ------------------------------------------------------------------
    # Patient cancels SOS (within the window)
    # ------------------------------------------------------------------

    @staticmethod
    @transaction.atomic
    def cancel_sos(request: EmergencyRequest, patient: User) -> EmergencyRequest:
        """
        Patient cancels their own SOS request.
        Only PENDING requests can be cancelled by the patient.
        """
        if request.patient != patient:
            raise PermissionError("You can only cancel your own emergency requests.")

        if request.status != EmergencyStatus.PENDING:
            raise ValueError(
                f"Cannot cancel a request with status '{request.status}'. "
                "Only pending requests can be cancelled."
            )

        old_status     = request.status
        request.status = EmergencyStatus.CANCELLED
        request.save(update_fields=["status", "updated_at"])

        EmergencyStatusLog.objects.create(
            request         = request,
            previous_status = old_status,
            new_status      = EmergencyStatus.CANCELLED,
            changed_by      = patient,
            notes           = "Cancelled by patient.",
        )

        logger.info("[SOS #%d] Cancelled by patient %s", request.pk, patient.username)

        # Notify admin that the SOS was cancelled
        EmergencyNotificationService.notify_sos_cancelled(request)

        return request

    # ------------------------------------------------------------------
    # FR-5.8  History helpers
    # ------------------------------------------------------------------

    @staticmethod
    def get_patient_history(patient: User) -> list:
        """All emergency requests for a patient, newest first."""
        return list(
            EmergencyRequest.objects
            .filter(patient=patient)
            .prefetch_related("status_logs")
            .order_by("-confirmed_at")
        )

    @staticmethod
    def get_active_request(patient: User) -> EmergencyRequest | None:
        """Return the patient's currently active (pending/dispatched) SOS, if any."""
        return EmergencyRequest.objects.filter(
            patient=patient,
            status__in=[EmergencyStatus.PENDING, EmergencyStatus.DISPATCHED],
        ).first()


# ---------------------------------------------------------------------------
# Notification Service  (stubs — Module 6 replaces these)
# ---------------------------------------------------------------------------

class EmergencyNotificationService:
    """
    Dispatches in-app notifications for emergency/SOS events and keeps log
    output for external channels (FCM/SMS/WhatsApp wired in Module 6).

    FR-5.5: admin/hospital alerted within 5 seconds.
    FR-5.6: patient receives acknowledgement.
    """

    @staticmethod
    def alert_admin(request: EmergencyRequest) -> None:
        """
        FR-5.5: Send immediate push + SMS to all active EmergencyContacts.
        EmergencyContacts are phone-number records (no user account), so in-app
        notifications only reach system admin users; external SMS/WhatsApp
        delivery is wired in Module 6.

        Production replacement:
            - FCM push to each contact's fcm_token
            - SMS via Arkesel/Hubtel to each contact's phone_number
            - WhatsApp via Business API to whatsapp_number if set
        """
        contacts = EmergencyContact.objects.filter(is_active=True)
        patient  = request.patient

        alert_message = (
            f"🚨 EMERGENCY SOS — {patient.get_full_name()} "
            f"(+{patient.phone_number})\n"
            f"Type: {request.get_emergency_type_display()}\n"
            f"Time: {request.confirmed_at:%Y-%m-%d %H:%M:%S}\n"
            f"GPS: {request.maps_url or 'No GPS data'}\n"
            f"Note: {request.description or 'No description'}"
        )

        # Notify in-app admin users (those with an account)
        from .models import UserRole
        admins = User.objects.filter(role=UserRole.ADMIN)
        for admin in admins:
            NotificationDispatcher._create(
                admin,
                NotificationType.EMERGENCY,
                "🚨 Emergency SOS",
                alert_message,
                action_url="/admin-home",
                metadata={"emergency_id": request.pk},
            )

        for contact in contacts:
            logger.critical(
                "[SOS ALERT] → %s (%s) | %s | %s",
                contact.name,
                contact.phone_number,
                contact.get_contact_type_display(),
                alert_message[:120],
            )

        # Mark admin as notified
        request.admin_notified = True
        request.save(update_fields=["admin_notified"])

        logger.critical(
            "[SOS #%d] Admin alert dispatched to %d contacts.", request.pk, contacts.count()
        )

    @staticmethod
    def acknowledge_patient(request: EmergencyRequest) -> None:
        """
        FR-5.6: Confirm receipt to patient.
        Push + SMS: 'Emergency request received. Help is on the way.'
        """
        NotificationDispatcher.emergency_acknowledged(request)

        patient = request.patient
        logger.info(
            "[SOS ACK] → Patient %s (%s): %s",
            patient.get_full_name(),
            patient.phone_number,
            "Emergency request received. Help is on the way.",
        )

        request.patient_ack_sent = True
        request.save(update_fields=["patient_ack_sent"])

    @staticmethod
    def notify_patient_status_change(
        request: EmergencyRequest,
        old_status: str,
    ) -> None:
        """
        FR-5.6: Real-time status update to patient.
        Fires on every PENDING → DISPATCHED → RESOLVED transition.
        """
        NotificationDispatcher.emergency_status_changed(request)

        messages = {
            EmergencyStatus.DISPATCHED: (
                f"🚑 Help is on the way! "
                f"{'Ambulance ' + request.ambulance_plate + ' has been dispatched. ' if request.ambulance_plate else ''}"
                f"{'ETA: ' + str(request.ambulance_eta_minutes) + ' minutes.' if request.ambulance_eta_minutes else ''}"
            ).strip(),
            EmergencyStatus.RESOLVED: (
                "✅ Your emergency request has been resolved. "
                "Please contact the hospital if you need further assistance."
            ),
            EmergencyStatus.FALSE_ALARM: (
                "Your emergency request has been closed as a false alarm. "
                "If you need help, please submit a new SOS."
            ),
            EmergencyStatus.CANCELLED: (
                "Your emergency request has been cancelled."
            ),
        }

        msg = messages.get(request.status, f"SOS status updated to: {request.status}")

        logger.info(
            "[SOS STATUS] → Patient %s: %s",
            request.patient.get_full_name(),
            msg,
        )

    @staticmethod
    def notify_sos_cancelled(request: EmergencyRequest) -> None:
        """In-app notification to the patient + notify admin contacts."""
        NotificationDispatcher.emergency_cancelled(request)

        contacts = EmergencyContact.objects.filter(is_active=True)
        logger.info(
            "[SOS CANCEL] SOS #%d cancelled by patient %s — notifying %d admin contacts.",
            request.pk,
            request.patient.get_full_name(),
            contacts.count(),
        )


# ---------------------------------------------------------------------------
# Analytics Service  (FR-7.6)
# ---------------------------------------------------------------------------

class EmergencyAnalyticsService:

    @staticmethod
    def admin_log(
        from_date=None,
        to_date=None,
        status: str | None = None,
        patient_id: int | None = None,
    ) -> list:
        """
        FR-7.6: Admin view of all emergency requests with full detail.
        Filterable by date range, status, and patient.
        """
        qs = EmergencyRequest.objects.select_related(
            "patient", "handled_by"
        ).prefetch_related("status_logs__changed_by").order_by("-confirmed_at")

        if from_date:
            qs = qs.filter(confirmed_at__date__gte=from_date)
        if to_date:
            qs = qs.filter(confirmed_at__date__lte=to_date)
        if status:
            qs = qs.filter(status=status)
        if patient_id:
            qs = qs.filter(patient_id=patient_id)

        return list(qs)

    @staticmethod
    def summary_stats(from_date=None, to_date=None) -> dict:
        """
        Aggregate statistics for the admin dashboard.
        """
        qs = EmergencyRequest.objects.all()
        if from_date:
            qs = qs.filter(confirmed_at__date__gte=from_date)
        if to_date:
            qs = qs.filter(confirmed_at__date__lte=to_date)

        total        = qs.count()
        pending      = qs.filter(status=EmergencyStatus.PENDING).count()
        dispatched   = qs.filter(status=EmergencyStatus.DISPATCHED).count()
        resolved     = qs.filter(status=EmergencyStatus.RESOLVED).count()
        cancelled    = qs.filter(status=EmergencyStatus.CANCELLED).count()
        false_alarms = qs.filter(status=EmergencyStatus.FALSE_ALARM).count()

        # Average response time (pending → dispatched)
        responded = qs.filter(
            response_time_seconds__isnull=False
        ).values_list("response_time_seconds", flat=True)

        avg_response = None
        if responded:
            avg_response = round(sum(responded) / len(responded))

        # Breakdown by type
        type_breakdown = {}
        for choice_val, _ in EmergencyRequest._meta.get_field("emergency_type").choices:
            type_breakdown[choice_val] = qs.filter(emergency_type=choice_val).count()

        return {
            "total":               total,
            "pending":             pending,
            "dispatched":          dispatched,
            "resolved":            resolved,
            "cancelled":           cancelled,
            "false_alarms":        false_alarms,
            "avg_response_seconds":avg_response,
            "type_breakdown":      type_breakdown,
        }        