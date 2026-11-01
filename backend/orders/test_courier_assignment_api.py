from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import UserProfile

from .models import Order


User = get_user_model()


class OrderCourierAssignmentAPIViewTests(APITestCase):
    def setUp(self):
        self.customer = User.objects.create_user(
            username="customer",
            password="test-password",
        )

        self.admin_user = User.objects.create_user(
            username="admin",
            password="test-password",
            is_staff=True,
        )

        self.courier = User.objects.create_user(
            username="courier-one",
            password="test-password",
        )

        self.non_courier = User.objects.create_user(
            username="another-customer",
            password="test-password",
        )

        self.admin_user.profile.role = UserProfile.Role.ADMIN
        self.admin_user.profile.save(update_fields=("role",))

        self.courier.profile.role = UserProfile.Role.COURIER
        self.courier.profile.is_on_shift = True
        self.courier.profile.save(update_fields=("role", "is_on_shift"))

        self.order = Order.objects.create(
            customer=self.customer,
            status=Order.Status.AWAITING_LOCKER,
        )

    def assignment_url(self):
        return reverse(
            "order-assign-courier",
            kwargs={"public_id": self.order.public_id},
        )

    def test_admin_can_assign_courier_to_order(self):
        self.client.force_authenticate(user=self.admin_user)

        response = self.client.post(
            self.assignment_url(),
            {"courier_id": self.courier.id},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["courier_id"], self.courier.id)
        self.assertEqual(
            response.data["courier_username"],
            "courier-one",
        )

        self.order.refresh_from_db()

        self.assertEqual(self.order.assigned_courier, self.courier)
        self.assertIsNotNone(self.order.courier_assigned_at)

    def test_customer_cannot_assign_courier(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.post(
            self.assignment_url(),
            {"courier_id": self.courier.id},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_admin_cannot_assign_non_courier_user(self):
        self.client.force_authenticate(user=self.admin_user)

        response = self.client.post(
            self.assignment_url(),
            {"courier_id": self.non_courier.id},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

        self.order.refresh_from_db()
        self.assertIsNone(self.order.assigned_courier)

    def test_admin_cannot_assign_courier_after_collection(self):
        self.order.status = Order.Status.COLLECTED
        self.order.save(update_fields=("status",))

        self.client.force_authenticate(user=self.admin_user)

        response = self.client.post(
            self.assignment_url(),
            {"courier_id": self.courier.id},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_admin_cannot_assign_courier_who_is_off_shift(self):
        self.courier.profile.is_on_shift = False
        self.courier.profile.save(update_fields=("is_on_shift",))
        self.client.force_authenticate(user=self.admin_user)

        response = self.client.post(self.assignment_url(), {"courier_id": self.courier.id}, format="json")

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("not on shift", str(response.data).lower())

    def test_admin_cannot_assign_courier_with_another_active_order(self):
        Order.objects.create(
            customer=self.customer,
            status=Order.Status.ASSIGNED,
            assigned_courier=self.courier,
        )
        self.client.force_authenticate(user=self.admin_user)

        response = self.client.post(self.assignment_url(), {"courier_id": self.courier.id}, format="json")

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("active order", str(response.data).lower())
        self.assertIsNone(Order.objects.get(pk=self.order.pk).assigned_courier)

    def test_reassigning_order_to_same_courier_is_idempotent(self):
        self.order.assigned_courier = self.courier
        self.order.save(update_fields=("assigned_courier",))
        self.client.force_authenticate(user=self.admin_user)

        response = self.client.post(self.assignment_url(), {"courier_id": self.courier.id}, format="json")

        self.assertEqual(response.status_code, status.HTTP_200_OK)
