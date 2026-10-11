from celery import shared_task
from django.conf import settings
from django.core.mail import send_mail
from django.db import transaction
from django.utils import timezone

from .models import Notification


def build_notification_email_message(notification):
    lines = [
        notification.message,
        "",
        f"Notification type: {notification.notification_type}",
    ]

    if notification.order_id:
        lines.append(f"Order: {notification.order.public_id}")

    return "\n".join(lines)


@shared_task(bind=True)
def deliver_notification_email_task(self, notification_id):
    with transaction.atomic():
        try:
            notification = (
                Notification.objects.select_for_update(of=("self",))
                .get(id=notification_id)
            )
        except Notification.DoesNotExist:
            return False

        notification = (
            Notification.objects.select_related("user", "order")
            .get(id=notification.id)
        )

        notification.delivery_attempts += 1

        recipient_email = notification.user.email

        if not recipient_email:
            notification.delivery_status = (
                Notification.DeliveryStatus.SKIPPED
            )
            notification.delivery_error = "User has no email address."
            notification.save(
                update_fields=(
                    "delivery_status",
                    "delivery_attempts",
                    "delivery_error",
                )
            )
            return False

        try:
            send_mail(
                subject=notification.title,
                message=build_notification_email_message(notification),
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[recipient_email],
                fail_silently=False,
            )
        except Exception as error:
            notification.delivery_status = (
                Notification.DeliveryStatus.FAILED
            )
            notification.delivery_error = str(error)
            notification.save(
                update_fields=(
                    "delivery_status",
                    "delivery_attempts",
                    "delivery_error",
                )
            )
            return False

        notification.delivery_status = Notification.DeliveryStatus.SENT
        notification.delivered_at = timezone.now()
        notification.delivery_error = ""
        notification.save(
            update_fields=(
                "delivery_status",
                "delivery_attempts",
                "delivered_at",
                "delivery_error",
            )
        )

    return True