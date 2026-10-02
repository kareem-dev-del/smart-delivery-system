from rest_framework import generics, status
from rest_framework.exceptions import NotFound
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Notification
from .pagination import NotificationPagination
from .serializers import (
    NotificationListFilterSerializer,
    NotificationSerializer,
)
from .services import (
    mark_all_notifications_as_read,
    mark_notification_as_read,
)


class NotificationListAPIView(generics.ListAPIView):
    serializer_class = NotificationSerializer
    pagination_class = NotificationPagination
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        filter_serializer = NotificationListFilterSerializer(
            data=self.request.query_params,
        )
        filter_serializer.is_valid(raise_exception=True)

        queryset = (
            Notification.objects.filter(user=self.request.user)
            .select_related("order")
            .order_by("-created_at")
        )

        if "unread" in filter_serializer.validated_data:
            unread = filter_serializer.validated_data["unread"]

            queryset = queryset.filter(is_read=not unread)

        return queryset


class NotificationMarkReadAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        try:
            notification = mark_notification_as_read(
                notification_id=pk,
                user=request.user,
            )
        except Notification.DoesNotExist as error:
            raise NotFound("Notification not found.") from error

        return Response(
            NotificationSerializer(notification).data,
            status=status.HTTP_200_OK,
            headers={"Cache-Control": "no-store"},
        )


class NotificationMarkAllReadAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        updated_count = mark_all_notifications_as_read(
            user=request.user,
        )

        return Response(
            {"updated_count": updated_count},
            status=status.HTTP_200_OK,
            headers={"Cache-Control": "no-store"},
        )