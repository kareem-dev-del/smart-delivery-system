from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import UserProfile
from lockers.models import LockerStation

from .models import Order


User = get_user_model()


class AdminOrderListAPIViewTests(APITestCase):
    def setUp(self):
        self.admin = User.objects.create_user(
            username="admin",
            password="test-password",
            is_staff=True,
        )
        self.admin.profile.role = UserProfile.Role.ADMIN
        self.admin.profile.save(update_fields=("role",))

        self.customer = User.objects.create_user(
            username="customer-one",
            password="test-password",
        )
        self.customer.profile.role = UserProfile.Role.CUSTOMER
        self.customer.profile.save(update_fields=("role",))

        self.courier = User.objects.create_user(
            username="courier-one",
            password="test-password",
        )
        self.courier.profile.role = UserProfile.Role.COURIER
        self.courier.profile.save(update_fields=("role",))

        self.locker = LockerStation.objects.create(
            name="Nasr City Locker",
            code="NASR-001",
            address="Nasr City, Cairo",
            latitude="30.062630",
            longitude="31.335220",
            status=LockerStation.Status.ONLINE,
        )

        self.ready_order = Order.objects.create(
            customer=self.customer,
            assigned_courier=self.courier,
            locker_station=self.locker,
            status=Order.Status.READY_FOR_PICKUP,
        )

        self.awaiting_order = Order.objects.create(
            customer=self.customer,
            status=Order.Status.AWAITING_LOCKER,
        )

    def test_non_admin_cannot_access_admin_orders(self):
        response = self.client.get(reverse("admin-order-list"))

        self.assertEqual(
            response.status_code,
            status.HTTP_401_UNAUTHORIZED,
        )

        self.client.force_authenticate(user=self.customer)

        response = self.client.get(reverse("admin-order-list"))

        self.assertEqual(
            response.status_code,
            status.HTTP_403_FORBIDDEN,
        )

    def test_admin_can_filter_orders_by_status_and_locker(self):
        self.client.force_authenticate(user=self.admin)

        response = self.client.get(
            reverse("admin-order-list"),
            {
                "status": Order.Status.READY_FOR_PICKUP,
                "locker_station_id": self.locker.id,
            },
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["count"], 1)
        self.assertEqual(
            response.data["results"][0]["public_id"],
            str(self.ready_order.public_id),
        )
        self.assertEqual(
            response.data["results"][0]["customer_username"],
            "customer-one",
        )

    def test_admin_can_search_by_username_and_public_id(self):
        self.client.force_authenticate(user=self.admin)

        username_response = self.client.get(
            reverse("admin-order-list"),
            {"search": "customer-one"},
        )

        self.assertEqual(username_response.status_code, status.HTTP_200_OK)
        self.assertEqual(username_response.data["count"], 2)

        order_response = self.client.get(
            reverse("admin-order-list"),
            {"search": str(self.ready_order.public_id)},
        )

        self.assertEqual(order_response.status_code, status.HTTP_200_OK)
        self.assertEqual(order_response.data["count"], 1)
        self.assertEqual(
            order_response.data["results"][0]["public_id"],
            str(self.ready_order.public_id),
        )

    def test_invalid_status_filter_is_rejected(self):
        self.client.force_authenticate(user=self.admin)

        response = self.client.get(
            reverse("admin-order-list"),
            {"status": "invalid-status"},
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_400_BAD_REQUEST,
        )
        self.assertIn("status", response.data)