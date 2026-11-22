from celery import shared_task
from django.conf import settings
from django.core.mail import send_mail
from django.db import transaction
from django.utils import timezone
import json
import logging
import os

from .models import Notification
from .models import PushDevice

logger = logging.getLogger(__name__)


def _firebase_messaging():
    service_account_json = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON", "").strip()
    if not service_account_json:
        return None

    import firebase_admin
    from firebase_admin import credentials, messaging

    try:
        app = firebase_admin.get_app("smartdrop-push")
    except ValueError:
        credential = credentials.Certificate(json.loads(service_account_json))
        app = firebase_admin.initialize_app(credential, name="smartdrop-push")
    return messaging, app


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


@shared_task(bind=True)
def deliver_notification_push_task(self, notification_id):
    try:
        notification = Notification.objects.select_related("user", "order").get(
            id=notification_id
        )
    except Notification.DoesNotExist:
        return False

    firebase = _firebase_messaging()
    if firebase is None:
        logger.info("Skipping FCM delivery; Firebase service account is not configured.")
        return False

    messaging, app = firebase
    tokens = list(
        PushDevice.objects.filter(user=notification.user).values_list("id", "token")
    )
    if not tokens:
        return False

    data = {str(key): str(value) for key, value in notification.data.items()}
    data.update(
        {
            "notification_id": str(notification.id),
            "notification_type": notification.notification_type,
            "role": notification.user.profile.role,
        }
    )
    if notification.order_id:
        data["order_public_id"] = str(notification.order.public_id)

    stale_device_ids = []
    for device_id, token in tokens:
        try:
            messaging.send(
                messaging.Message(
                    token=token,
                    notification=messaging.Notification(
                        title=notification.title,
                        body=notification.message[:200],
                    ),
                    data=data,
                    android=messaging.AndroidConfig(
                        priority="high",
                        notification=messaging.AndroidNotification(
                            channel_id="smartdrop_order_updates"
                        ),
                    ),
                ),
                app=app,
            )
        except messaging.UnregisteredError:
            stale_device_ids.append(device_id)
        except Exception:
            logger.exception("FCM delivery failed for notification %s", notification_id)

    if stale_device_ids:
        PushDevice.objects.filter(id__in=stale_device_ids).delete()
    return True
