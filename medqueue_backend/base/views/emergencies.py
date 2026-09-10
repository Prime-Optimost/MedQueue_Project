"""
emergency/views.py

All API views for Module 5: Emergency SOS & Ambulance Request.

View map (FR traceability):
  TriggerSOSView              → FR-5.3 / FR-5.4  patient triggers SOS + GPS
  ActiveSOSStatusView         → FR-5.7  patient polls their active request
  CancelSOSView               → FR-5.2  patient cancels within window
  PatientEmergencyHistoryView → FR-5.8  patient's past SOS records
  AdminUpdateSOSStatusView    → FR-5.7  admin / doctor updates status
  AdminEmergencyLogView       → FR-7.6  admin full log with filters
  AdminEmergencyDetailView    → FR-7.6  admin single request detail
  AdminEmergencySummaryView   → FR-7.6  admin aggregate stats
  EmergencyContactListView    → FR-5.5  admin CRUD on hospital contacts
  EmergencyContactDetailView  → FR-5.5  admin update / delete contact
"""

import datetime

from django.utils import timezone
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from base.models import User
from base.permissions import IsAdminUser, IsDoctor, IsPatient  # adjust app name

from ..models import EmergencyContact, EmergencyRequest, EmergencyStatus
from ..serializers import (
    CancelSOSSerializer,
    EmergencyContactSerializer,
    EmergencyRequestListSerializer,
    EmergencyRequestSerializer,
    EmergencySummaryStatsSerializer,
    TriggerSOSSerializer,
    UpdateEmergencyStatusSerializer,
)
from ..services import EmergencyAnalyticsService, EmergencyService


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
# FR-5.3 / FR-5.4  Patient triggers SOS
# ---------------------------------------------------------------------------

class TriggerSOSView(APIView):
    """
    POST /emergency/sos/

    Called by Flutter after the patient confirms the 5-second countdown
    (FR-5.2 is handled client-side). GPS coordinates, emergency type, and
    an optional description are sent in the body.

    Returns the newly created EmergencyRequest and the Google Maps URL
    (so Flutter can show it on a status screen).

    Side effects (all within the same request cycle, < 5 seconds target):
      - Creates EmergencyRequest (status: pending)
      - Alerts all active EmergencyContacts via push + SMS (FR-5.5)
      - Sends patient acknowledgement (FR-5.6)
    """
    permission_classes = [IsAuthenticated, IsPatient]

    def post(self, request):
        serializer = TriggerSOSSerializer(
            data=request.data,
            context={"request": request},
        )
        if not serializer.is_valid():
            return api_response(
                message="SOS submission failed.",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        d = serializer.validated_data
        emergency = EmergencyService.create_sos(
            patient        = request.user,
            latitude       = d.get("latitude"),
            longitude      = d.get("longitude"),
            gps_accuracy   = d.get("gps_accuracy"),
            emergency_type = d.get("emergency_type"),
            description    = d.get("description", ""),
        )

        return api_response(
            data=EmergencyRequestSerializer(emergency).data,
            message=(
                "🚨 Emergency request received. "
                "Hospital staff have been alerted. Help is on the way."
            ),
            status_code=status.HTTP_201_CREATED,
        )


# ---------------------------------------------------------------------------
# FR-5.7  Patient: view active SOS status
# ---------------------------------------------------------------------------

class ActiveSOSStatusView(APIView):
    """
    GET /emergency/sos/active/

    Patient polls their currently active (pending / dispatched) emergency request.
    Flutter should poll this every 10 seconds or subscribe to Firebase
    (path: /emergency/{patient_id}/active/).

    Returns null data with `has_active: false` if no active SOS exists.
    """
    permission_classes = [IsAuthenticated, IsPatient]

    def get(self, request):
        emergency = EmergencyService.get_active_request(request.user)

        if not emergency:
            return api_response(
                data={"has_active": False},
                message="No active emergency request.",
            )

        return api_response(
            data={
                "has_active": True,
                "request":    EmergencyRequestSerializer(emergency).data,
            },
            message="Active emergency request retrieved.",
        )


# ---------------------------------------------------------------------------
# FR-5.2  Patient: cancel pending SOS
# ---------------------------------------------------------------------------

class CancelSOSView(APIView):
    """
    POST /emergency/sos/<pk>/cancel/

    Patient cancels their own PENDING SOS (e.g., accidental trigger).
    Only PENDING requests can be cancelled — DISPATCHED ones require admin action.
    """
    permission_classes = [IsAuthenticated, IsPatient]

    def post(self, request, pk: int):
        try:
            emergency = EmergencyRequest.objects.get(pk=pk, patient=request.user)
        except EmergencyRequest.DoesNotExist:
            return api_response(
                message="Emergency request not found.",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        try:
            emergency = EmergencyService.cancel_sos(emergency, request.user)
        except (ValueError, PermissionError) as exc:
            return api_response(
                message=str(exc),
                errors={"sos": str(exc)},
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        return api_response(
            data=EmergencyRequestSerializer(emergency).data,
            message="Emergency request cancelled.",
        )


# ---------------------------------------------------------------------------
# FR-5.8  Patient: emergency history
# ---------------------------------------------------------------------------

class PatientEmergencyHistoryView(APIView):
    """
    GET /emergency/history/
    Query params: ?page=1&page_size=10

    Returns the authenticated patient's full SOS history, newest first,
    with status timeline logs attached to each record.
    """
    permission_classes = [IsAuthenticated, IsPatient]

    def get(self, request):
        history   = EmergencyService.get_patient_history(request.user)
        page_size = min(int(request.query_params.get("page_size", 10)), 50)
        page      = max(int(request.query_params.get("page", 1)), 1)
        total     = len(history)
        offset    = (page - 1) * page_size
        results   = history[offset: offset + page_size]

        return api_response(
            data={
                "count":   total,
                "page":    page,
                "pages":   -(-total // page_size),
                "results": EmergencyRequestListSerializer(results, many=True).data,
            },
            message="Emergency history retrieved.",
        )


# ---------------------------------------------------------------------------
# FR-5.7  Admin / Doctor: update SOS status
# ---------------------------------------------------------------------------

class AdminUpdateSOSStatusView(APIView):
    """
    PATCH /emergency/admin/<pk>/status/

    Admin or duty doctor updates the status of any emergency request.
    Allows:
      pending    → dispatched (with optional ambulance details)
      pending    → false_alarm
      dispatched → resolved
      dispatched → false_alarm

    All status changes are immutably logged in EmergencyStatusLog.
    Patient is notified of every change.
    """
    permission_classes = [IsAuthenticated]

    def patch(self, request, pk: int):
        # Allow admins AND doctors (duty doctors handle emergencies)
        if not (request.user.is_admin_user or request.user.is_doctor):
            return api_response(
                message="Only admins and doctors can update emergency status.",
                status_code=status.HTTP_403_FORBIDDEN,
            )

        try:
            emergency = EmergencyRequest.objects.select_related(
                "patient", "handled_by"
            ).get(pk=pk)
        except EmergencyRequest.DoesNotExist:
            return api_response(
                message="Emergency request not found.",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        serializer = UpdateEmergencyStatusSerializer(
            data=request.data,
            context={"emergency_request": emergency},
        )
        if not serializer.is_valid():
            return api_response(
                message="Invalid status update.",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        d = serializer.validated_data

        try:
            emergency = EmergencyService.update_status(
                request              = emergency,
                new_status           = d["new_status"],
                by_user              = request.user,
                notes                = d.get("notes", ""),
                ambulance_plate      = d.get("ambulance_plate", ""),
                ambulance_eta_minutes= d.get("ambulance_eta_minutes"),
                resolution_notes     = d.get("resolution_notes", ""),
            )
        except ValueError as exc:
            return api_response(
                message=str(exc),
                errors={"new_status": str(exc)},
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        return api_response(
            data=EmergencyRequestSerializer(emergency).data,
            message=f"Emergency #{pk} status updated to '{emergency.status}'.",
        )


# ---------------------------------------------------------------------------
# FR-7.6  Admin: full emergency log
# ---------------------------------------------------------------------------

class AdminEmergencyLogView(APIView):
    """
    GET /emergency/admin/log/
    Query params:
      ?status=pending
      ?from=YYYY-MM-DD&to=YYYY-MM-DD
      ?patient_id=12
      ?page=1&page_size=20

    Admin's searchable, filterable log of all SOS records.
    """
    permission_classes = [IsAuthenticated, IsAdminUser]

    def get(self, request):
        from_str   = request.query_params.get("from", "").strip()
        to_str     = request.query_params.get("to", "").strip()
        sos_status = request.query_params.get("status", "").strip()
        patient_id = request.query_params.get("patient_id", "").strip()

        from_date = None
        to_date   = None

        try:
            if from_str:
                from_date = datetime.date.fromisoformat(from_str)
            if to_str:
                to_date = datetime.date.fromisoformat(to_str)
        except ValueError:
            return api_response(
                message="Invalid date format. Use YYYY-MM-DD.",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        records = EmergencyAnalyticsService.admin_log(
            from_date  = from_date,
            to_date    = to_date,
            status     = sos_status or None,
            patient_id = int(patient_id) if patient_id else None,
        )

        page_size = min(int(request.query_params.get("page_size", 20)), 100)
        page      = max(int(request.query_params.get("page", 1)), 1)
        total     = len(records)
        offset    = (page - 1) * page_size
        results   = records[offset: offset + page_size]

        return api_response(
            data={
                "count":   total,
                "page":    page,
                "pages":   -(-total // page_size),
                "results": EmergencyRequestListSerializer(results, many=True).data,
            },
            message="Emergency log retrieved.",
        )


# ---------------------------------------------------------------------------
# FR-7.6  Admin: single SOS detail (full with status history)
# ---------------------------------------------------------------------------

class AdminEmergencyDetailView(APIView):
    """
    GET   /emergency/admin/<pk>/
    Returns the full EmergencyRequest including the complete status log timeline.
    """
    permission_classes = [IsAuthenticated, IsAdminUser]

    def get(self, request, pk: int):
        try:
            emergency = EmergencyRequest.objects.select_related(
                "patient", "handled_by"
            ).prefetch_related(
                "status_logs__changed_by"
            ).get(pk=pk)
        except EmergencyRequest.DoesNotExist:
            return api_response(
                message="Emergency request not found.",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        return api_response(
            data=EmergencyRequestSerializer(emergency).data,
            message="Emergency request retrieved.",
        )


# ---------------------------------------------------------------------------
# FR-7.6  Admin: aggregate summary stats
# ---------------------------------------------------------------------------

class AdminEmergencySummaryView(APIView):
    """
    GET /emergency/admin/summary/
    Query params: ?from=YYYY-MM-DD&to=YYYY-MM-DD

    Dashboard summary: totals by status, average response time,
    and breakdown by emergency type.
    """
    permission_classes = [IsAuthenticated, IsAdminUser]

    def get(self, request):
        from_str = request.query_params.get("from", "").strip()
        to_str   = request.query_params.get("to", "").strip()

        from_date = None
        to_date   = None
        try:
            if from_str:
                from_date = datetime.date.fromisoformat(from_str)
            if to_str:
                to_date = datetime.date.fromisoformat(to_str)
        except ValueError:
            return api_response(
                message="Invalid date format.",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        stats = EmergencyAnalyticsService.summary_stats(from_date, to_date)

        return api_response(
            data=EmergencySummaryStatsSerializer(stats).data,
            message="Emergency summary statistics retrieved.",
        )


# ---------------------------------------------------------------------------
# FR-5.5  Admin: manage emergency contacts
# ---------------------------------------------------------------------------

class EmergencyContactListView(APIView):
    """
    GET  /emergency/admin/contacts/       — list all contacts
    POST /emergency/admin/contacts/       — create new contact
    """
    permission_classes = [IsAuthenticated, IsAdminUser]

    def get(self, request):
        contact_type = request.query_params.get("type", "").strip()
        qs = EmergencyContact.objects.order_by("contact_type", "name")
        if contact_type:
            qs = qs.filter(contact_type=contact_type)

        return api_response(
            data=EmergencyContactSerializer(qs, many=True).data,
            message="Emergency contacts retrieved.",
        )

    def post(self, request):
        serializer = EmergencyContactSerializer(data=request.data)
        if not serializer.is_valid():
            return api_response(
                message="Invalid contact data.",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )
        contact = serializer.save()
        return api_response(
            data=EmergencyContactSerializer(contact).data,
            message="Emergency contact created successfully.",
            status_code=status.HTTP_201_CREATED,
        )


class EmergencyContactDetailView(APIView):
    """
    GET    /emergency/admin/contacts/<pk>/
    PATCH  /emergency/admin/contacts/<pk>/
    DELETE /emergency/admin/contacts/<pk>/  — soft deactivate
    """
    permission_classes = [IsAuthenticated, IsAdminUser]

    def _get(self, pk):
        try:
            return EmergencyContact.objects.get(pk=pk)
        except EmergencyContact.DoesNotExist:
            return None

    def get(self, request, pk: int):
        obj = self._get(pk)
        if not obj:
            return api_response(message="Contact not found.", status_code=404)
        return api_response(data=EmergencyContactSerializer(obj).data)

    def patch(self, request, pk: int):
        obj = self._get(pk)
        if not obj:
            return api_response(message="Contact not found.", status_code=404)
        serializer = EmergencyContactSerializer(obj, data=request.data, partial=True)
        if not serializer.is_valid():
            return api_response(
                message="Update failed.",
                errors=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )
        serializer.save()
        return api_response(
            data=serializer.data,
            message="Contact updated successfully.",
        )

    def delete(self, request, pk: int):
        obj = self._get(pk)
        if not obj:
            return api_response(message="Contact not found.", status_code=404)
        obj.is_active = False
        obj.save(update_fields=["is_active", "updated_at"])
        return api_response(message=f"Emergency contact '{obj.name}' deactivated.")