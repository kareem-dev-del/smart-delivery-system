from datetime import timedelta
from decimal import Decimal

from uuid import uuid4

from django.test import override_settings

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
    LockerDeviceRequest,
)
from orders.models import Order, QRToken
from orders.services import issue_pickup_qr_token


User = get_user_model()


class LockerPickupScanAPIViewTests(APITestCase):
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

        self.qr_token, self.raw_token = issue_pickup_qr_token(
            order_public_id=self.order.public_id,
            customer=self.customer,
        )

    def scan_url(self):
        return reverse("locker-pickup-scan")

    def post_scan(self, *, raw_token=None, idempotency_key=None):
        return self.client.post(
            self.scan_url(),
            {"token": raw_token or self.raw_token},
            format="json",
            HTTP_IDEMPOTENCY_KEY=str(idempotency_key or uuid4()),
        )

    def test_unauthenticated_user_cannot_scan_qr(self):
        response = self.client.post(
            self.scan_url(),
            {"token": self.raw_token},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_customer_cannot_scan_qr_as_a_locker_device(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.post(
            self.scan_url(),
            {"token": self.raw_token},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_correct_locker_device_can_authorize_drawer_opening(self):
        self.client.force_authenticate(user=self.device_user)

        response = self.post_scan()

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
        self.assertEqual(
            self.order.status,
            Order.Status.READY_FOR_PICKUP,
        )
        self.assertEqual(self.drawer.status, Drawer.Status.OCCUPIED)

        self.assertTrue(
            LockerEventLog.objects.filter(
                order=self.order,
                event_type=LockerEventLog.EventType.PICKUP_OPENED,
            ).exists()
        )

    def test_other_locker_device_cannot_open_order_drawer(self):
        self.client.force_authenticate(user=self.other_device_user)

        response = self.post_scan()

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

        self.qr_token.refresh_from_db()
        self.assertIsNone(self.qr_token.used_at)

    def test_same_idempotency_key_replays_open_drawer_command(self):
        self.client.force_authenticate(user=self.device_user)
        idempotency_key = uuid4()

        first_response = self.post_scan(
            idempotency_key=idempotency_key,
        )
        second_response = self.post_scan(
            idempotency_key=idempotency_key,
        )

        self.assertEqual(first_response.status_code, status.HTTP_200_OK)
        self.assertEqual(second_response.status_code, status.HTTP_200_OK)
        self.assertEqual(first_response.data, second_response.data)
        self.assertEqual(first_response["Cache-Control"], "no-store")
        self.assertEqual(second_response["Cache-Control"], "no-store")

        self.assertEqual(
            LockerDeviceRequest.objects.filter(
                locker_device__user=self.device_user,
            ).count(),
            1,
        )
        self.assertEqual(
            LockerEventLog.objects.filter(
                order=self.order,
                event_type=LockerEventLog.EventType.PICKUP_OPENED,
            ).count(),
            1,
        )

    def test_expired_qr_token_cannot_open_drawer(self):
        self.qr_token.expires_at = timezone.now() - timedelta(seconds=1)
        self.qr_token.save(update_fields=("expires_at",))

        self.client.force_authenticate(user=self.device_user)

        response = self.post_scan()

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

        self.qr_token.refresh_from_db()
        self.assertIsNone(self.qr_token.used_at)

    def test_device_must_send_an_idempotency_key(self):
        self.client.force_authenticate(user=self.device_user)

        response = self.client.post(
            self.scan_url(),
            {"token": self.raw_token},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("idempotency_key", response.data)

    def test_new_key_cannot_scan_an_already_used_qr_token(self):
        self.client.force_authenticate(user=self.device_user)

        first_response = self.post_scan()
        second_response = self.post_scan()

        self.assertEqual(first_response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            second_response.status_code,
            status.HTTP_400_BAD_REQUEST,
        )


    @override_settings(LOCKER_DEVICE_OPEN_COMMAND_REPLAY_SECONDS=60)
    def test_expired_replay_does_not_reissue_open_command(self):
        self.client.force_authenticate(user=self.device_user)
        idempotency_key = uuid4()

        first_response = self.post_scan(
            idempotency_key=idempotency_key,
        )

        receipt = LockerDeviceRequest.objects.get(
            locker_device__user=self.device_user,
            idempotency_key=idempotency_key,
        )
        receipt.processed_at = timezone.now() - timedelta(seconds=61)
        receipt.save(update_fields=("processed_at",))

        replay_response = self.post_scan(
            idempotency_key=idempotency_key,
        )

        self.assertEqual(first_response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            replay_response.status_code,
            status.HTTP_409_CONFLICT,
        )


    def test_replay_does_not_open_drawer_after_collection(self):
        self.client.force_authenticate(user=self.device_user)
        idempotency_key = uuid4()

        first_response = self.post_scan(
            idempotency_key=idempotency_key,
        )

        self.order.status = Order.Status.COLLECTED
        self.order.save(update_fields=("status",))

        self.drawer.status = Drawer.Status.AVAILABLE
        self.drawer.save(update_fields=("status",))

        replay_response = self.post_scan(
            idempotency_key=idempotency_key,
        )

        self.assertEqual(first_response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            replay_response.status_code,
            status.HTTP_409_CONFLICT,
        )