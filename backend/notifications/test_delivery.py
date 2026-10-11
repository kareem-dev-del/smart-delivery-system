from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.core import mail
from django.test import TestCase, override_settings

from .models import Notification
from .services import create_notification
from .tasks import deliver_notification_email_task


User = get_user_model()


class NotificationDeliveryTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="customer",
            email="customer@example.com",
            password="test-password",
        )

    @patch("notifications.services.deliver_notification_email_task")
    def test_create_notification_enqueues_email_delivery_after_commit(
        self,
        mocked_task,
    ):
        with self.captureOnCommitCallbacks(execute=True):
            notification = create_notification(
                user=self.user,
                notification_type=Notification.Type.ORDER_READY_FOR_PICKUP,
                title="Order ready",
                message="Your order is ready for pickup.",
            )

        self.assertEqual(notification.user, self.user)
        mocked_task.delay.assert_called_once_with(notification.id)
    @override_settings(
        EMAIL_BACKEND="django.core.mail.backends.locmem.EmailBackend",
        DEFAULT_FROM_EMAIL="Smart Delivery <no-reply@example.com>",
    )
    def test_email_delivery_task_sends_notification_email(self):
        notification = Notification.objects.create(
            user=self.user,
            notification_type=Notification.Type.ORDER_READY_FOR_PICKUP,
            title="Order ready",
            message="Your order is ready for pickup.",
        )

        result = deliver_notification_email_task(notification.id)

        self.assertTrue(result)
        self.assertEqual(len(mail.outbox), 1)
        self.assertEqual(mail.outbox[0].subject, "Order ready")
        self.assertEqual(mail.outbox[0].to, ["customer@example.com"])
        self.assertIn(
            "Your order is ready for pickup.",
            mail.outbox[0].body,
        )

        notification.refresh_from_db()
        self.assertEqual(
            notification.delivery_status,
            Notification.DeliveryStatus.SENT,
        )
        self.assertEqual(notification.delivery_attempts, 1)
        self.assertIsNotNone(notification.delivered_at)
        self.assertEqual(notification.delivery_error, "")

    def test_email_delivery_task_skips_users_without_email(self):
        self.user.email = ""
        self.user.save(update_fields=("email",))

        notification = Notification.objects.create(
            user=self.user,
            notification_type=Notification.Type.ORDER_READY_FOR_PICKUP,
            title="Order ready",
            message="Your order is ready for pickup.",
        )

        result = deliver_notification_email_task(notification.id)

        self.assertFalse(result)

        notification.refresh_from_db()
        self.assertEqual(
            notification.delivery_status,
            Notification.DeliveryStatus.SKIPPED,
        )
        self.assertEqual(notification.delivery_attempts, 1)
        self.assertEqual(
            notification.delivery_error,
            "User has no email address.",
        )

    def test_email_delivery_task_ignores_missing_notification(self):
        result = deliver_notification_email_task(999999)

        self.assertFalse(result)


    @patch("notifications.tasks.send_mail")
    def test_email_delivery_task_marks_notification_as_failed(
        self,
        mocked_send_mail,
    ):
        mocked_send_mail.side_effect = RuntimeError("SMTP is down")

        notification = Notification.objects.create(
            user=self.user,
            notification_type=Notification.Type.ORDER_READY_FOR_PICKUP,
            title="Order ready",
            message="Your order is ready for pickup.",
        )

        result = deliver_notification_email_task(notification.id)

        self.assertFalse(result)
        notification.refresh_from_db()
        self.assertEqual(
            notification.delivery_status,
            Notification.DeliveryStatus.FAILED,
        )
        self.assertEqual(notification.delivery_attempts, 1)
        self.assertIn("SMTP is down", notification.delivery_error)