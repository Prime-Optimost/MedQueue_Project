"""
notifications/views.py

API views for the in-app notification inbox.
Used by patients, doctors and admins to list / mark / delete their notifications.
"""

from django.db.models import Q
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from ..models import Notification
from ..serializers import NotificationSerializer


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


class NotificationListView(APIView):
    """
    GET  /auth/notifications/        → list current user's notifications (newest first)
    POST /auth/notifications/read/   → mark one or all as read
    """

    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = (
            Notification.objects.filter(recipient=request.user)
            .order_by("-created_at")
        )
        unread_total = qs.filter(is_read=False).count()
        data = {
            "results": NotificationSerializer(qs, many=True).data,
            "unread_total": unread_total,
        }
        return api_response(data=data, message="Notifications retrieved.")

    def post(self, request):
        # Body: {"id": <id>}  or  {"all": true}  → mark read
        body = request.data or {}
        if body.get("all"):
            Notification.objects.filter(recipient=request.user, is_read=False).update(
                is_read=True
            )
            return api_response(
                data={"marked": "all"}, message="All notifications marked as read."
            )

        notif_id = body.get("id")
        if notif_id is None:
            return api_response(
                message="Provide either 'id' or 'all': true.",
                errors={"body": "Missing 'id' or 'all'."},
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        updated = Notification.objects.filter(
            Q(recipient=request.user, id=notif_id, is_read=False)
        ).update(is_read=True)
        return api_response(
            data={"marked": updated},
            message="Notification marked as read." if updated else "Notification already read or not found.",
        )


class NotificationDetailView(APIView):
    """
    DELETE /auth/notifications/<id>/   → delete one of the current user's notifications
    """

    permission_classes = [IsAuthenticated]

    def delete(self, request, pk):
        deleted, _ = Notification.objects.filter(
            recipient=request.user, id=pk
        ).delete()
        return api_response(
            data={"deleted": deleted},
            message="Notification deleted." if deleted else "Notification not found.",
            status_code=status.HTTP_200_OK if deleted else status.HTTP_404_NOT_FOUND,
        )
