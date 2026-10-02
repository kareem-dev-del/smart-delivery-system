from decimal import Decimal

from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import UserProfile
from lockers.models import Drawer, LockerStation

from .models import Order


User = get_user_model()


class OrderResponseSecurityAPIViewTests(APITestCase):
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

        self.admin_user.profile.role = UserProfile.Role.ADMIN
        self.admin_user.profile.save(update_fields=("role",))

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

        self.drawer = Drawer.objects.create(
            locker_station=self.locker,
            number=3,
            size=Drawer.Size.SMALL,
            status=Drawer.Status.RESERVED,
        )

        self.order = Order.objects.create(
            customer=self.customer,
            assigned_courier=self.courier,
            status=Order.Status.ASSIGNED,
            locker_station=self.locker,
            assigned_drawer=self.drawer,
            total_amount=Decimal("20.00"),
        )

    def detail_url(self):
        return reverse(
            "order-detail",
            kwargs={"public_id": self.order.public_id},
        )

    def test_customer_does_not_receive_internal_drawer_or_courier_data(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.get(self.detail_url())

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["locker"]["code"], "NASR-001")

        self.assertNotIn("assigned_drawer", response.data)
        self.assertNotIn("assigned_drawer_number", response.data)
        self.assertNotIn("assigned_courier", response.data)
        self.assertNotIn("assigned_courier_username", response.data)
        self.assertNotIn("pickup_opened_at", response.data)
        self.assertNotIn("return_opened_at", response.data)

    def test_admin_receives_operational_order_data(self):
        self.client.force_authenticate(user=self.admin_user)

        response = self.client.get(self.detail_url())

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["customer"], self.customer.id)
        self.assertEqual(response.data["customer_username"], "customer")
        self.assertEqual(response.data["assigned_courier"], self.courier.id)
        self.assertEqual(
            response.data["assigned_courier_username"],
            "courier-one",
        )
        self.assertEqual(response.data["locker_station"], self.locker.id)
        self.assertEqual(response.data["assigned_drawer"], self.drawer.id)
        self.assertEqual(response.data["assigned_drawer_number"], 3)
        self.assertIn("pickup_opened_at", response.data)
        self.assertIn("return_opened_at", response.data)