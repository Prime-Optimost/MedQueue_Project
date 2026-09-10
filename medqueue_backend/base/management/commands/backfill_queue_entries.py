"""
Management command to backfill queue entries for existing confirmed appointments.
Useful after fixing import errors or deploying queue system.
"""

from django.core.management.base import BaseCommand
from django.db import transaction

from base.models import Appointment, AppointmentStatus, QueueEntry
from base.services import QueueService


class Command(BaseCommand):
    help = "Backfill queue entries for existing confirmed appointments"

    def handle(self, *args, **options):
        """Create queue entries for confirmed appointments that don't have them."""
        
        # Get all confirmed appointments without queue entries
        confirmed_apts = Appointment.objects.filter(
            status=AppointmentStatus.CONFIRMED
        ).exclude(
            queue_entry__isnull=False
        )
        
        count = confirmed_apts.count()
        self.stdout.write(f"Found {count} confirmed appointments without queue entries")
        
        if count == 0:
            self.stdout.write(self.style.SUCCESS("No backfill needed!"))
            return
        
        created = 0
        failed = 0
        
        for apt in confirmed_apts:
            try:
                with transaction.atomic():
                    entry = QueueService.assign_queue_number(apt)
                    created += 1
                    self.stdout.write(
                        f"✓ Appointment #{apt.id} → Queue #{entry.queue_number}"
                    )
            except Exception as e:
                failed += 1
                self.stdout.write(
                    self.style.ERROR(
                        f"✗ Appointment #{apt.id} failed: {str(e)}"
                    )
                )
        
        self.stdout.write(
            self.style.SUCCESS(
                f"\nBackfill complete: {created} created, {failed} failed"
            )
        )
        
        # Show final counts
        total_entries = QueueEntry.objects.count()
        self.stdout.write(f"Total queue entries now: {total_entries}")
