from rest_framework import serializers

from .models import AuditLog


class AuditLogSerializer(serializers.ModelSerializer):
    actor = serializers.IntegerField(
        source="actor_id",
        read_only=True,
        allow_null=True,
    )
    actor_username = serializers.CharField(
        source="actor.username",
        read_only=True,
        allow_null=True,
    )

    class Meta:
        model = AuditLog
        fields = (
            "id",
            "actor",
            "actor_username",
            "action",
            "target_type",
            "target_id",
            "metadata",
            "created_at",
        )
        read_only_fields = fields


class AuditLogFilterSerializer(serializers.Serializer):
    action = serializers.ChoiceField(
        choices=AuditLog.Action.choices,
        required=False,
    )
    target_type = serializers.ChoiceField(
        choices=AuditLog.TargetType.choices,
        required=False,
    )
    actor_id = serializers.IntegerField(
        min_value=1,
        required=False,
    )
    target_id = serializers.CharField(
        max_length=100,
        required=False,
    )