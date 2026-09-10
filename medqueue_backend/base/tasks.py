"""
appointments/tasks.py

Celery async / periodic tasks for the Appointments module.

Tasks:
  send_appointment_reminders     — 24h and 30-min reminder notifications (FR-6.2)
  generate_daily_slots           — nightly pre-generation of slots for next 30 days
  handle_no_show_followup        — auto no-show alert after appointment window passes

To register the periodic tasks add to settings.py:

  from celery.schedules import crontab

  CELERY_BEAT_SCHEDULE = {
      "appointment-reminders": {
          "task":     "appointments.tasks.send_appointment_reminders",
          "schedule": crontab(minute="*/5"),   # every 5 minutes
      },
      "generate-daily-slots": {
          "task":     "appointments.tasks.generate_daily_slots",
          "schedule": crontab(hour=0, minute=0),  # midnight
      },
      "no-show-followup": {
          "task":     "appointments.tasks.handle_no_show_followup",
          "schedule": crontab(minute="*/10"),
      },
  }
"""

import datetime
import logging

from celery import shared_task
from django.utils import timezone

logger = logging.getLogger(__name__)



@shared_task(bind=True, max_retries=3, default_retry_delay=60)
def send_appointment_reminders(self):
    """
    FR-6.2: Send 24-hour and 30-minute appointment reminders.
    Scans upcoming confirmed appointments and fires notifications
    if the reminder hasn't been sent yet.
    """
    from .models import Appointment, AppointmentStatus
    from .services import NotificationDispatcher

    now  = timezone.now()

    # -- 24-hour reminders --
    window_24h_start = now + datetime.timedelta(hours=23, minutes=50)
    window_24h_end   = now + datetime.timedelta(hours=24, minutes=10)

    appts_24h = Appointment.objects.filter(
        status=AppointmentStatus.CONFIRMED,
        reminder_24h_sent=False,
    ).select_related("patient", "doctor")

    for appt in appts_24h:
        appt_dt = timezone.make_aware(
            datetime.datetime.combine(appt.appointment_date, appt.appointment_time)
        )
        if window_24h_start <= appt_dt <= window_24h_end:
            try:
                NotificationDispatcher.appointment_reminder(appt, hours_before=24)
                appt.reminder_24h_sent = True
                appt.save(update_fields=["reminder_24h_sent"])
                logger.info("24h reminder sent for Appointment #%d", appt.pk)
            except Exception as exc:
                logger.error("Failed 24h reminder for Appointment #%d: %s", appt.pk, exc)

    # -- 30-minute reminders --
    window_30m_start = now + datetime.timedelta(minutes=25)
    window_30m_end   = now + datetime.timedelta(minutes=35)

    appts_30m = Appointment.objects.filter(
        status=AppointmentStatus.CONFIRMED,
        reminder_30m_sent=False,
    ).select_related("patient", "doctor")

    for appt in appts_30m:
        appt_dt = timezone.make_aware(
            datetime.datetime.combine(appt.appointment_date, appt.appointment_time)
        )
        if window_30m_start <= appt_dt <= window_30m_end:
            try:
                NotificationDispatcher.appointment_reminder(appt, hours_before=0)  # "in 30 minutes"
                appt.reminder_30m_sent = True
                appt.save(update_fields=["reminder_30m_sent"])
                logger.info("30m reminder sent for Appointment #%d", appt.pk)
            except Exception as exc:
                logger.error("Failed 30m reminder for Appointment #%d: %s", appt.pk, exc)


@shared_task(bind=True, max_retries=3)
def generate_daily_slots(self):
    """
    Nightly task: pre-generate slots for all doctors for the next 30 days.
    Idempotent — safe to re-run.
    """
    from base.models import User
    from .services import SlotService

    doctors     = User.objects.filter(role="doctor", is_active=True)
    today       = datetime.date.today()
    total_created = 0

    for doctor in doctors:
        for days_ahead in range(1, 31):   # next 30 days
            target_date = today + datetime.timedelta(days=days_ahead)
            created = SlotService.generate_slots_for_date(doctor, target_date)
            total_created += created

    logger.info("Nightly slot generation: %d new slots created.", total_created)
    return total_created


@shared_task(bind=True, max_retries=3)
def handle_no_show_followup(self):
    """
    FR-2.9: Auto-detect missed appointments and mark them NO_SHOW
    if the doctor hasn't manually updated the status within 1 hour
    of the appointment time.
    """
    from .models import Appointment, AppointmentStatus
    from .services import AppointmentService, AppointmentNotificationService

    now      = timezone.now()
    one_hour_ago = now - datetime.timedelta(hours=1)

    # Find confirmed appointments whose time passed over 1 hour ago
    missed = Appointment.objects.filter(
        status=AppointmentStatus.CONFIRMED,
    ).select_related("patient", "doctor")

    for appt in missed:
        appt_dt = timezone.make_aware(
            datetime.datetime.combine(appt.appointment_date, appt.appointment_time)
        )
        if appt_dt < one_hour_ago:
            try:
                appt.transition_status(AppointmentStatus.NO_SHOW)
                appt.save()
                AppointmentNotificationService.on_no_show(appt)
                logger.info("Auto no-show: Appointment #%d", appt.pk)
            except Exception as exc:
                logger.error("Failed auto no-show for Appointment #%d: %s", appt.pk, exc)
                
                
"""
queue/tasks.py

Celery periodic tasks for Module 3: Virtual Queuing System.

Tasks:
  broadcast_queue_positions    — push Firebase snapshot every 5 s (FR-3.2)
  check_2away_notifications    — scan for patients now 2 positions away (FR-3.3)
  update_avg_consultation_times— nightly recalc of avg consultation mins (FR-3.8)
  auto_close_stale_sessions    — close sessions with no activity after 8 PM

Celery beat schedule (add to settings.py):

  CELERY_BEAT_SCHEDULE = {
      "queue-broadcast": {
          "task":     "queue.tasks.broadcast_queue_positions",
          "schedule": 5,                               # every 5 seconds
      },
      "queue-2away-check": {
          "task":     "queue.tasks.check_2away_notifications",
          "schedule": crontab(minute="*/1"),           # every minute
      },
      "queue-avg-update": {
          "task":     "queue.tasks.update_avg_consultation_times",
          "schedule": crontab(hour=1, minute=0),       # 01:00 nightly
      },
      "queue-auto-close": {
          "task":     "queue.tasks.auto_close_stale_sessions",
          "schedule": crontab(hour=20, minute=0),      # 20:00 daily
      },
  }
"""



@shared_task(bind=True, max_retries=2)
def broadcast_queue_positions(self):
    """
    FR-3.2: Push Firebase snapshots for all active queue sessions.
    Runs every 5 seconds via Celery Beat.

    In production, Flutter clients subscribe directly to Firebase paths
    and receive updates within milliseconds of the DB write. This task
    is a safety net for any missed pushes (network blip, restart, etc.).
    """
    from .models import QueueSession, QueueSessionStatus
    from .services import FirebaseQueueSync

    active_sessions = QueueSession.objects.filter(
        date=datetime.date.today(),
        status__in=[QueueSessionStatus.ACTIVE, QueueSessionStatus.PAUSED],
    ).select_related("doctor")

    pushed = 0
    for session in active_sessions:
        try:
            FirebaseQueueSync.push_session(session)
            pushed += 1
        except Exception as exc:
            logger.error("[broadcast] Failed for session %d: %s", session.pk, exc)

    logger.debug("[broadcast] Pushed %d active sessions.", pushed)
    return pushed


@shared_task(bind=True, max_retries=3)
def check_2away_notifications(self):
    """
    FR-3.3: Scan all waiting patients across active queues.
    Fire a 'get ready' push notification to anyone who is now exactly 2 positions away.
    """
    from .models import QueueEntry, QueueEntryStatus, QueueSession, QueueSessionStatus
    from .services import QueueNotificationService

    active_sessions = QueueSession.objects.filter(
        date=datetime.date.today(),
        status=QueueSessionStatus.ACTIVE,
    )

    notified_count = 0
    for session in active_sessions:
        waiting = QueueEntry.objects.filter(
            session=session,
            status=QueueEntryStatus.WAITING,
            notified_2away=False,
        ).select_related("patient")

        for entry in waiting:
            if entry.positions_ahead == 2:
                try:
                    QueueNotificationService.on_2away(entry)
                    entry.notified_2away = True
                    entry.save(update_fields=["notified_2away"])
                    notified_count += 1
                except Exception as exc:
                    logger.error(
                        "[2away] Failed to notify entry %d: %s", entry.pk, exc
                    )

    logger.info("[2away] Notified %d patients.", notified_count)
    return notified_count


@shared_task(bind=True, max_retries=2)
def update_avg_consultation_times(self):
    """
    FR-3.8: Nightly recalculation of avg_consultation_minutes for all doctors.
    Averages actual consultation durations from the last 30 completed entries.
    """
    from base.models import User
    from .models import QueueEntry, QueueEntryStatus

    doctors = User.objects.filter(role="doctor", is_active=True).select_related("doctor_profile")
    updated = 0

    for doctor in doctors:
        try:
            profile = doctor.doctor_profile
        except Exception:
            continue

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

        durations = [
            e.actual_consultation_minutes for e in recent
            if e.actual_consultation_minutes
        ]
        if not durations:
            continue

        new_avg = round(sum(durations) / len(durations))
        new_avg = max(5, min(new_avg, 120))

        if profile.avg_consultation_minutes != new_avg:
            profile.avg_consultation_minutes = new_avg
            profile.save(update_fields=["avg_consultation_minutes"])
            updated += 1
            logger.info(
                "[avg-update] Dr. %s → %d min avg (from %d samples)",
                doctor.get_full_name(), new_avg, len(durations),
            )

    logger.info("[avg-update] Updated %d doctors.", updated)
    return updated


@shared_task(bind=True, max_retries=2)
def auto_close_stale_sessions(self):
    """
    Automatically close queue sessions that are still ACTIVE or PAUSED at 8 PM.
    Prevents orphan sessions from blocking the next day.
    """
    from .models import QueueSession, QueueSessionStatus
    from .services import FirebaseQueueSync

    today    = datetime.date.today()
    stale    = QueueSession.objects.filter(
        date=today,
        status__in=[QueueSessionStatus.ACTIVE, QueueSessionStatus.PAUSED],
    )

    closed = 0
    for session in stale:
        session.status = QueueSessionStatus.CLOSED
        session.save(update_fields=["status", "updated_at"])
        FirebaseQueueSync.push_session(session)
        closed += 1
        logger.info("[auto-close] Session %d closed (end of day).", session.pk)

    return closed       




"""
emergency/tasks.py

Celery periodic tasks for Module 5: Emergency SOS & Ambulance Request.

Tasks:
  escalate_stale_sos       — re-alert admin if a PENDING SOS has been ignored > 3 min
  remind_dispatched_sos    — remind admin to resolve dispatched SOS after 60 min
  cleanup_old_sos_records  — archive resolved records older than 90 days (GDPR-style)

Celery beat schedule (add to settings.py):

  CELERY_BEAT_SCHEDULE = {
      "sos-escalate": {
          "task":     "emergency.tasks.escalate_stale_sos",
          "schedule": crontab(minute="*/3"),     # every 3 minutes
      },
      "sos-dispatched-remind": {
          "task":     "emergency.tasks.remind_dispatched_sos",
          "schedule": crontab(minute="*/15"),    # every 15 minutes
      },
  }
"""


@shared_task(bind=True, max_retries=3, default_retry_delay=30)
def escalate_stale_sos(self):
    """
    FR-5.5: Re-send admin alert if a PENDING SOS has not been acknowledged
    within 3 minutes of creation. Prevents silent drops in high-traffic periods.
    """
    from .models import EmergencyRequest, EmergencyStatus
    from .services import EmergencyNotificationService

    threshold = timezone.now() - datetime.timedelta(minutes=3)

    stale = EmergencyRequest.objects.filter(
        status=EmergencyStatus.PENDING,
        confirmed_at__lte=threshold,
    ).select_related("patient")

    escalated = 0
    for request in stale:
        try:
            logger.critical(
                "[SOS ESCALATION] Request #%d has been PENDING for > 3 min. "
                "Patient: %s. GPS: %s",
                request.pk,
                request.patient.get_full_name(),
                request.maps_url or "No GPS",
            )
            # Re-fire the admin alert with an ESCALATION flag
            EmergencyNotificationService.alert_admin(request)
            escalated += 1
        except Exception as exc:
            logger.error("[SOS ESCALATION] Failed for #%d: %s", request.pk, exc)

    if escalated:
        logger.critical("[SOS ESCALATION] Re-alerted admin for %d stale SOS.", escalated)
    return escalated


@shared_task(bind=True, max_retries=2)
def remind_dispatched_sos(self):
    """
    If an ambulance has been dispatched but the SOS hasn't been resolved
    after 60 minutes, send a reminder to admin to update the status.
    Prevents orphaned DISPATCHED records from cluttering the dashboard.
    """
    from .models import EmergencyRequest, EmergencyStatus

    threshold = timezone.now() - datetime.timedelta(minutes=60)

    overdue = EmergencyRequest.objects.filter(
        status=EmergencyStatus.DISPATCHED,
        dispatched_at__lte=threshold,
    ).select_related("patient", "handled_by")

    for request in overdue:
        logger.warning(
            "[SOS OVERDUE] Request #%d has been DISPATCHED for > 60 min. "
            "Patient: %s. Handled by: %s. Please update the status.",
            request.pk,
            request.patient.get_full_name(),
            request.handled_by.get_full_name() if request.handled_by else "Unassigned",
        )
        # Module 6 will send a real push/SMS here

    return overdue.count()         