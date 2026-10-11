from django.core.exceptions import ValidationError
from django.db import transaction
from django.utils import timezone

from .models import Notification
from .tasks import deliver_notification_email_task


def create_notification(
    *,
    user,
    notification_type,
    title,
    message,
    order=None,
    data=None,
):
    if not user or not user.pk:
        raise ValidationError(
            {"user": "A valid notification recipient is required."}
        )

    if order:
        allowed_recipient_ids = {
            order.customer_id,
            order.assigned_courier_id,
        }

        if user.id not in allowed_recipient_ids:
            raise ValidationError(
                {
                    "user": (
                        "Notification recipient is not related to this order."
                    )
                }
            )

    notification = Notification.objects.create(
        user=user,
        order=order,
        notification_type=notification_type,
        title=title,
        message=message,
        data=dict(data or {}),
    )

    transaction.on_commit(
        lambda: deliver_notification_email_task.delay(notification.id)
    )

    return notification


@transaction.atomic
def mark_notification_as_read(*, notification_id, user):
    notification = (
        Notification.objects.select_for_update()
        .get(
            pk=notification_id,
            user=user,
        )
    )

    if not notification.is_read:
        notification.is_read = True
        notification.read_at = timezone.now()
        notification.save(
            update_fields=(
                "is_read",
                "read_at",
            )
        )

    return notification


@transaction.atomic
def mark_all_notifications_as_read(*, user):
    return Notification.objects.filter(
        user=user,
        is_read=False,
    ).update(
        is_read=True,
        read_at=timezone.now(),
    )