from datetime import timedelta
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.urls import reverse
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from uuid import uuid4

from accounts.models import UserProfile
from lockers.models import (
    Drawer,
    LockerDevice,
    LockerEventLog,
    LockerStation,
    LockerDeviceRequest,
)
from orders.models import Order, QRToken
from orders.services import (
    authorize_return_by_qr,
    hash_qr_token,
    issue_return_qr_token,
)


User = get_user_model()


class LockerReturnConfirmationAPIViewTests(APITestCase):
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

        _, raw_token = issue_return_qr_token(
            order_public_id=self.order.public_id,
            courier=self.courier,
        )

        authorize_return_by_qr(
            raw_token=raw_token,
            device_user=self.device_user,
        )

        self.order.refresh_from_db()

    def confirm_url(self):
        return reverse(
            "locker-confirm-return",
            kwargs={"public_id": self.order.public_id},
        )

    def post_confirmation(self, *, idempotency_key=None):
        return self.client.post(
            self.confirm_url(),
            HTTP_IDEMPOTENCY_KEY=str(idempotency_key or uuid4()),
        )
    def test_unauthenticated_user_cannot_confirm_return(self):
        response = self.client.post(self.confirm_url())

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_customer_cannot_confirm_return(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.post(self.confirm_url())

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_other_locker_device_cannot_confirm_return(self):
        self.client.force_authenticate(user=self.other_device_user)

        response = self.post_confirmation()

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

        self.order.refresh_from_db()
        self.drawer.refresh_from_db()

        self.assertEqual(self.order.status, Order.Status.EXPIRED)
        self.assertEqual(
            self.drawer.status,
            Drawer.Status.RETURN_PENDING,
        )

    def test_correct_device_confirms_return_and_releases_drawer(self):
        unused_qr_token = QRToken.objects.create(
            order=self.order,
            purpose=QRToken.Purpose.COURIER_RETURN,
            token_hash=hash_qr_token(
                "unused-return-token-for-confirmation-test-12345"
            ),
            expires_at=timezone.now() + timedelta(minutes=10),
        )

        self.client.force_authenticate(user=self.device_user)

        response = self.post_confirmation()

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            response.data["status"],
            Order.Status.RETURNED,
        )
        self.assertEqual(response.data["drawer_number"], 3)
        self.assertEqual(
            response.data["drawer_status"],
            Drawer.Status.AVAILABLE,
        )
        self.assertIsNotNone(response.data["returned_at"])
        self.assertEqual(response["Cache-Control"], "no-store")

        self.order.refresh_from_db()
        self.drawer.refresh_from_db()
        unused_qr_token.refresh_from_db()

        self.assertEqual(self.order.status, Order.Status.RETURNED)
        self.assertIsNotNone(self.order.returned_at)
        self.assertEqual(self.drawer.status, Drawer.Status.AVAILABLE)
        self.assertIsNotNone(unused_qr_token.revoked_at)

        event_types = set(
            LockerEventLog.objects.filter(order=self.order).values_list(
                "event_type",
                flat=True,
            )
        )

        self.assertIn(
            LockerEventLog.EventType.PACKAGE_RETURNED,
            event_types,
        )
        self.assertIn(
            LockerEventLog.EventType.DRAWER_RELEASED,
            event_types,
        )

    def test_cannot_confirm_return_before_qr_scan(self):
        self.order.return_opened_at = None
        self.order.save(update_fields=("return_opened_at",))

        self.client.force_authenticate(user=self.device_user)

        response = self.post_confirmation()

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

        self.order.refresh_from_db()
        self.drawer.refresh_from_db()

        self.assertEqual(self.order.status, Order.Status.EXPIRED)
        self.assertEqual(
            self.drawer.status,
            Drawer.Status.RETURN_PENDING,
        )

    def test_same_idempotency_key_replays_return_confirmation(self):
        self.client.force_authenticate(user=self.device_user)
        idempotency_key = uuid4()

        first_response = self.post_confirmation(
            idempotency_key=idempotency_key,
        )
        second_response = self.post_confirmation(
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
                event_type=LockerEventLog.EventType.PACKAGE_RETURNED,
            ).count(),
            1,
        )

    def test_device_must_send_an_idempotency_key(self):
        self.client.force_authenticate(user=self.device_user)

        response = self.client.post(self.confirm_url())

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("idempotency_key", response.data)


    def test_new_key_cannot_repeat_completed_return(self):
        self.client.force_authenticate(user=self.device_user)

        first_response = self.post_confirmation()
        second_response = self.post_confirmation()

        self.assertEqual(first_response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            second_response.status_code,
            status.HTTP_400_BAD_REQUEST,
        )