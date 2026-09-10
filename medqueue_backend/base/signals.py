"""
queue/signals.py

Django signals that wire Module 2 (Appointments) → Module 3 (Queue).

On every appointment save where status transitions to CONFIRMED,
QueueService.assign_queue_number() is called automatically.

Register in queue/apps.py → ready().
"""

import logging

from django.db.models.signals import post_save
from django.dispatch import receiver

logger = logging.getLogger(__name__)


def register_signals():
    """
    Called from BaseConfig.ready() to avoid circular imports.
    Importing Appointment inside the function keeps the import lazy.
    """

    try:
        from base.models import Appointment, AppointmentStatus
        from .services import QueueService

        @receiver(post_save, sender=Appointment)
        def auto_assign_queue_on_confirmation(sender, instance: Appointment, created: bool, **kwargs):
            """
            Fires whenever an Appointment is saved.
            We only act when:
              1. The appointment is CONFIRMED (status = "confirmed")
              2. There is no QueueEntry already linked to it
                 (prevents duplicate assignment on subsequent saves)
            """
            if instance.status != AppointmentStatus.CONFIRMED:
                return

            # Avoid circular import at module level
            from .models import QueueEntry

            already_assigned = QueueEntry.objects.filter(appointment=instance).exists()
            if already_assigned:
                return

            try:
                entry = QueueService.assign_queue_number(instance)
                logger.info(
                    "[Signal] Queue #%d auto-assigned for Appointment #%d (patient=%s, doctor=%s, date=%s)",
                    entry.queue_number,
                    instance.pk,
                    instance.patient.get_full_name(),
                    instance.doctor.get_full_name(),
                    instance.appointment_date,
                )
            except Exception as exc:
                # Signal failures must never crash the appointment save
                logger.error(
                    "[Signal] Failed to assign queue for Appointment #%d: %s",
                    instance.pk, exc,
                )

    except ImportError as exc:
        # Appointments app not installed yet (e.g. during first migration)
        logger.warning("[Queue signals] Could not import Appointment model: %s", exc)