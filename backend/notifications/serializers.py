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
            "delivery_status",
            "delivery_attempts",
            "delivered_at",
            "delivery_error",
            "read_at",
            "created_at",
        )
        read_only_fields = fields


class NotificationMarkAllReadResponseSerializer(serializers.Serializer):
    updated_count = serializers.IntegerField(read_only=True)

class NotificationListFilterSerializer(serializers.Serializer):
    unread = serializers.BooleanField(required=False)


class AdminNotificationSerializer(NotificationSerializer):
    recipient = serializers.IntegerField(
        source="user_id",
        read_only=True,
    )
    recipient_username = serializers.CharField(
        source="user.username",
        read_only=True,
    )

    class Meta(NotificationSerializer.Meta):
        fields = NotificationSerializer.Meta.fields + (
            "recipient",
            "recipient_username",
        )
        read_only_fields = fields


class AdminNotificationListFilterSerializer(serializers.Serializer):
    delivery_status = serializers.ChoiceField(
        choices=Notification.DeliveryStatus.choices,
        required=False,
    )
    notification_type = serializers.ChoiceField(
        choices=Notification.Type.choices,
        required=False,
    )
    unread = serializers.BooleanField(required=False)
