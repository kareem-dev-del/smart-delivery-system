from decimal import Decimal
from uuid import uuid4

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
    LockerDeviceRequest,
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

    def deposit_url(self, public_id=None):
        return reverse(
            "order-deposit",
            kwargs={
                "public_id": public_id or self.order.public_id,
            },
        )


    def post_deposit(self, *, idempotency_key=None, public_id=None):
        return self.client.post(
            self.deposit_url(public_id=public_id),
            HTTP_IDEMPOTENCY_KEY=str(idempotency_key or uuid4()),
        )


    def create_assigned_order(self, *, drawer):
        order = create_order(
            customer=self.customer,
            items=[
                {"product_id": self.product.id, "quantity": 1},
            ],
        )

        return assign_order_to_drawer(
            order_public_id=order.public_id,
            locker_station_id=self.locker.id,
            drawer_id=drawer.id,
        )

    def test_unauthenticated_user_cannot_confirm_deposit(self):
        response = self.client.post(self.deposit_url())

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_customer_cannot_confirm_deposit(self):
        self.client.force_authenticate(user=self.customer)

        response = self.post_deposit()

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_device_cannot_confirm_deposit_for_another_locker(self):
        self.client.force_authenticate(user=self.other_device_user)

        response = self.post_deposit()

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

        self.order.refresh_from_db()
        self.drawer.refresh_from_db()

        self.assertEqual(self.order.status, Order.Status.ASSIGNED)
        self.assertEqual(self.drawer.status, Drawer.Status.RESERVED)

    def test_correct_device_confirms_package_deposit(self):
        self.client.force_authenticate(user=self.device_user)

        response = self.post_deposit()

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

    def test_device_must_send_an_idempotency_key(self):
        self.client.force_authenticate(user=self.device_user)

        response = self.client.post(self.deposit_url())

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("idempotency_key", response.data)


    def test_same_idempotency_key_replays_deposit_result(self):
        self.client.force_authenticate(user=self.device_user)
        idempotency_key = uuid4()

        first_response = self.post_deposit(
            idempotency_key=idempotency_key,
        )
        second_response = self.post_deposit(
            idempotency_key=idempotency_key,
        )

        self.assertEqual(first_response.status_code, status.HTTP_200_OK)
        self.assertEqual(second_response.status_code, status.HTTP_200_OK)
        self.assertEqual(first_response.data, second_response.data)

        self.assertEqual(
            LockerDeviceRequest.objects.filter(
                locker_device__user=self.device_user,
            ).count(),
            1,
        )
        self.assertEqual(
            LockerEventLog.objects.filter(
                order=self.order,
                event_type=LockerEventLog.EventType.PACKAGE_DEPOSITED,
            ).count(),
            1,
        )


    def test_new_key_cannot_repeat_completed_deposit(self):
        self.client.force_authenticate(user=self.device_user)

        first_response = self.post_deposit()
        second_response = self.post_deposit()

        self.assertEqual(first_response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            second_response.status_code,
            status.HTTP_400_BAD_REQUEST,
        )

    def test_same_key_cannot_be_reused_for_another_order(self):
        self.client.force_authenticate(user=self.device_user)

        second_drawer = Drawer.objects.create(
            locker_station=self.locker,
            number=2,
            size=Drawer.Size.SMALL,
            status=Drawer.Status.AVAILABLE,
        )
        second_order = self.create_assigned_order(
            drawer=second_drawer,
        )
        idempotency_key = uuid4()

        first_response = self.post_deposit(
            idempotency_key=idempotency_key,
        )
        conflict_response = self.post_deposit(
            idempotency_key=idempotency_key,
            public_id=second_order.public_id,
        )

        self.assertEqual(first_response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            conflict_response.status_code,
            status.HTTP_409_CONFLICT,
        )

        second_order.refresh_from_db()
        second_drawer.refresh_from_db()

        self.assertEqual(second_order.status, Order.Status.ASSIGNED)
        self.assertEqual(second_drawer.status, Drawer.Status.RESERVED)
