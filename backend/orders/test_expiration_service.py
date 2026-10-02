from datetime import timedelta
from decimal import Decimal
from io import StringIO

from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.test import TestCase
from django.utils import timezone

from lockers.models import Drawer, LockerEventLog, LockerStation

from .models import Order
from .services import (
    expire_order_if_overdue,
    issue_pickup_qr_token,
)


User = get_user_model()


class ExpireOverdueOrdersTests(TestCase):
    def setUp(self):
        self.customer = User.objects.create_user(
            username="customer",
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
            delivery_deadline=timezone.now() + timedelta(hours=1),
        )

    def make_order_overdue(self):
        self.order.delivery_deadline = timezone.now() - timedelta(minutes=1)
        self.order.save(update_fields=("delivery_deadline",))

    def test_expires_overdue_order_and_marks_drawer_for_return(self):
        qr_token, _ = issue_pickup_qr_token(
            order_public_id=self.order.public_id,
            customer=self.customer,
        )

        self.make_order_overdue()

        expired = expire_order_if_overdue(order_id=self.order.id)

        self.assertTrue(expired)

        self.order.refresh_from_db()
        self.drawer.refresh_from_db()
        qr_token.refresh_from_db()

        self.assertEqual(self.order.status, Order.Status.EXPIRED)
        self.assertEqual(
            self.drawer.status,
            Drawer.Status.RETURN_PENDING,
        )
        self.assertIsNotNone(qr_token.revoked_at)

        self.assertTrue(
            LockerEventLog.objects.filter(
                order=self.order,
                event_type=LockerEventLog.EventType.PICKUP_EXPIRED,
            ).exists()
        )

    def test_does_not_expire_order_before_deadline(self):
        expired = expire_order_if_overdue(order_id=self.order.id)

        self.assertFalse(expired)

        self.order.refresh_from_db()
        self.drawer.refresh_from_db()

        self.assertEqual(
            self.order.status,
            Order.Status.READY_FOR_PICKUP,
        )
        self.assertEqual(self.drawer.status, Drawer.Status.OCCUPIED)

    def test_does_not_expire_order_with_active_pickup_attempt(self):
        self.make_order_overdue()

        self.order.pickup_opened_at = timezone.now()
        self.order.save(update_fields=("pickup_opened_at",))

        expired = expire_order_if_overdue(order_id=self.order.id)

        self.assertFalse(expired)

        self.order.refresh_from_db()
        self.assertEqual(
            self.order.status,
            Order.Status.READY_FOR_PICKUP,
        )


    def test_management_command_dry_run_does_not_expire_orders(self):
        self.make_order_overdue()

        output = StringIO()

        call_command(
            "expire_overdue_orders",
            "--dry-run",
            stdout=output,
        )

        self.order.refresh_from_db()

        self.assertEqual(
            self.order.status,
            Order.Status.READY_FOR_PICKUP,
        )
        self.assertIn(
            "Would expire 1 order(s).",
            output.getvalue(),
        )


    def test_management_command_expires_overdue_orders(self):
        self.make_order_overdue()

        output = StringIO()

        call_command(
            "expire_overdue_orders",
            stdout=output,
        )

        self.order.refresh_from_db()

        self.assertEqual(self.order.status, Order.Status.EXPIRED)
        self.assertIn("Expired 1 order(s).", output.getvalue())