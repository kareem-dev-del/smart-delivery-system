from celery import shared_task
from django.conf import settings
from django.core.mail import send_mail

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


@shared_task(
    bind=True,
    autoretry_for=(Exception,),
    retry_backoff=True,
    retry_kwargs={"max_retries": 3},
)
def deliver_notification_email_task(self, notification_id):
    try:
        notification = (
            Notification.objects.select_related("user", "order")
            .get(id=notification_id)
        )
    except Notification.DoesNotExist:
        return False

    recipient_email = notification.user.email

    if not recipient_email:
        return False

    send_mail(
        subject=notification.title,
        message=build_notification_email_message(notification),
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=[recipient_email],
        fail_silently=False,
    )

    return True