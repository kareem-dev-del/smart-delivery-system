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

    def test_email_delivery_task_ignores_missing_notification(self):
        result = deliver_notification_email_task(999999)

        self.assertFalse(result)