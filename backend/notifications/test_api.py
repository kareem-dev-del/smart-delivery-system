from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from .models import Notification


User = get_user_model()


class NotificationAPIViewTests(APITestCase):
    def setUp(self):
        self.customer = User.objects.create_user(
            username="customer",
            password="test-password",
        )
        self.other_customer = User.objects.create_user(
            username="other-customer",
            password="test-password",
        )

        self.own_notification = Notification.objects.create(
            user=self.customer,
            notification_type=Notification.Type.ORDER_READY_FOR_PICKUP,
            title="Order ready",
            message="Your order is ready.",
        )
        self.other_notification = Notification.objects.create(
            user=self.other_customer,
            notification_type=Notification.Type.ORDER_PICKUP_EXPIRED,
            title="Order expired",
            message="Your pickup window expired.",
        )

    def test_unauthenticated_user_cannot_list_notifications(self):
        response = self.client.get(reverse("notification-list"))

        self.assertEqual(
            response.status_code,
            status.HTTP_401_UNAUTHORIZED,
        )

    def test_user_sees_only_own_unread_notifications(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.get(
            reverse("notification-list"),
            {"unread": "true"},
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["count"], 1)
        self.assertEqual(
            response.data["results"][0]["id"],
            self.own_notification.id,
        )

    def test_user_can_mark_own_notification_as_read(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.post(
            reverse(
                "notification-mark-read",
                kwargs={"pk": self.own_notification.id},
            )
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data["is_read"])

        self.own_notification.refresh_from_db()
        self.assertIsNotNone(self.own_notification.read_at)

    def test_user_cannot_mark_another_users_notification_as_read(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.post(
            reverse(
                "notification-mark-read",
                kwargs={"pk": self.other_notification.id},
            )
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_404_NOT_FOUND,
        )

    def test_user_can_mark_all_notifications_as_read(self):
        Notification.objects.create(
            user=self.customer,
            notification_type=Notification.Type.ORDER_PICKUP_EXPIRED,
            title="Another notification",
            message="Another message.",
        )

        self.client.force_authenticate(user=self.customer)

        response = self.client.post(
            reverse("notification-mark-all-read")
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["updated_count"], 2)