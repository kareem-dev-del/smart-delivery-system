from rest_framework import generics, status
from rest_framework.exceptions import NotFound
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from accounts.permissions import IsAdminRole

from .models import Notification
from .models import PushDevice
from .pagination import NotificationPagination
from .serializers import (
    AdminNotificationListFilterSerializer,
    AdminNotificationSerializer,
    NotificationListFilterSerializer,
    NotificationSerializer,
    NotificationMarkAllReadResponseSerializer,
    PushDeviceSerializer,
    PushDeviceDeleteSerializer,
)
from .services import (
    mark_all_notifications_as_read,
    mark_notification_as_read,
)
from drf_spectacular.utils import extend_schema
from django.db import transaction


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


@extend_schema(
    tags=["Notifications"],
    request=PushDeviceSerializer,
    responses={status.HTTP_200_OK: PushDeviceSerializer},
)
class PushDeviceAPIView(APIView):
    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request):
        serializer = PushDeviceSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        device, _ = PushDevice.objects.update_or_create(
            token=serializer.validated_data["token"],
            defaults={
                "user": request.user,
                "platform": serializer.validated_data["platform"],
            },
        )
        return Response(
            PushDeviceSerializer(device).data,
            status=status.HTTP_200_OK,
            headers={"Cache-Control": "no-store"},
        )

    def delete(self, request):
        serializer = PushDeviceDeleteSerializer(data=request.query_params)
        serializer.is_valid(raise_exception=True)
        deleted, _ = PushDevice.objects.filter(
            user=request.user,
            token=serializer.validated_data["token"],
        ).delete()
        return Response({"deleted": deleted > 0}, status=status.HTTP_200_OK)
