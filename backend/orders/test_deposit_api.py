from decimal import Decimal

from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import UserProfile
from lockers.models import (
    Drawer,
    LockerDevice,
    LockerEventLog,
    LockerStation,
)
from products.models import Product

from .models import Order
from .services import assign_order_to_drawer, create_order


User = get_user_model()


class OrderDepositAPIViewTests(APITestCase):
    def setUp(self):
        self.customer = User.objects.create_user(
            username="customer",
            password="test-password",
        )

        self.device_user = User.objects.create_user(
            username="locker-nasr-001",
            password="test-password",
        )

        self.other_device_user = User.objects.create_user(
            username="locker-maadi-001",
            password="test-password",
        )

        self.device_user.profile.role = UserProfile.Role.LOCKER_DEVICE
        self.device_user.profile.save(update_fields=("role",))

        self.other_device_user.profile.role = UserProfile.Role.LOCKER_DEVICE
        self.other_device_user.profile.save(update_fields=("role",))

        self.product = Product.objects.create(
            name="USB Cable",
            price=Decimal("20.00"),
            stock=20,
            size=Product.Size.SMALL,
        )

        self.locker = LockerStation.objects.create(
            name="Nasr City Locker",
            code="NASR-001",
            address="Nasr City, Cairo",
            latitude="30.062630",
            longitude="31.335220",
            status=LockerStation.Status.ONLINE,
        )

        self.other_locker = LockerStation.objects.create(
            name="Maadi Locker",
            code="MAADI-001",
            address="Maadi, Cairo",
            latitude="29.960235",
            longitude="31.256540",
            status=LockerStation.Status.ONLINE,
        )

        LockerDevice.objects.create(
            locker_station=self.locker,
            user=self.device_user,
            device_code="nasr-001-controller",
        )

        LockerDevice.objects.create(
            locker_station=self.other_locker,
            user=self.other_device_user,
            device_code="maadi-001-controller",
        )

        self.drawer = Drawer.objects.create(
            locker_station=self.locker,
            number=1,
            size=Drawer.Size.SMALL,
            status=Drawer.Status.AVAILABLE,
        )

        order = create_order(
            customer=self.customer,
            items=[
                {"product_id": self.product.id, "quantity": 1},
            ],
        )

        self.order = assign_order_to_drawer(
            order_public_id=order.public_id,
            locker_station_id=self.locker.id,
            drawer_id=self.drawer.id,
        )

    def deposit_url(self):
        return reverse(
            "order-deposit",
            kwargs={"public_id": self.order.public_id},
        )

    def test_unauthenticated_user_cannot_confirm_deposit(self):
        response = self.client.post(self.deposit_url())

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_customer_cannot_confirm_deposit(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.post(self.deposit_url())

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_device_cannot_confirm_deposit_for_another_locker(self):
        self.client.force_authenticate(user=self.other_device_user)

        response = self.client.post(self.deposit_url())

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

        self.order.refresh_from_db()
        self.drawer.refresh_from_db()

        self.assertEqual(self.order.status, Order.Status.ASSIGNED)
        self.assertEqual(self.drawer.status, Drawer.Status.RESERVED)

    def test_correct_device_confirms_package_deposit(self):
        self.client.force_authenticate(user=self.device_user)

        response = self.client.post(self.deposit_url())

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            response.data["status"],
            Order.Status.READY_FOR_PICKUP,
        )
        self.assertIsNotNone(response.data["ready_for_pickup_at"])
        self.assertIsNotNone(response.data["delivery_deadline"])

        self.order.refresh_from_db()
        self.drawer.refresh_from_db()

        self.assertEqual(
            self.order.status,
            Order.Status.READY_FOR_PICKUP,
        )
        self.assertEqual(self.drawer.status, Drawer.Status.OCCUPIED)

        event_types = set(
            LockerEventLog.objects.filter(order=self.order).values_list(
                "event_type",
                flat=True,
            )
        )

        self.assertIn(
            LockerEventLog.EventType.DRAWER_RESERVED,
            event_types,
        )
        self.assertIn(
            LockerEventLog.EventType.PACKAGE_DEPOSITED,
            event_types,
        )

    def test_device_cannot_confirm_deposit_twice(self):
        self.client.force_authenticate(user=self.device_user)

        first_response = self.client.post(self.deposit_url())
        second_response = self.client.post(self.deposit_url())

        self.assertEqual(first_response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            second_response.status_code,
            status.HTTP_400_BAD_REQUEST,
        )