from datetime import timedelta
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.urls import reverse
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import UserProfile
from lockers.models import (
    Drawer,
    LockerDevice,
    LockerEventLog,
    LockerStation,
)
from orders.models import Order, QRToken
from orders.services import (
    authorize_pickup_by_qr,
    issue_pickup_qr_token,
)


User = get_user_model()


class LockerCollectionConfirmationAPIViewTests(APITestCase):
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
            number=3,
            size=Drawer.Size.SMALL,
            status=Drawer.Status.OCCUPIED,
        )

        self.order = Order.objects.create(
            customer=self.customer,
            status=Order.Status.READY_FOR_PICKUP,
            locker_station=self.locker,
            assigned_drawer=self.drawer,
            total_amount=Decimal("20.00"),
            delivery_deadline=timezone.now() + timedelta(hours=48),
        )

        _, raw_token = issue_pickup_qr_token(
            order_public_id=self.order.public_id,
            customer=self.customer,
        )

        authorize_pickup_by_qr(
            raw_token=raw_token,
            device_user=self.device_user,
        )

        self.order.refresh_from_db()

    def confirm_url(self):
        return reverse(
            "locker-confirm-collection",
            kwargs={"public_id": self.order.public_id},
        )

    def test_unauthenticated_user_cannot_confirm_collection(self):
        response = self.client.post(self.confirm_url())

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_customer_cannot_confirm_collection(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.post(self.confirm_url())

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_other_locker_device_cannot_confirm_collection(self):
        self.client.force_authenticate(user=self.other_device_user)

        response = self.client.post(self.confirm_url())

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

        self.order.refresh_from_db()
        self.drawer.refresh_from_db()

        self.assertEqual(
            self.order.status,
            Order.Status.READY_FOR_PICKUP,
        )
        self.assertEqual(self.drawer.status, Drawer.Status.OCCUPIED)

    def test_correct_device_confirms_collection_and_releases_drawer(self):
        _, unused_raw_token = issue_pickup_qr_token(
            order_public_id=self.order.public_id,
            customer=self.customer,
        )

        unused_qr_token = QRToken.objects.get(
            token_hash__isnull=False,
            order=self.order,
            used_at__isnull=True,
            revoked_at__isnull=True,
        )

        self.client.force_authenticate(user=self.device_user)

        response = self.client.post(self.confirm_url())

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            response.data["status"],
            Order.Status.COLLECTED,
        )
        self.assertEqual(response.data["drawer_number"], 3)
        self.assertEqual(
            response.data["drawer_status"],
            Drawer.Status.AVAILABLE,
        )
        self.assertIsNotNone(response.data["collected_at"])

        self.order.refresh_from_db()
        self.drawer.refresh_from_db()
        unused_qr_token.refresh_from_db()

        self.assertEqual(self.order.status, Order.Status.COLLECTED)
        self.assertIsNotNone(self.order.collected_at)
        self.assertEqual(self.drawer.status, Drawer.Status.AVAILABLE)
        self.assertIsNotNone(unused_qr_token.revoked_at)

        event_types = set(
            LockerEventLog.objects.filter(order=self.order).values_list(
                "event_type",
                flat=True,
            )
        )

        self.assertIn(
            LockerEventLog.EventType.PACKAGE_COLLECTED,
            event_types,
        )
        self.assertIn(
            LockerEventLog.EventType.DRAWER_RELEASED,
            event_types,
        )

    def test_cannot_confirm_collection_before_qr_scan(self):
        self.order.pickup_opened_at = None
        self.order.save(update_fields=("pickup_opened_at",))

        self.client.force_authenticate(user=self.device_user)

        response = self.client.post(self.confirm_url())

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

        self.order.refresh_from_db()
        self.assertEqual(
            self.order.status,
            Order.Status.READY_FOR_PICKUP,
        )

    def test_collection_cannot_be_confirmed_twice(self):
        self.client.force_authenticate(user=self.device_user)

        first_response = self.client.post(self.confirm_url())
        second_response = self.client.post(self.confirm_url())

        self.assertEqual(first_response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            second_response.status_code,
            status.HTTP_400_BAD_REQUEST,
        )