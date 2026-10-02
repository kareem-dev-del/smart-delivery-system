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
from orders.services import hash_qr_token, issue_return_qr_token


User = get_user_model()


class LockerReturnScanAPIViewTests(APITestCase):
    def setUp(self):
        self.customer = User.objects.create_user(
            username="customer",
            password="test-password",
        )

        self.courier = User.objects.create_user(
            username="courier-one",
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

        self.courier.profile.role = UserProfile.Role.COURIER
        self.courier.profile.save(update_fields=("role",))

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
            status=Drawer.Status.RETURN_PENDING,
        )

        self.order = Order.objects.create(
            customer=self.customer,
            assigned_courier=self.courier,
            status=Order.Status.EXPIRED,
            locker_station=self.locker,
            assigned_drawer=self.drawer,
            total_amount=Decimal("20.00"),
        )

        self.qr_token, self.raw_token = issue_return_qr_token(
            order_public_id=self.order.public_id,
            courier=self.courier,
        )

    def scan_url(self):
        return reverse("locker-return-scan")

    def test_unauthenticated_user_cannot_scan_return_qr(self):
        response = self.client.post(
            self.scan_url(),
            {"token": self.raw_token},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_customer_cannot_scan_return_qr_as_locker_device(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.post(
            self.scan_url(),
            {"token": self.raw_token},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_correct_locker_device_can_open_return_drawer(self):
        self.client.force_authenticate(user=self.device_user)

        response = self.client.post(
            self.scan_url(),
            {"token": self.raw_token},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["command"], "open_drawer")
        self.assertEqual(response.data["drawer_number"], 3)
        self.assertEqual(
            response.data["order_public_id"],
            str(self.order.public_id),
        )
        self.assertEqual(response["Cache-Control"], "no-store")

        self.qr_token.refresh_from_db()
        self.order.refresh_from_db()
        self.drawer.refresh_from_db()

        self.assertIsNotNone(self.qr_token.used_at)
        self.assertIsNotNone(self.order.return_opened_at)
        self.assertEqual(self.order.status, Order.Status.EXPIRED)
        self.assertEqual(
            self.drawer.status,
            Drawer.Status.RETURN_PENDING,
        )

        self.assertTrue(
            LockerEventLog.objects.filter(
                order=self.order,
                event_type=LockerEventLog.EventType.RETURN_OPENED,
            ).exists()
        )

    def test_other_locker_device_cannot_open_return_drawer(self):
        self.client.force_authenticate(user=self.other_device_user)

        response = self.client.post(
            self.scan_url(),
            {"token": self.raw_token},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

        self.qr_token.refresh_from_db()
        self.assertIsNone(self.qr_token.used_at)

    def test_return_qr_cannot_be_scanned_twice(self):
        self.client.force_authenticate(user=self.device_user)

        first_response = self.client.post(
            self.scan_url(),
            {"token": self.raw_token},
            format="json",
        )

        second_response = self.client.post(
            self.scan_url(),
            {"token": self.raw_token},
            format="json",
        )

        self.assertEqual(first_response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            second_response.status_code,
            status.HTTP_400_BAD_REQUEST,
        )

        self.assertEqual(
            LockerEventLog.objects.filter(
                order=self.order,
                event_type=LockerEventLog.EventType.RETURN_OPENED,
            ).count(),
            1,
        )

    def test_customer_pickup_qr_cannot_be_used_for_return_scan(self):
        raw_token = "customer-pickup-token-for-return-test-12345"

        QRToken.objects.create(
            order=self.order,
            purpose=QRToken.Purpose.CUSTOMER_PICKUP,
            token_hash=hash_qr_token(raw_token),
            expires_at=timezone.now() + timedelta(minutes=10),
        )

        self.client.force_authenticate(user=self.device_user)

        response = self.client.post(
            self.scan_url(),
            {"token": raw_token},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)