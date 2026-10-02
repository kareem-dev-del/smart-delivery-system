from rest_framework import serializers

from .models import Notification


class NotificationSerializer(serializers.ModelSerializer):
    order_public_id = serializers.UUIDField(
        source="order.public_id",
        read_only=True,
        allow_null=True,
    )

    class Meta:
        model = Notification
        fields = (
            "id",
            "notification_type",
            "title",
            "message",
            "data",
            "order_public_id",
            "is_read",
            "read_at",
            "created_at",
        )
        read_only_fields = fields


class NotificationListFilterSerializer(serializers.Serializer):
    unread = serializers.BooleanField(required=False)