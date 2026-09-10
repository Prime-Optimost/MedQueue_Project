"""
availability/views.py — Doctor self-serve availability CRUD.

Endpoints (all under the same /api/v1/auth/ prefix):
  GET    /availability/my/
  POST   /availability/my/
  PATCH  /availability/my/<pk>/
  DELETE /availability/my/<pk>/

These let authenticated doctors manage their own DoctorSchedule rows
without involving an admin.
"""

from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework import status

from ..models import DoctorSchedule
from ..permissions import IsDoctor
from ..serializers import DoctorScheduleSerializer


def api_response(data=None, message="", status_code=200, errors=None) -> Response:
    return Response(
        {
            "status": "error" if errors else "success",
            "message": message,
            "data": data,
            "errors": errors,
        },
        status=status_code,
    )


class DoctorMyAvailabilityView(APIView):
    """
    GET    /availability/my/
        List the authenticated doctor's active availability entries.

    POST   /availability/my/
        Create a new schedule entry for the authenticated doctor.
        Body fields (all required unless noted):
            day_of_week            int     0 = Monday … 6 = Sunday
            start_time             time    "08:00"
            end_time               time    "17:00"
            slot_duration_minutes  int     default 15
            max_patients_per_day   int     default 20
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
        data = request.data.copy()
        data["doctor"] = request.user.pk
        serializer = DoctorScheduleSerializer(data=data)
        if not serializer.is_valid():
            return api_response(
                message="Invalid schedule data.",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )
        schedule = serializer.save()
        return api_response(
            data=DoctorScheduleSerializer(schedule).data,
            message="Schedule entry created successfully.",
            status_code=status.HTTP_201_CREATED,
        )


class DoctorMyAvailabilityDetailView(APIView):
    """
    PATCH  /availability/my/<pk>/
        Partially update a schedule entry the doctor owns.

    DELETE /availability/my/<pk>/
        Soft-deactivate a schedule entry.
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
        payload = {"id": obj.pk, "is_active": False}
        obj.is_active = False
        obj.save(update_fields=["is_active"])
        return api_response(
            data=payload,
            message="Schedule entry deactivated successfully.",
        )
