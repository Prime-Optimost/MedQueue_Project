"""
queue/views.py

All API views for Module 3: Virtual Queuing System.

View map (FR traceability):
  PatientQueueStatusView       → FR-3.2  patient sees own position + wait time
  PatientLeaveQueueView        → FR-3.6  patient voluntarily leaves queue
  DoctorQueueView              → FR-3.5  doctor sees full day queue
  DoctorCallNextView           → FR-3.5  doctor calls next patient
  DoctorMarkCompleteView       → FR-3.4  doctor completes consultation (advances queue)
  DoctorPauseQueueView         → FR-3.5  pause queue
  DoctorResumeQueueView        → FR-3.5  resume queue
  DoctorCloseQueueView         → FR-3.5  close queue at end of day
  AdminQueueOverviewView       → FR-7.3  admin live monitor (all doctors)
  AdminDailyStatsView          → FR-3.7  per-doctor daily analytics
  AdminAggregateStatsView      → FR-3.7  date-range aggregate analytics
  AdminForceEntryStatusView    → FR-2.10 admin override entry status
"""

import datetime

from django.utils import timezone
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from ..models import User
from ..permissions import IsAdminUser, IsDoctor, IsPatient  # adjust to your app name

from ..models import QueueEntry, QueueEntryStatus, QueueSession, QueueSessionStatus
from ..serializers import (
    AdminQueueOverviewSerializer,
    AggregateStatsSerializer,
    DailyStatsSerializer,
    LeaveQueueSerializer,
    PauseQueueSerializer,
    QueueEntryPatientSerializer,
    QueueSessionDoctorSerializer,
)
from ..services import QueueAnalyticsService, QueueService, WaitTimeService


# ---------------------------------------------------------------------------
# Response helper
# ---------------------------------------------------------------------------

def api_response(data=None, message="", status_code=200, errors=None) -> Response:
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
# FR-3.2  Patient: view own queue position
# ---------------------------------------------------------------------------

class PatientQueueStatusView(APIView):
    """
    GET /queue/my-position/?date=YYYY-MM-DD

    Returns the authenticated patient's current queue position, number of
    patients ahead, and estimated wait time.  Flutter polls this every 5
    seconds (or subscribes to Firebase for true real-time).

    If no date is given, defaults to today.
    """
    permission_classes = [IsAuthenticated, IsPatient]

    def get(self, request):
        date_str = request.query_params.get("date", "").strip()
        if date_str:
            try:
                target_date = datetime.date.fromisoformat(date_str)
            except ValueError:
                return api_response(
                    message="Invalid date format. Use YYYY-MM-DD.",
                    errors={"date": "Invalid format."},
                    status_code=status.HTTP_400_BAD_REQUEST,
                )
        else:
            target_date = datetime.date.today()

        entry = QueueService.get_patient_entry(request.user, target_date)

        if entry is None:
            return api_response(
                message="You have no active queue entry for this date.",
                data={"in_queue": False, "date": str(target_date)},
            )

        wait_info = WaitTimeService.calculate(entry)
        serialized = QueueEntryPatientSerializer(entry).data

        return api_response(
            data={
                "in_queue":    True,
                "entry":       serialized,
                "wait_info":   wait_info,
                "firebase_path": f"queues/{entry.session.doctor_id}/{target_date}",
            },
            message="Queue position retrieved successfully.",
        )


# ---------------------------------------------------------------------------
# FR-3.6  Patient: leave queue voluntarily
# ---------------------------------------------------------------------------

class PatientLeaveQueueView(APIView):
    """
    POST /queue/leave/
    Body: {} (no fields required)

    Patient voluntarily exits the queue for today.
    Cancels the linked appointment and releases the time slot.
    Only works for WAITING entries (not already-called ones).
    """
    permission_classes = [IsAuthenticated, IsPatient]

    def post(self, request):
        target_date = datetime.date.today()
        entry = QueueService.get_patient_entry(request.user, target_date)

        if entry is None:
            return api_response(
                message="You are not in any active queue today.",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        try:
            QueueService.patient_leave_queue(entry)
        except ValueError as exc:
            return api_response(
                message=str(exc),
                errors={"entry": str(exc)},
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        return api_response(
            message=(
                "You have left the queue. Your appointment has been cancelled "
                "and the slot is now available for other patients."
            ),
        )


# ---------------------------------------------------------------------------
# FR-3.5  Doctor: view full queue
# ---------------------------------------------------------------------------

class DoctorQueueView(APIView):
    """
    GET /queue/doctor/?date=YYYY-MM-DD

    Doctor sees all patients in their queue for the day with position,
    status, visit reason, and call controls.
    Defaults to today if no date given.
    """
    permission_classes = [IsAuthenticated, IsDoctor]

    def get(self, request):
        date_str = request.query_params.get("date", "").strip()
        try:
            target_date = (
                datetime.date.fromisoformat(date_str) if date_str
                else datetime.date.today()
            )
        except ValueError:
            return api_response(
                message="Invalid date format.",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        session = QueueSession.objects.filter(
            doctor=request.user, date=target_date
        ).prefetch_related("entries__patient", "entries__appointment").first()

        if session is None:
            return api_response(
                message="No queue session found for this date.",
                data={"date": str(target_date), "has_session": False},
            )

        return api_response(
            data=QueueSessionDoctorSerializer(session).data,
            message="Queue retrieved successfully.",
        )


# ---------------------------------------------------------------------------
# FR-3.5  Doctor: call next patient
# ---------------------------------------------------------------------------

class DoctorCallNextView(APIView):
    """
    POST /queue/doctor/call-next/
    Body: {} (session inferred from today's queue for this doctor)

    Doctor calls the next WAITING patient.
    Sets their status to CALLED, increments current_position,
    notifies patient, and pushes updated snapshot to Firebase.
    """
    permission_classes = [IsAuthenticated, IsDoctor]

    def post(self, request):
        session = QueueSession.objects.filter(
            doctor=request.user,
            date=datetime.date.today(),
        ).first()

        if session is None:
            return api_response(
                message="No active queue session found for today.",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        try:
            called_entry = QueueService.call_next(session, request.user)
        except ValueError as exc:
            return api_response(
                message=str(exc),
                errors={"queue": str(exc)},
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        if called_entry is None:
            return api_response(
                message="No more patients waiting in the queue.",
                data={"queue_empty": True},
            )

        from ..serializers import QueueEntryDoctorSerializer
        return api_response(
            data={
                "called_entry": QueueEntryDoctorSerializer(called_entry).data,
                "remaining":    session.waiting_count,
            },
            message=(
                f"Queue #{called_entry.queue_number} — "
                f"{called_entry.patient.get_full_name()} has been called."
            ),
        )


# ---------------------------------------------------------------------------
# FR-3.4  Doctor: mark consultation complete (advances queue)
# ---------------------------------------------------------------------------

class DoctorMarkCompleteView(APIView):
    """
    POST /queue/doctor/entries/<entry_id>/complete/
    Body: {} (notes go via the Appointment endpoint)

    Doctor marks the current consultation as done.
    Transitions entry CALLED → COMPLETED.
    Triggers Firebase push so all waiting patients see updated positions.
    """
    permission_classes = [IsAuthenticated, IsDoctor]

    def post(self, request, entry_id: int):
        try:
            entry = QueueEntry.objects.select_related(
                "session", "session__doctor", "patient", "appointment"
            ).get(pk=entry_id, session__doctor=request.user)
        except QueueEntry.DoesNotExist:
            return api_response(
                message="Queue entry not found.",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        try:
            entry = QueueService.mark_entry_complete(entry, request.user)
        except ValueError as exc:
            return api_response(
                message=str(exc),
                errors={"entry": str(exc)},
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        session = QueueSession.objects.get(pk=entry.session_id)
        return api_response(
            data={
                "completed_entry_id":  entry.pk,
                "completed_queue_no":  entry.queue_number,
                "remaining_waiting":   session.waiting_count,
                "total_served_today":  session.served_count,
            },
            message=(
                f"Consultation for queue #{entry.queue_number} "
                f"({entry.patient.get_full_name()}) marked complete."
            ),
        )


# ---------------------------------------------------------------------------
# FR-3.5  Doctor: pause queue
# ---------------------------------------------------------------------------

class DoctorPauseQueueView(APIView):
    """
    POST /queue/doctor/pause/
    Body: {pause_reason: "Emergency break"}

    Pauses the queue. All waiting patients are notified of the delay.
    """
    permission_classes = [IsAuthenticated, IsDoctor]

    def post(self, request):
        session = QueueSession.objects.filter(
            doctor=request.user, date=datetime.date.today()
        ).first()

        if session is None:
            return api_response(
                message="No active queue session found for today.",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        serializer = PauseQueueSerializer(data=request.data)
        if not serializer.is_valid():
            return api_response(
                message="Invalid request.",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        try:
            session = QueueService.pause_queue(
                session=session,
                doctor=request.user,
                reason=serializer.validated_data["pause_reason"],
            )
        except ValueError as exc:
            return api_response(
                message=str(exc),
                errors={"queue": str(exc)},
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        return api_response(
            data={"session_status": session.status, "pause_reason": session.pause_reason},
            message="Queue paused. Waiting patients have been notified.",
        )


# ---------------------------------------------------------------------------
# FR-3.5  Doctor: resume queue
# ---------------------------------------------------------------------------

class DoctorResumeQueueView(APIView):
    """
    POST /queue/doctor/resume/
    Body: {} (no fields)
    """
    permission_classes = [IsAuthenticated, IsDoctor]

    def post(self, request):
        session = QueueSession.objects.filter(
            doctor=request.user, date=datetime.date.today()
        ).first()

        if session is None:
            return api_response(
                message="No queue session found for today.",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        try:
            session = QueueService.resume_queue(session, request.user)
        except ValueError as exc:
            return api_response(
                message=str(exc),
                errors={"queue": str(exc)},
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        return api_response(
            data={
                "session_status":  session.status,
                "waiting_count":   session.waiting_count,
                "current_position":session.current_position,
            },
            message="Queue resumed. Patients have been notified.",
        )


# ---------------------------------------------------------------------------
# FR-3.5  Doctor: close queue for the day
# ---------------------------------------------------------------------------

class DoctorCloseQueueView(APIView):
    """
    POST /queue/doctor/close/
    Closes the queue session for today. Cannot be undone.
    """
    permission_classes = [IsAuthenticated, IsDoctor]

    def post(self, request):
        session = QueueSession.objects.filter(
            doctor=request.user, date=datetime.date.today()
        ).first()

        if session is None:
            return api_response(
                message="No queue session found for today.",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        if session.status == QueueSessionStatus.CLOSED:
            return api_response(
                message="Queue session is already closed.",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        session = QueueService.close_session(session, request.user)
        return api_response(
            data={
                "session_status": session.status,
                "total_served":   session.served_count,
                "waiting_at_close": session.waiting_count,
            },
            message="Queue closed for today.",
        )


# ---------------------------------------------------------------------------
# FR-7.3  Admin: live queue overview (all doctors)
# ---------------------------------------------------------------------------

class AdminQueueOverviewView(APIView):
    """
    GET /queue/admin/overview/?date=YYYY-MM-DD

    Returns all active doctor queues for a given date.
    Defaults to today. Used for the admin live monitoring dashboard.
    """
    permission_classes = [IsAuthenticated, IsAdminUser]

    def get(self, request):
        date_str = request.query_params.get("date", "").strip()
        try:
            target_date = (
                datetime.date.fromisoformat(date_str) if date_str
                else datetime.date.today()
            )
        except ValueError:
            return api_response(
                message="Invalid date format.",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        overview = QueueAnalyticsService.admin_overview(target_date)
        return api_response(
            data={
                "date":     str(target_date),
                "count":    len(overview),
                "queues":   AdminQueueOverviewSerializer(overview, many=True).data,
            },
            message=f"Live queue overview for {target_date} retrieved.",
        )


# ---------------------------------------------------------------------------
# FR-3.7  Admin: daily stats for one doctor
# ---------------------------------------------------------------------------

class AdminDailyStatsView(APIView):
    """
    GET /queue/admin/stats/daily/?doctor_id=4&date=YYYY-MM-DD
    """
    permission_classes = [IsAuthenticated, IsAdminUser]

    def get(self, request):
        doctor_id = request.query_params.get("doctor_id", "").strip()
        date_str  = request.query_params.get("date", "").strip()

        if not doctor_id:
            return api_response(
                message="doctor_id is required.",
                errors={"doctor_id": "Required."},
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        try:
            doctor = User.objects.get(pk=doctor_id, role="doctor")
        except User.DoesNotExist:
            return api_response(
                message="Doctor not found.",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        try:
            target_date = (
                datetime.date.fromisoformat(date_str) if date_str
                else datetime.date.today()
            )
        except ValueError:
            return api_response(
                message="Invalid date format.",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        stats = QueueAnalyticsService.daily_stats(doctor, target_date)

        if "error" in stats:
            return api_response(
                message=stats["error"],
                status_code=status.HTTP_404_NOT_FOUND,
            )

        return api_response(
            data=DailyStatsSerializer(stats).data,
            message="Daily queue statistics retrieved.",
        )


# ---------------------------------------------------------------------------
# FR-3.7  Admin: aggregate stats (date range)
# ---------------------------------------------------------------------------

class AdminAggregateStatsView(APIView):
    """
    GET /queue/admin/stats/aggregate/?from=YYYY-MM-DD&to=YYYY-MM-DD&doctor_id=4

    doctor_id is optional — omit for all doctors.
    """
    permission_classes = [IsAuthenticated, IsAdminUser]

    def get(self, request):
        from_str  = request.query_params.get("from", "").strip()
        to_str    = request.query_params.get("to",   "").strip()
        doctor_id = request.query_params.get("doctor_id", "").strip()

        if not from_str or not to_str:
            return api_response(
                message="Both 'from' and 'to' date parameters are required.",
                errors={"from": "Required.", "to": "Required."},
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        try:
            from_date = datetime.date.fromisoformat(from_str)
            to_date   = datetime.date.fromisoformat(to_str)
        except ValueError:
            return api_response(
                message="Invalid date format. Use YYYY-MM-DD.",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        if from_date > to_date:
            return api_response(
                message="'from' date must be before or equal to 'to' date.",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        doctor = None
        if doctor_id:
            try:
                doctor = User.objects.get(pk=doctor_id, role="doctor")
            except User.DoesNotExist:
                return api_response(
                    message="Doctor not found.",
                    status_code=status.HTTP_404_NOT_FOUND,
                )

        stats = QueueAnalyticsService.aggregate_stats(from_date, to_date, doctor)
        return api_response(
            data=AggregateStatsSerializer(stats).data,
            message="Aggregate queue statistics retrieved.",
        )


# ---------------------------------------------------------------------------
# Admin: force entry status update  (FR-2.10 / admin override)
# ---------------------------------------------------------------------------

class AdminForceEntryStatusView(APIView):
    """
    PATCH /queue/admin/entries/<entry_id>/
    Body: {new_status: "skipped"|"completed"|"left"|...}

    Admin can force-update any entry status (e.g., mark a ghost patient
    as skipped to unblock the queue).
    """
    permission_classes = [IsAuthenticated, IsAdminUser]

    ALLOWED_STATUSES = [
        QueueEntryStatus.COMPLETED,
        QueueEntryStatus.SKIPPED,
        QueueEntryStatus.LEFT,
    ]

    def patch(self, request, entry_id: int):
        try:
            entry = QueueEntry.objects.select_related(
                "session", "patient"
            ).get(pk=entry_id)
        except QueueEntry.DoesNotExist:
            return api_response(
                message="Queue entry not found.",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        new_status = request.data.get("new_status", "").strip()
        if new_status not in self.ALLOWED_STATUSES:
            return api_response(
                message=f"Invalid status. Allowed: {self.ALLOWED_STATUSES}",
                errors={"new_status": "Invalid value."},
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        from django.utils import timezone as tz
        entry.status = new_status
        if new_status == QueueEntryStatus.COMPLETED and not entry.completed_at:
            entry.completed_at = tz.now()
        entry.save()
        # Push updated session snapshot
        from ..services import FirebaseQueueSync
        FirebaseQueueSync.push_session(entry.session)

        from ..serializers import QueueEntryDoctorSerializer
        return api_response(
            data=QueueEntryDoctorSerializer(entry).data,
            message=f"Entry #{entry.queue_number} status forced to '{new_status}' by admin.",
        )