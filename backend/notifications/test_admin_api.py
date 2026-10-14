from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import UserProfile

from .models import Notification


User = get_user_model()


class AdminNotificationListAPIViewTests(APITestCase):
    def setUp(self):
        self.admin = User.objects.create_user(
            username="admin",
            password="test-password",
            is_staff=True,
        )
        self.admin.profile.role = UserProfile.Role.ADMIN
        self.admin.profile.save(update_fields=("role",))

        self.customer = User.objects.create_user(
            username="customer",
            password="test-password",
        )
        self.other_customer = User.objects.create_user(
            username="other-customer",
            password="test-password",
        )

        self.pending_notification = Notification.objects.create(
            user=self.customer,
            notification_type=Notification.Type.ORDER_READY_FOR_PICKUP,
            title="Order ready",
            message="Your order is ready for pickup.",
            delivery_status=Notification.DeliveryStatus.PENDING,
        )
        self.failed_notification = Notification.objects.create(
            user=self.other_customer,
            notification_type=Notification.Type.ORDER_PICKUP_EXPIRED,
            title="Order expired",
            message="Your pickup window expired.",
            delivery_status=Notification.DeliveryStatus.FAILED,
            delivery_error="SMTP is unavailable.",
        )

    def test_unauthenticated_and_non_admin_users_cannot_list_all_notifications(
        self,
    ):
        response = self.client.get(
            reverse("admin-notification-list"),
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_401_UNAUTHORIZED,
        )

        self.client.force_authenticate(user=self.customer)

        response = self.client.get(
            reverse("admin-notification-list"),
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_403_FORBIDDEN,
        )

    def test_admin_can_list_all_notifications_with_recipient_details(self):
        self.client.force_authenticate(user=self.admin)

        response = self.client.get(
            reverse("admin-notification-list"),
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["count"], 2)

        notifications_by_id = {
            notification["id"]: notification
            for notification in response.data["results"]
        }

        pending = notifications_by_id[self.pending_notification.id]
        self.assertEqual(pending["recipient"], self.customer.id)
        self.assertEqual(pending["recipient_username"], "customer")
        self.assertEqual(
            pending["delivery_status"],
            Notification.DeliveryStatus.PENDING,
        )

        failed = notifications_by_id[self.failed_notification.id]
        self.assertEqual(failed["recipient"], self.other_customer.id)
        self.assertEqual(
            failed["delivery_status"],
            Notification.DeliveryStatus.FAILED,
        )

    def test_admin_can_filter_notifications_by_delivery_status_and_type(self):
        self.client.force_authenticate(user=self.admin)

        response = self.client.get(
            reverse("admin-notification-list"),
            {
                "delivery_status": Notification.DeliveryStatus.FAILED,
                "notification_type": (
                    Notification.Type.ORDER_PICKUP_EXPIRED
                ),
            },
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["count"], 1)
        self.assertEqual(
            response.data["results"][0]["id"],
            self.failed_notification.id,
        )

    def test_invalid_admin_notification_filter_is_rejected(self):
        self.client.force_authenticate(user=self.admin)

        response = self.client.get(
            reverse("admin-notification-list"),
            {"delivery_status": "not-a-status"},
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_400_BAD_REQUEST,
        )
        self.assertIn("delivery_status", response.data)