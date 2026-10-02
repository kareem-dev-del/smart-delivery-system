from rest_framework import generics
from rest_framework.permissions import IsAuthenticated

from accounts.permissions import IsAdminRole

from .models import AuditLog
from .pagination import AuditLogPagination
from .serializers import (
    AuditLogFilterSerializer,
    AuditLogSerializer,
)


class AuditLogListAPIView(generics.ListAPIView):
    serializer_class = AuditLogSerializer
    pagination_class = AuditLogPagination
    permission_classes = [IsAuthenticated, IsAdminRole]

    def get_queryset(self):
        filter_serializer = AuditLogFilterSerializer(
            data=self.request.query_params,
        )
        filter_serializer.is_valid(raise_exception=True)

        filters = filter_serializer.validated_data

        queryset = AuditLog.objects.select_related(
            "actor"
        ).order_by("-created_at")

        if "action" in filters:
            queryset = queryset.filter(action=filters["action"])

        if "target_type" in filters:
            queryset = queryset.filter(
                target_type=filters["target_type"]
            )

        if "actor_id" in filters:
            queryset = queryset.filter(actor_id=filters["actor_id"])

        if "target_id" in filters:
            queryset = queryset.filter(
                target_id=filters["target_id"]
            )

        return queryset

    def list(self, request, *args, **kwargs):
        response = super().list(request, *args, **kwargs)
        response["Cache-Control"] = "no-store"
        return response