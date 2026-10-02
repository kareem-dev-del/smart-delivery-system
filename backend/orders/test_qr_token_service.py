import hashlib
from datetime import timedelta
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError
from django.test import TestCase
from django.utils import timezone

from lockers.models import Drawer, LockerEventLog, LockerStation

from .models import Order, QRToken
from .services import issue_pickup_qr_token


User = get_user_model()


class IssuePickupQRTokenServiceTests(TestCase):
    def setUp(self):
        self.customer = User.objects.create_user(
            username="customer",
            password="test-password",
        )

        self.other_customer = User.objects.create_user(
            username="other-customer",
            password="test-password",
        )

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
            number=1,
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

    def test_issues_active_qr_token_and_stores_only_its_hash(self):
        qr_token, raw_token = issue_pickup_qr_token(
            order_public_id=self.order.public_id,
            customer=self.customer,
        )

        self.assertEqual(qr_token.order, self.order)
        self.assertTrue(qr_token.is_active)
        self.assertNotEqual(qr_token.token_hash, raw_token)
        self.assertEqual(
            qr_token.token_hash,
            hashlib.sha256(raw_token.encode("utf-8")).hexdigest(),
        )
        self.assertIsNone(qr_token.used_at)
        self.assertIsNone(qr_token.revoked_at)

        self.assertTrue(
            LockerEventLog.objects.filter(
                order=self.order,
                event_type=LockerEventLog.EventType.PICKUP_TOKEN_ISSUED,
            ).exists()
        )

    def test_new_qr_token_revokes_the_previous_unused_token(self):
        first_token, first_raw_token = issue_pickup_qr_token(
            order_public_id=self.order.public_id,
            customer=self.customer,
        )

        second_token, second_raw_token = issue_pickup_qr_token(
            order_public_id=self.order.public_id,
            customer=self.customer,
        )

        first_token.refresh_from_db()

        self.assertNotEqual(first_raw_token, second_raw_token)
        self.assertNotEqual(first_token.token_hash, second_token.token_hash)
        self.assertIsNotNone(first_token.revoked_at)
        self.assertIsNone(second_token.revoked_at)
        self.assertTrue(second_token.is_active)

    def test_rejects_qr_request_from_another_customer(self):
        with self.assertRaises(ValidationError):
            issue_pickup_qr_token(
                order_public_id=self.order.public_id,
                customer=self.other_customer,
            )

        self.assertEqual(QRToken.objects.count(), 0)

    def test_rejects_order_that_is_not_ready_for_pickup(self):
        self.order.status = Order.Status.ASSIGNED
        self.order.save(update_fields=("status",))

        with self.assertRaises(ValidationError):
            issue_pickup_qr_token(
                order_public_id=self.order.public_id,
                customer=self.customer,
            )

        self.assertEqual(QRToken.objects.count(), 0)

    def test_rejects_order_after_the_pickup_window_expires(self):
        self.order.delivery_deadline = timezone.now() - timedelta(seconds=1)
        self.order.save(update_fields=("delivery_deadline",))

        with self.assertRaises(ValidationError):
            issue_pickup_qr_token(
                order_public_id=self.order.public_id,
                customer=self.customer,
            )

        self.assertEqual(QRToken.objects.count(), 0)