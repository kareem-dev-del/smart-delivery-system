from django.core.exceptions import ValidationError

from .models import AuditLog


def create_audit_log(
    *,
    actor,
    action,
    target_type,
    target_id,
    metadata=None,
):
    if not target_id:
        raise ValidationError(
            {"target_id": "A target id is required."}
        )

    return AuditLog.objects.create(
        actor=actor,
        action=action,
        target_type=target_type,
        target_id=str(target_id),
        metadata=dict(metadata or {}),
    )