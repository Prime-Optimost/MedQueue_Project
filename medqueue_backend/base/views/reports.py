"""
reports/views.py

Admin report generation endpoints.

View map:
  AdminGeneralReportView  → general report (day / week / month / year)
  AdminPatientReportView  → per-patient appointment report
  AdminDoctorReportView   → per-doctor activity report
"""

import datetime

from django.db.models import Count, Q
from django.utils import timezone
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from base.permissions import IsAdminUser

from ..models import (
    Appointment,
    AppointmentStatus,
    DoctorAvailabilityOverride,
    DoctorSchedule,
    EmergencyRequest,
    EmergencyStatus,
    User,
    UserRole,
)


# ---------------------------------------------------------------------------
# Response helper (matches the envelope used across the project)
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
# Shared helpers
# ---------------------------------------------------------------------------

def _parse_date(value, default=None):
    if not value:
        return default
    try:
        return datetime.date.fromisoformat(str(value).strip())
    except (ValueError, TypeError):
        return default


def _period_bounds(period, anchor):
    """Return (from_date, to_date) for a period anchored at ``anchor``."""
    period = (period or "day").lower()
    if period == "week":
        start = anchor - datetime.timedelta(days=anchor.weekday())
        return start, start + datetime.timedelta(days=6)
    if period == "month":
        start = anchor.replace(day=1)
        next_month = (start.replace(day=28) + datetime.timedelta(days=4)).replace(
            day=1
        )
        return start, next_month - datetime.timedelta(days=1)
    if period == "year":
        return anchor.replace(month=1, day=1), anchor.replace(month=12, day=31)
    return anchor, anchor  # day (default)


def _full_name(user):
    if user is None:
        return ""
    return user.get_full_name() or user.username


def _appointment_status_counts(qs):
    counts = {
        AppointmentStatus.PENDING: 0,
        AppointmentStatus.CONFIRMED: 0,
        AppointmentStatus.COMPLETED: 0,
        AppointmentStatus.CANCELLED: 0,
        AppointmentStatus.NO_SHOW: 0,
        AppointmentStatus.RESCHEDULED: 0,
    }
    for row in qs.values("status").annotate(total=Count("id")):
        counts[row["status"]] = row["total"]
    return counts


# ---------------------------------------------------------------------------
# General report  (period-based)
# ---------------------------------------------------------------------------

class AdminGeneralReportView(APIView):
    """
    GET /admin/reports/general/?period=day|week|month|year&date=YYYY-MM-DD

    Aggregates the whole hospital for one period:
      - total booked appointments (with patient names + times)
      - appointment outcome summary (completed / cancelled / no-show / ...)
      - doctors that worked (with patients seen per doctor)
      - emergency alerts received (who triggered, dispatched vs falsed)
    """

    permission_classes = [IsAuthenticated, IsAdminUser]

    def get(self, request):
        period = request.query_params.get("period", "day").strip().lower()
        if period not in {"day", "week", "month", "year"}:
            return api_response(
                message="Invalid period. Choose one of: day, week, month, year.",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        anchor = _parse_date(request.query_params.get("date")) or timezone.localdate()
        from_date, to_date = _period_bounds(period, anchor)

        appointments = Appointment.objects.filter(
            appointment_date__gte=from_date,
            appointment_date__lte=to_date,
        ).select_related("patient", "doctor")

        total_booked = appointments.count()
        bookings = [
            {
                "appointment_id": appt.id,
                "patient_id": appt.patient.id,
                "patient_name": _full_name(appt.patient),
                "doctor_id": appt.doctor.id,
                "doctor_name": _full_name(appt.doctor),
                "date": appt.appointment_date.isoformat(),
                "time": appt.appointment_time.strftime("%H:%M") if appt.appointment_time else None,
                "status": appt.status,
            }
            for appt in appointments.order_by("appointment_date", "appointment_time")
        ]

        # Doctors that worked in the period
        doctor_rows = (
            appointments.order_by("doctor")
            .values("doctor", "doctor__username", "doctor__first_name", "doctor__last_name")
            .annotate(
                total=Count("id"),
                seen=Count("id", filter=Q(status=AppointmentStatus.COMPLETED)),
            )
        )
        doctors_worked = []
        for row in doctor_rows:
            doctor = User.objects.filter(pk=row["doctor"]).first()
            specialization = None
            if doctor is not None:
                profile = getattr(doctor, "doctor_profile", None)
                specialization = profile.specialization if profile else None
            doctors_worked.append(
                {
                    "id": row["doctor"],
                    "name": (
                        (row["doctor__first_name"] or "") + " " + (row["doctor__last_name"] or "")
                    ).strip()
                    or row["doctor__username"],
                    "specialization": specialization,
                    "appointments": row["total"],
                    "patients_seen": row["seen"],
                }
            )

        # Emergency alerts in the period (triggered at created_at)
        emergencies = EmergencyRequest.objects.filter(
            created_at__date__gte=from_date,
            created_at__date__lte=to_date,
        ).select_related("patient")

        emergency_total = emergencies.count()
        emergency_dispatched = emergencies.filter(
            status=EmergencyStatus.DISPATCHED
        ).count()
        emergency_falsed = emergencies.filter(
            status=EmergencyStatus.FALSE_ALARM
        ).count()

        return api_response(
            data={
                "period": period,
                "from_date": from_date.isoformat(),
                "to_date": to_date.isoformat(),
                "total_booked": total_booked,
                "bookings": bookings,
                "appointment_summary": _appointment_status_counts(appointments),
                "doctors_worked": {
                    "count": len(doctors_worked),
                    "doctors": doctors_worked,
                },
                "emergencies": {
                    "total": emergency_total,
                    "dispatched": emergency_dispatched,
                    "falsed": emergency_falsed,
                    "from": [
                        {
                            "alert_id": em.id,
                            "patient_id": em.patient.id,
                            "patient_name": _full_name(em.patient),
                            "emergency_type": em.emergency_type,
                            "status": em.status,
                            "description": em.description,
                            "created_at": em.created_at.isoformat(),
                        }
                        for em in emergencies.order_by("-created_at")
                    ],
                },
            },
            message="General report generated.",
        )


# ---------------------------------------------------------------------------
# Patient report
# ---------------------------------------------------------------------------

class AdminPatientReportView(APIView):
    """
    GET /admin/reports/patient/?patient_id=<id>

    Lists every appointment of a patient with the doctor's name,
    specialisation, date, time and the patient's stated reason
    (blank reason is included as empty).
    """

    permission_classes = [IsAuthenticated, IsAdminUser]

    def get(self, request):
        patient_id = request.query_params.get("patient_id")
        if not patient_id:
            return api_response(
                message="patient_id is required.",
                status_code=status.HTTP_400_BAD_REQUEST,
            )
        try:
            patient = User.objects.get(pk=patient_id, role=UserRole.PATIENT)
        except User.DoesNotExist:
            return api_response(
                message="Patient not found.",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        appointments = (
            Appointment.objects.filter(patient=patient)
            .select_related("doctor")
            .order_by("-appointment_date", "-appointment_time")
        )

        return api_response(
            data={
                "patient_id": patient.id,
                "patient_name": _full_name(patient),
                "total_appointments": appointments.count(),
                "appointments": [
                    {
                        "appointment_id": appt.id,
                        "doctor_id": appt.doctor.id,
                        "doctor_name": _full_name(appt.doctor),
                        "specialization": (
                            getattr(appt.doctor, "doctor_profile", None).specialization
                            if getattr(appt.doctor, "doctor_profile", None)
                            else None
                        ),
                        "date": appt.appointment_date.isoformat(),
                        "time": appt.appointment_time.strftime("%H:%M") if appt.appointment_time else None,
                        "reason": appt.reason or "",
                        "status": appt.status,
                        "notes": appt.notes or "",
                    }
                    for appt in appointments
                ],
            },
            message=f"Patient report generated for {_full_name(patient)}.",
        )


# ---------------------------------------------------------------------------
# Doctor report
# ---------------------------------------------------------------------------

class AdminDoctorReportView(APIView):
    """
    GET /admin/reports/doctor/?doctor_id=<id>&from=YYYY-MM-DD&to=YYYY-MM-DD

    Doctor activity report:
      - active days (recurring weekly schedule + date overrides)
      - total patients seen (completed appointments)
      - all patients that booked with the doctor (names + time + date)
      - patients the doctor was able to care for (completed)
    """

    permission_classes = [IsAuthenticated, IsAdminUser]

    def get(self, request):
        doctor_id = request.query_params.get("doctor_id")
        if not doctor_id:
            return api_response(
                message="doctor_id is required.",
                status_code=status.HTTP_400_BAD_REQUEST,
            )
        try:
            doctor = User.objects.get(pk=doctor_id, role=UserRole.DOCTOR)
        except User.DoesNotExist:
            return api_response(
                message="Doctor not found.",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        from_date = _parse_date(request.query_params.get("from"))
        to_date = _parse_date(request.query_params.get("to"))
        appts = Appointment.objects.filter(doctor=doctor).select_related("patient")
        if from_date:
            appts = appts.filter(appointment_date__gte=from_date)
        if to_date:
            appts = appts.filter(appointment_date__lte=to_date)
        appts = appts.order_by("appointment_date", "appointment_time")

        completed = appts.filter(status=AppointmentStatus.COMPLETED)

        active_days = list(
            DoctorSchedule.objects.filter(doctor=doctor, is_active=True)
            .order_by("day_of_week")
            .values(
                "id",
                "day_of_week",
                "start_time",
                "end_time",
                "slot_duration_minutes",
                "max_patients_per_day",
            )
        )

        overrides = DoctorAvailabilityOverride.objects.filter(
            doctor=doctor,
            date__gte=from_date or datetime.date(2000, 1, 1),
            date__lte=to_date or datetime.date(2999, 12, 31),
        ).order_by("date")
        date_overrides = [
            {
                "id": o.id,
                "date": o.date.isoformat(),
                "override_type": o.override_type,
                "start_time": o.start_time.strftime("%H:%M") if o.start_time else None,
                "end_time": o.end_time.strftime("%H:%M") if o.end_time else None,
            }
            for o in overrides
        ]

        def _visit_payload(appt):
            return {
                "appointment_id": appt.id,
                "patient_id": appt.patient.id,
                "patient_name": _full_name(appt.patient),
                "date": appt.appointment_date.isoformat(),
                "time": appt.appointment_time.strftime("%H:%M") if appt.appointment_time else None,
                "status": appt.status,
                "notes": appt.notes or "",
            }

        profile = getattr(doctor, "doctor_profile", None)
        return api_response(
            data={
                "doctor_id": doctor.id,
                "doctor_name": _full_name(doctor),
                "specialization": profile.specialization if profile else None,
                "hospital_name": profile.hospital_name if profile else None,
                "is_accepting_patients": (
                    bool(profile.is_accepting_patients) if profile else False
                ),
                "active_days": active_days,
                "date_overrides": date_overrides,
                "total_appointments": appts.count(),
                "total_patients_seen": completed.count(),
                "booked_patients": [_visit_payload(a) for a in appts],
                "patients_cared_for": [_visit_payload(a) for a in completed],
            },
            message=f"Doctor report generated for {doctor.get_full_name()}.",
        )