from rest_framework import generics, status
from rest_framework.exceptions import NotFound
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from accounts.permissions import IsAdminRole

from .models import Notification
from .pagination import NotificationPagination
from .serializers import (
    AdminNotificationListFilterSerializer,
    AdminNotificationSerializer,
    NotificationListFilterSerializer,
    NotificationSerializer,
    NotificationMarkAllReadResponseSerializer,
)
from .services import (
    mark_all_notifications_as_read,
    mark_notification_as_read,
)
from drf_spectacular.utils import extend_schema


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

        if "unread" in self.request.query_params:
           unread = filter_serializer.validated_data["unread"]

           queryset = queryset.filter(is_read=not unread)

        return queryset



class AdminNotificationListAPIView(generics.ListAPIView):
    serializer_class = AdminNotificationSerializer
    pagination_class = NotificationPagination
    permission_classes = [IsAdminRole]

    def get_queryset(self):
        filter_serializer = AdminNotificationListFilterSerializer(
            data=self.request.query_params,
        )
        filter_serializer.is_valid(raise_exception=True)

        filters = filter_serializer.validated_data

        queryset = (
            Notification.objects.select_related("user", "order")
            .order_by("-created_at")
        )

        if "delivery_status" in filters:
            queryset = queryset.filter(
                delivery_status=filters["delivery_status"],
            )

        if "notification_type" in filters:
            queryset = queryset.filter(
                notification_type=filters["notification_type"],
            )
        if "unread" in self.request.query_params:
            queryset = queryset.filter(
                is_read=not filters["unread"],
            )

        return queryset

    def list(self, request, *args, **kwargs):
        response = super().list(request, *args, **kwargs)
        response["Cache-Control"] = "no-store"
        return response

@extend_schema(
    tags=["Notifications"],
    request=None,
    responses={status.HTTP_200_OK: NotificationSerializer},
)
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

@extend_schema(
    tags=["Notifications"],
    request=None,
    responses={
        status.HTTP_200_OK: NotificationMarkAllReadResponseSerializer,
    },
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