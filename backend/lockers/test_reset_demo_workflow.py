from io import StringIO
from uuid import uuid4
from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.core.management.base import CommandError
from django.test import TestCase, override_settings

from lockers.models import Drawer, LockerDevice, LockerStation,LockerDeviceRequest
from orders.models import Order
from products.models import Product


User = get_user_model()


@override_settings(DEBUG=True)
class ResetDemoWorkflowCommandTests(TestCase):
    demo_password = "demo-password-123"

    def setUp(self):
        call_command(
            "seed_demo_data",
            "--password",
            self.demo_password,
        )

        self.customer = User.objects.get(username="demo-customer")
        self.station = LockerStation.objects.get(code="DEMO-MAADI-001")
        self.drawer = Drawer.objects.get(
            locker_station=self.station,
            number=1,
        )
        self.device = LockerDevice.objects.get(
             device_code="DEMO-DEVICE-MAADI-001"
        )
        self.product = Product.objects.get(name="Demo Phone Case")

    def test_reset_removes_demo_customer_orders_and_restores_resources(self):
        order = Order.objects.create(
            customer=self.customer,
            locker_station=self.station,
            assigned_drawer=self.drawer,
            status=Order.Status.READY_FOR_PICKUP,
            total_amount="250.00",
        )
        receipt = LockerDeviceRequest.objects.create(
            locker_device=self.device,
            order=order,
            operation=LockerDeviceRequest.Operation.DEPOSIT_CONFIRMATION,
            idempotency_key=uuid4(),
            request_hash="a" * 64,
            response_status=200,
            response_body={"status": "ready_for_pickup"},
        )

        self.drawer.status = Drawer.Status.OCCUPIED
        self.drawer.save(update_fields=["status"])

        self.product.stock = 19
        self.product.save(update_fields=["stock"])

        output = StringIO()

        call_command(
            "reset_demo_workflow",
            "--yes",
            stdout=output,
        )

        self.assertFalse(Order.objects.filter(id=order.id).exists())
        self.assertFalse(
            LockerDeviceRequest.objects.filter(id=receipt.id).exists()
        )

        self.drawer.refresh_from_db()
        self.assertEqual(self.drawer.status, Drawer.Status.AVAILABLE)

        self.product.refresh_from_db()
        self.assertEqual(self.product.stock, 20)
        self.assertTrue(self.product.is_active)

        self.station.refresh_from_db()
        self.assertEqual(
            self.station.status,
            LockerStation.Status.ONLINE,
        )

        self.device.refresh_from_db()
        self.assertTrue(self.device.is_active)
        self.assertIsNone(self.device.last_heartbeat_at)

        self.assertIn("Demo workflow reset is complete.", output.getvalue())

    def test_reset_requires_explicit_confirmation(self):
        with self.assertRaisesMessage(
            CommandError,
            "Pass --yes to confirm the demo workflow reset.",
        ):
            call_command("reset_demo_workflow")


class ResetDemoWorkflowProductionGuardTests(TestCase):
    @override_settings(DEBUG=False)
    def test_reset_refuses_to_run_when_debug_is_disabled(self):
        with self.assertRaisesMessage(
            CommandError,
            "reset_demo_workflow can only run when DEBUG=True.",
        ):
            call_command("reset_demo_workflow", "--yes")