"""
appointments/views.py

All API views for Module 2: Appointment Booking & Management.

View map (FR traceability):
  DoctorListView              → FR-2.1  browse doctors
  DoctorSlotListView          → FR-2.2  real-time slot availability
  BookAppointmentView         → FR-2.3  book appointment
  AppointmentDetailView       → FR-2.3  confirm + view detail
  CancelAppointmentView       → FR-2.5  cancel
  RescheduleAppointmentView   → FR-2.6  reschedule
  DoctorScheduleView          → FR-2.7  doctor's own schedule
  DoctorMarkStatusView        → FR-2.7  complete / no-show
  AppointmentHistoryView      → FR-2.8  full history
  AdminScheduleView           → FR-7.2  admin creates/edits DoctorSchedule
  AdminAppointmentOverrideView→ FR-2.10 admin override

All views return the standard envelope:
  {status, message, data, errors}
"""

import datetime

from django.db.models import Q
from django.utils import timezone
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from ..permissions import IsAdminUser, IsDoctor, IsPatient  # ← adjust

from ..models import (
    User,
    Appointment,
    AppointmentStatus,
    DoctorAvailabilityOverride,
    DoctorSchedule,
    SlotStatus,
    TimeSlot,
)
from ..serializers import (
    AdminAppointmentOverrideSerializer,
    AppointmentListSerializer,
    AppointmentSerializer,
    BookAppointmentSerializer,
    CancelAppointmentSerializer,
    DoctorAvailabilityOverrideSerializer,
    DoctorProfileBriefSerializer,
    DoctorScheduleSerializer,
    DoctorStatusUpdateSerializer,
    RescheduleSerializer,
    TimeSlotSerializer,
)
from ..services import AppointmentService, SlotService


# ---------------------------------------------------------------------------
# Response helper  (mirrors accounts/views.py envelope)
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
# FR-2.1  Browse Doctors
# ---------------------------------------------------------------------------

class DoctorListView(APIView):
    """
    GET /appointments/doctors/
    Query params:
      ?specialization=Cardiology
      ?hospital=UENR
      ?date=2026-06-10          (only doctors with available slots on that date)
      ?search=dr. kwame
    """
    permission_classes = [IsAuthenticated, IsPatient]

    def get(self, request):
        qs = User.objects.filter(
            role="doctor",
            is_active=True,
        ).select_related("doctor_profile").order_by("first_name")

        # Filter by specialization
        spec = request.query_params.get("specialization", "").strip()
        if spec:
            qs = qs.filter(doctor_profile__specialization__icontains=spec)

        # Filter by hospital
        hospital = request.query_params.get("hospital", "").strip()
        if hospital:
            qs = qs.filter(doctor_profile__hospital_name__icontains=hospital)

        # Filter by accepting patients
        qs = qs.filter(doctor_profile__is_accepting_patients=True)

        # Filter by date availability (has schedule for that day of week)
        date_str = request.query_params.get("date", "").strip()
        if date_str:
            try:
                requested_date = datetime.date.fromisoformat(date_str)
                day_of_week    = requested_date.weekday()
                qs = qs.filter(
                    schedules__day_of_week=day_of_week,
                    schedules__is_active=True,
                )
            except ValueError:
                return api_response(
                    message="Invalid date format. Use YYYY-MM-DD.",
                    errors={"date": "Invalid format."},
                    status_code=status.HTTP_400_BAD_REQUEST,
                )

        # Free-text search
        search = request.query_params.get("search", "").strip()
        if search:
            qs = qs.filter(
                Q(first_name__icontains=search)
                | Q(last_name__icontains=search)
                | Q(doctor_profile__specialization__icontains=search)
            )

        serializer = DoctorProfileBriefSerializer(qs, many=True)
        return api_response(
            data={"count": qs.count(), "doctors": serializer.data},
            message="Doctors retrieved successfully.",
        )


# ---------------------------------------------------------------------------
# FR-2.2  Real-Time Slot Availability
# ---------------------------------------------------------------------------

class DoctorSlotListView(APIView):
    """
    GET /appointments/doctors/<doctor_id>/slots/?date=YYYY-MM-DD

    Returns all slots (available + booked) for the requested date so
    the Flutter UI can colour them green/grey.  Slots are generated
    on-demand if they don't exist yet.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, doctor_id: int):
        # Resolve doctor
        try:
            doctor = User.objects.get(pk=doctor_id, role="doctor", is_active=True)
        except User.DoesNotExist:
            return api_response(
                message="Doctor not found.",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        # Parse date
        date_str = request.query_params.get("date", "").strip()
        if not date_str:
            return api_response(
                message="Query parameter 'date' is required (YYYY-MM-DD).",
                errors={"date": "Required."},
                status_code=status.HTTP_400_BAD_REQUEST,
            )
        try:
            requested_date = datetime.date.fromisoformat(date_str)
        except ValueError:
            return api_response(
                message="Invalid date format. Use YYYY-MM-DD.",
                errors={"date": "Invalid format."},
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        if requested_date < datetime.date.today():
            return api_response(
                message="Cannot view slots for past dates.",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        # Generate slots on demand (idempotent)
        SlotService.generate_slots_for_date(doctor, requested_date)

        slots = TimeSlot.objects.filter(
            doctor=doctor,
            date=requested_date,
        ).order_by("start_time")

        return api_response(
            data={
                "doctor_id":   doctor_id,
                "date":        date_str,
                "slots":       TimeSlotSerializer(slots, many=True).data,
                "total":       slots.count(),
                "available":   slots.filter(status=SlotStatus.AVAILABLE).count(),
            },
            message="Slots retrieved successfully.",
        )


class DoctorAvailabilityDatesView(APIView):
    """
    GET /doctors/<doctor_id>/availability/?from=YYYY-MM-DD&to=YYYY-MM-DD

    Returns the ISO dates within [from, to] on which the doctor has
    bookable slots (weekly schedule days + date overrides). Used by the
    patient booking calendar to grey-out unavailable dates (FR-2.2).
    When from/to are omitted, the next 365 days are returned.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, doctor_id: int):
        try:
            doctor = User.objects.get(pk=doctor_id, role="doctor", is_active=True)
        except User.DoesNotExist:
            return api_response(
                message="Doctor not found.",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        today = datetime.date.today()
        try:
            from_str = request.query_params.get("from", "").strip()
            start = datetime.date.fromisoformat(from_str) if from_str else today
            to_str = request.query_params.get("to", "").strip()
            end = datetime.date.fromisoformat(to_str) if to_str else today + datetime.timedelta(days=365)
        except ValueError:
            return api_response(
                message="Invalid date format. Use YYYY-MM-DD.",
                errors={"dates": "Invalid format."},
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        if end < start:
            start, end = end, start
        if start < today:
            start = today
        if start > end:
            return api_response(
                data={"doctor_id": doctor_id, "dates": []},
                message="No dates in range.",
            )

        dates = SlotService.available_dates(doctor, start, end)
        return api_response(
            data={
                "doctor_id": doctor_id,
                "from": start.isoformat(),
                "to": end.isoformat(),
                "dates": [d.isoformat() for d in dates],
            },
            message="Available dates retrieved successfully.",
        )


# ---------------------------------------------------------------------------
# FR-2.3  Book Appointment
# ---------------------------------------------------------------------------

class BookAppointmentView(APIView):
    """
    POST /appointments/book/
    Body: {slot_id, reason}
    """
    permission_classes = [IsAuthenticated, IsPatient]

    def post(self, request):
        serializer = BookAppointmentSerializer(
            data=request.data,
            context={"request": request},
        )
        if not serializer.is_valid():
            return api_response(
                message="Booking failed. Please fix the errors below.",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        slot   = serializer.validated_data["slot_id"]
        reason = serializer.validated_data["reason"]

        try:
            appointment = AppointmentService.book(
                patient=request.user,
                slot=slot,
                reason=reason,
            )
        except ValueError as exc:
            return api_response(
                message=str(exc),
                errors={"slot_id": str(exc)},
                status_code=status.HTTP_409_CONFLICT,
            )

        return api_response(
            data=AppointmentSerializer(
                appointment, context={"request": request}
            ).data,
            message="Appointment booked successfully. You will receive a confirmation shortly.",
            status_code=status.HTTP_201_CREATED,
        )


# ---------------------------------------------------------------------------
# FR-2.3 / 2.5 / 2.6  Appointment Detail + Cancel + Reschedule
# ---------------------------------------------------------------------------

class AppointmentDetailView(APIView):
    """
    GET    /appointments/<pk>/   — view detail
    DELETE /appointments/<pk>/   — cancel
    """
    permission_classes = [IsAuthenticated]

    def _get_appointment(self, pk: int, user: User) -> Appointment | None:
        """
        Patients see only their own appointments.
        Doctors see appointments assigned to them.
        Admins see all.
        """
        try:
            appt = Appointment.objects.select_related(
                "patient", "doctor", "slot", "doctor__doctor_profile"
            ).get(pk=pk)
        except Appointment.DoesNotExist:
            return None

        if user.is_admin_user:
            return appt
        if user.is_doctor and appt.doctor == user:
            return appt
        if user.is_patient and appt.patient == user:
            return appt
        return None  # forbidden

    def get(self, request, pk: int):
        appt = self._get_appointment(pk, request.user)
        if appt is None:
            return api_response(
                message="Appointment not found.",
                status_code=status.HTTP_404_NOT_FOUND,
            )
        return api_response(
            data=AppointmentSerializer(appt, context={"request": request}).data,
            message="Appointment retrieved successfully.",
        )


class CancelAppointmentView(APIView):
    """
    POST /appointments/<pk>/cancel/
    Body: {cancellation_reason}  (optional)
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, pk: int):
        try:
            appt = Appointment.objects.select_related(
                "patient", "doctor", "slot"
            ).get(pk=pk)
        except Appointment.DoesNotExist:
            return api_response(
                message="Appointment not found.",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        # Permission: patient owns it, doctor is assigned, or admin
        user = request.user
        if not (
            user.is_admin_user
            or (user.is_doctor and appt.doctor == user)
            or (user.is_patient and appt.patient == user)
        ):
            return api_response(
                message="You do not have permission to cancel this appointment.",
                status_code=status.HTTP_403_FORBIDDEN,
            )

        serializer = CancelAppointmentSerializer(data=request.data)
        if not serializer.is_valid():
            return api_response(
                message="Invalid request.",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        try:
            appt = AppointmentService.cancel(
                appointment=appt,
                by_user=user,
                reason=serializer.validated_data["cancellation_reason"],
            )
        except ValueError as exc:
            return api_response(
                message=str(exc),
                errors={"appointment": str(exc)},
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        return api_response(
            data=AppointmentSerializer(appt, context={"request": request}).data,
            message="Appointment cancelled successfully.",
        )


class RescheduleAppointmentView(APIView):
    """
    POST /appointments/<pk>/reschedule/
    Body: {new_slot_id, reason}
    """
    permission_classes = [IsAuthenticated, IsPatient]

    def post(self, request, pk: int):
        try:
            appt = Appointment.objects.select_related(
                "patient", "doctor", "slot"
            ).get(pk=pk, patient=request.user)
        except Appointment.DoesNotExist:
            return api_response(
                message="Appointment not found.",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        serializer = RescheduleSerializer(data=request.data)
        if not serializer.is_valid():
            return api_response(
                message="Reschedule failed. Please fix the errors below.",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        try:
            new_appt = AppointmentService.reschedule(
                old_appointment=appt,
                new_slot=serializer.validated_data["new_slot_id"],
                by_user=request.user,
                reason=serializer.validated_data["reason"],
            )
        except ValueError as exc:
            return api_response(
                message=str(exc),
                errors={"reschedule": str(exc)},
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        return api_response(
            data=AppointmentSerializer(new_appt, context={"request": request}).data,
            message="Appointment rescheduled successfully.",
            status_code=status.HTTP_201_CREATED,
        )


# ---------------------------------------------------------------------------
# FR-2.7  Doctor Schedule View
# ---------------------------------------------------------------------------

class DoctorScheduleListView(APIView):
    """
    GET /appointments/doctor/schedule/?date=YYYY-MM-DD
        Returns the authenticated doctor's appointments for a given date
        (or today if date omitted).

    GET /appointments/doctor/schedule/?range=week
        Returns appointments for the next 7 days.
    """
    permission_classes = [IsAuthenticated, IsDoctor]

    def get(self, request):
        doctor = request.user
        date_str = request.query_params.get("date", "").strip()
        range_mode = request.query_params.get("range", "").strip()

        if range_mode == "week":
            start_date = datetime.date.today()
            end_date   = start_date + datetime.timedelta(days=6)
            qs = Appointment.objects.filter(
                doctor=doctor,
                appointment_date__range=(start_date, end_date),
                status__in=[AppointmentStatus.CONFIRMED, AppointmentStatus.PENDING],
            ).select_related("patient").order_by("appointment_date", "appointment_time")

        else:
            if date_str:
                try:
                    target_date = datetime.date.fromisoformat(date_str)
                except ValueError:
                    return api_response(
                        message="Invalid date format. Use YYYY-MM-DD.",
                        status_code=status.HTTP_400_BAD_REQUEST,
                    )
            else:
                target_date = datetime.date.today()

            qs = Appointment.objects.filter(
                doctor=doctor,
                appointment_date=target_date,
            ).select_related("patient").order_by("appointment_time")

        return api_response(
            data={
                "count":        qs.count(),
                "appointments": AppointmentListSerializer(qs, many=True).data,
            },
            message="Schedule retrieved successfully.",
        )


# ---------------------------------------------------------------------------
# FR-2.7  Doctor marks Complete / No-Show
# ---------------------------------------------------------------------------

class DoctorMarkStatusView(APIView):
    """
    POST /appointments/<pk>/mark/
    Body: {new_status: "completed"|"no_show", notes: "..."}
    Doctor only.
    """
    permission_classes = [IsAuthenticated, IsDoctor]

    def post(self, request, pk: int):
        try:
            appt = Appointment.objects.select_related(
                "patient", "doctor"
            ).get(pk=pk, doctor=request.user)
        except Appointment.DoesNotExist:
            return api_response(
                message="Appointment not found.",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        serializer = DoctorStatusUpdateSerializer(data=request.data)
        if not serializer.is_valid():
            return api_response(
                message="Invalid request.",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        try:
            appt = AppointmentService.mark_status(
                appointment=appt,
                new_status=serializer.validated_data["new_status"],
                doctor=request.user,
                notes=serializer.validated_data["notes"],
            )
        except ValueError as exc:
            return api_response(
                message=str(exc),
                errors={"status": str(exc)},
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        return api_response(
            data=AppointmentSerializer(appt, context={"request": request}).data,
            message=f"Appointment marked as '{appt.status}'.",
        )


# ---------------------------------------------------------------------------
# FR-2.8  Appointment History
# ---------------------------------------------------------------------------

class AppointmentHistoryView(APIView):
    """
    GET /appointments/history/
    Query params:
      ?status=completed
      ?from=2026-01-01&to=2026-06-30
      ?doctor_id=5      (patient filtering)
      ?patient_id=12    (doctor/admin filtering)
      ?page=1&page_size=20
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user

        # Base queryset by role
        if user.is_patient:
            qs = Appointment.objects.filter(patient=user)
        elif user.is_doctor:
            qs = Appointment.objects.filter(doctor=user)
        else:
            qs = Appointment.objects.all()

        qs = qs.select_related("patient", "doctor", "doctor__doctor_profile")

        # Status filter
        status_filter = request.query_params.get("status", "").strip()
        if status_filter:
            qs = qs.filter(status=status_filter)

        # Date range filter
        from_str = request.query_params.get("from", "").strip()
        to_str   = request.query_params.get("to",   "").strip()
        if from_str:
            try:
                qs = qs.filter(appointment_date__gte=datetime.date.fromisoformat(from_str))
            except ValueError:
                pass
        if to_str:
            try:
                qs = qs.filter(appointment_date__lte=datetime.date.fromisoformat(to_str))
            except ValueError:
                pass

        # Cross-role filters
        doctor_id  = request.query_params.get("doctor_id",  "").strip()
        patient_id = request.query_params.get("patient_id", "").strip()
        if doctor_id  and not user.is_patient:
            qs = qs.filter(doctor__pk=doctor_id)
        if patient_id and not user.is_patient:
            qs = qs.filter(patient__pk=patient_id)

        qs = qs.order_by("-appointment_date", "-appointment_time")

        # Pagination
        page_size = min(int(request.query_params.get("page_size", 20)), 100)
        page      = max(int(request.query_params.get("page", 1)), 1)
        total     = qs.count()
        offset    = (page - 1) * page_size
        results   = qs[offset: offset + page_size]

        return api_response(
            data={
                "count":   total,
                "page":    page,
                "pages":   -(-total // page_size),
                "results": AppointmentListSerializer(results, many=True).data,
            },
            message="Appointment history retrieved successfully.",
        )


# ---------------------------------------------------------------------------
# FR-7.2  Admin: Doctor Schedule CRUD
# ---------------------------------------------------------------------------
# (existing admin endpoints retained)

class AdminDoctorScheduleView(APIView):
    """
    GET    /appointments/admin/schedules/?doctor_id=5
    POST   /appointments/admin/schedules/
    """
    permission_classes = [IsAuthenticated, IsAdminUser]

    def get(self, request):
        qs = DoctorSchedule.objects.select_related("doctor").order_by("doctor", "day_of_week")
        doctor_id = request.query_params.get("doctor_id", "").strip()
        if doctor_id:
            qs = qs.filter(doctor__pk=doctor_id)

        return api_response(
            data=DoctorScheduleSerializer(qs, many=True).data,
            message="Schedules retrieved successfully.",
        )

    def post(self, request):
        serializer = DoctorScheduleSerializer(data=request.data)
        if not serializer.is_valid():
            return api_response(
                message="Invalid schedule data.",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )
        schedule = serializer.save()
        return api_response(
            data=DoctorScheduleSerializer(schedule).data,
            message="Doctor schedule created successfully.",
            status_code=status.HTTP_201_CREATED,
        )


class AdminDoctorScheduleDetailView(APIView):
    """
    GET    /appointments/admin/schedules/<pk>/
    PATCH  /appointments/admin/schedules/<pk>/
    DELETE /appointments/admin/schedules/<pk>/
    """
    permission_classes = [IsAuthenticated, IsAdminUser]

    def _get(self, pk):
        try:
            return DoctorSchedule.objects.select_related("doctor").get(pk=pk)
        except DoctorSchedule.DoesNotExist:
            return None

    def get(self, request, pk):
        obj = self._get(pk)
        if not obj:
            return api_response(message="Schedule not found.", status_code=404)
        return api_response(data=DoctorScheduleSerializer(obj).data)

    def patch(self, request, pk):
        obj = self._get(pk)
        if not obj:
            return api_response(message="Schedule not found.", status_code=404)
        serializer = DoctorScheduleSerializer(obj, data=request.data, partial=True)
        if not serializer.is_valid():
            return api_response(
                message="Update failed.",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )
        serializer.save()
        return api_response(
            data=serializer.data,
            message="Schedule updated successfully.",
        )

    def delete(self, request, pk):
        obj = self._get(pk)
        if not obj:
            return api_response(message="Schedule not found.", status_code=404)
        obj.is_active = False
        obj.save(update_fields=["is_active"])
        return api_response(message="Schedule deactivated successfully.")


# ---------------------------------------------------------------------------
# FR-X  Doctor: My Availability (self-serve CRUD)
# ---------------------------------------------------------------------------

class DoctorMyAvailabilityView(APIView):
    """
    GET    /availability/my/
        Returns the authenticated doctor's active schedule entries.

    POST   /availability/my/
        Create a new schedule entry.
        Body: {
            "day_of_week": 1,
            "start_time": "08:00",
            "end_time": "17:00",
            "slot_duration_minutes": 15,
            "max_patients_per_day": 30
        }

    PATCH  /availability/my/<pk>/
        Update a specific schedule entry (partial update supported).
        Body fields same as POST (all optional).

    DELETE /availability/my/<pk>/
        Deactivate a schedule entry (soft-delete).
    """
    permission_classes = [IsAuthenticated, IsDoctor]

    def get(self, request):
        qs = DoctorSchedule.objects.filter(
            doctor=request.user,
            is_active=True,
        ).order_by("day_of_week", "start_time")
        return api_response(
            data=DoctorScheduleSerializer(qs, many=True).data,
            message="Your availability schedule retrieved.",
        )

    def post(self, request):
        serializer = DoctorScheduleSerializer(data=request.data)
        if not serializer.is_valid():
            return api_response(
                message="Invalid schedule data.",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )
        schedule = serializer.save(doctor=request.user)
        return api_response(
            data=DoctorScheduleSerializer(schedule).data,
            message="Schedule entry created successfully.",
            status_code=status.HTTP_201_CREATED,
        )


class DoctorMyAvailabilityDetailView(APIView):
    """
    PATCH /availability/my/<pk>/
    DELETE /availability/my/<pk>/
    """
    permission_classes = [IsAuthenticated, IsDoctor]

    def _get_own(self, pk, user):
        try:
            return DoctorSchedule.objects.get(pk=pk, doctor=user, is_active=True)
        except DoctorSchedule.DoesNotExist:
            return None

    def patch(self, request, pk):
        obj = self._get_own(pk, request.user)
        if not obj:
            return api_response(message="Schedule entry not found.", status_code=404)
        serializer = DoctorScheduleSerializer(obj, data=request.data, partial=True)
        if not serializer.is_valid():
            return api_response(
                message="Update failed.",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )
        serializer.save()
        return api_response(
            data=serializer.data,
            message="Schedule entry updated successfully.",
        )

    def delete(self, request, pk):
        obj = self._get_own(pk, request.user)
        if not obj:
            return api_response(message="Schedule entry not found.", status_code=404)
        obj.is_active = False
        obj.save(update_fields=["is_active"])
        return api_response(message="Schedule entry deactivated successfully.")


# ---------------------------------------------------------------------------
# Doctor: Date-specific availability overrides
# ---------------------------------------------------------------------------

class DoctorDateAvailabilityListView(APIView):
    """
    GET    /availability/dates/?month=YYYY-MM
        Returns the doctor's date overrides for the given month.
    POST   /availability/dates/
        Create a date override.
        Body: {date, override_type, start_time?, end_time?, ...}
    """
    permission_classes = [IsAuthenticated, IsDoctor]

    def get(self, request):
        from ..models import DoctorAvailabilityOverride
        from ..serializers import DoctorAvailabilityOverrideSerializer

        month_str = request.query_params.get("month", "").strip()
        qs = DoctorAvailabilityOverride.objects.filter(doctor=request.user)
        if month_str:
            try:
                year, month = map(int, month_str.split("-"))
                qs = qs.filter(date__year=year, date__month=month)
            except (ValueError, TypeError):
                pass
        qs = qs.order_by("date")
        return api_response(
            data=DoctorAvailabilityOverrideSerializer(qs, many=True).data,
            message="Date availability overrides retrieved.",
        )

    def post(self, request):
        from ..models import DoctorAvailabilityOverride
        from ..serializers import DoctorAvailabilityOverrideSerializer

        data = request.data.copy()
        data["doctor"] = request.user.pk
        serializer = DoctorAvailabilityOverrideSerializer(data=data)
        if not serializer.is_valid():
            return api_response(
                message="Invalid data.",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )
        override = serializer.save()
        return api_response(
            data=DoctorAvailabilityOverrideSerializer(override).data,
            message="Date override created successfully.",
            status_code=status.HTTP_201_CREATED,
        )


class DoctorDateAvailabilityDetailView(APIView):
    """
    PATCH /availability/dates/<pk>/
    DELETE /availability/dates/<pk>/
    """
    permission_classes = [IsAuthenticated, IsDoctor]

    def _get_own(self, pk, user):
        from ..models import DoctorAvailabilityOverride
        try:
            return DoctorAvailabilityOverride.objects.get(pk=pk, doctor=user)
        except DoctorAvailabilityOverride.DoesNotExist:
            return None

    def patch(self, request, pk):
        from ..models import DoctorAvailabilityOverride
        from ..serializers import DoctorAvailabilityOverrideSerializer

        obj = self._get_own(pk, request.user)
        if not obj:
            return api_response(message="Override not found.", status_code=404)
        serializer = DoctorAvailabilityOverrideSerializer(obj, data=request.data, partial=True)
        if not serializer.is_valid():
            return api_response(
                message="Update failed.",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )
        override = serializer.save()
        return api_response(
            data=DoctorAvailabilityOverrideSerializer(override).data,
            message="Override updated successfully.",
        )

    def delete(self, request, pk):
        obj = self._get_own(pk, request.user)
        if not obj:
            return api_response(message="Override not found.", status_code=404)
        obj.delete()
        return api_response(message="Override deleted successfully.")


# ---------------------------------------------------------------------------
# FR-2.10  Admin Override
# ---------------------------------------------------------------------------

class AdminAppointmentOverrideView(APIView):
    """
    POST   /appointments/admin/override/          — create on behalf of patient
    PATCH  /appointments/admin/override/<pk>/     — force-update any appointment
    DELETE /appointments/admin/override/<pk>/     — force-cancel any appointment
    """
    permission_classes = [IsAuthenticated, IsAdminUser]

    def post(self, request):
        """Create appointment on behalf of patient (admin picks patient + slot)."""
        ser = AdminAppointmentOverrideSerializer(data=request.data)
        if not ser.is_valid():
            return api_response(
                message="Invalid override data.",
                errors=ser.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        patient = ser.validated_data.get("patient_id")
        slot    = ser.validated_data.get("slot_id")
        reason  = ser.validated_data.get("reason", "")

        if not patient or not slot:
            return api_response(
                message="patient_id and slot_id are required for appointment creation.",
                errors={"patient_id": "Required.", "slot_id": "Required."},
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        try:
            appt = AppointmentService.admin_create(patient=patient, slot=slot, reason=reason)
        except ValueError as exc:
            return api_response(
                message=str(exc),
                errors={"slot_id": str(exc)},
                status_code=status.HTTP_409_CONFLICT,
            )

        return api_response(
            data=AppointmentSerializer(appt, context={"request": request}).data,
            message=f"Appointment created by admin on behalf of {patient.get_full_name()}.",
            status_code=status.HTTP_201_CREATED,
        )

    def patch(self, request, pk: int):
        """Force any status change on any appointment."""
        try:
            appt = Appointment.objects.get(pk=pk)
        except Appointment.DoesNotExist:
            return api_response(message="Appointment not found.", status_code=404)

        ser = AdminAppointmentOverrideSerializer(data=request.data, partial=True)
        if not ser.is_valid():
            return api_response(
                message="Invalid data.",
                errors=ser.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        new_status = ser.validated_data.get("new_status")
        notes      = ser.validated_data.get("notes", "")

        if new_status:
            appt = AppointmentService.admin_update_status(
                appointment=appt,
                new_status=new_status,
                admin=request.user,
                notes=notes,
            )

        return api_response(
            data=AppointmentSerializer(appt, context={"request": request}).data,
            message="Appointment updated by admin.",
        )

    def delete(self, request, pk: int):
        """Force-cancel any appointment regardless of time restriction."""
        try:
            appt = Appointment.objects.select_related("slot").get(pk=pk)
        except Appointment.DoesNotExist:
            return api_response(message="Appointment not found.", status_code=404)

        try:
            appt = AppointmentService.cancel(
                appointment=appt,
                by_user=request.user,
                reason=request.data.get("cancellation_reason", "Admin override cancellation"),
            )
        except ValueError as exc:
            return api_response(message=str(exc), status_code=status.HTTP_400_BAD_REQUEST)

        return api_response(message=f"Appointment #{pk} cancelled by admin.")