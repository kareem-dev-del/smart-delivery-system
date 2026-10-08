from io import StringIO

from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.core.management.base import CommandError
from django.test import TestCase, override_settings

from accounts.models import UserProfile
from lockers.models import Drawer, LockerDevice, LockerStation
from products.models import Product


User = get_user_model()

@override_settings(DEBUG=True)
class SeedDemoDataCommandTests(TestCase):
    password = "demo-password-123"

    def run_command(self):
        output = StringIO()

        call_command(
            "seed_demo_data",
            "--password",
            self.password,
            stdout=output,
        )

        return output.getvalue()

    def test_creates_expected_demo_data(self):
        output = self.run_command()

        admin = User.objects.get(username="demo-admin")
        customer = User.objects.get(username="demo-customer")
        courier = User.objects.get(username="demo-courier")
        device_user = User.objects.get(
            username="demo-locker-device"
        )

        self.assertTrue(admin.is_staff)
        self.assertTrue(admin.check_password(self.password))
        self.assertEqual(
            admin.profile.role,
            UserProfile.Role.ADMIN,
        )
        self.assertEqual(
            customer.profile.role,
            UserProfile.Role.CUSTOMER,
        )
        self.assertEqual(
            courier.profile.role,
            UserProfile.Role.COURIER,
        )
        self.assertEqual(
            device_user.profile.role,
            UserProfile.Role.LOCKER_DEVICE,
        )

        locker_station = LockerStation.objects.get(
            code="DEMO-MAADI-001"
        )
        self.assertEqual(
            locker_station.status,
            LockerStation.Status.ONLINE,
        )
        self.assertEqual(
            Drawer.objects.filter(
                locker_station=locker_station
            ).count(),
            3,
        )
        self.assertEqual(
            LockerDevice.objects.filter(
                locker_station=locker_station,
                user=device_user,
                is_active=True,
            ).count(),
            1,
        )
        self.assertEqual(
            Product.objects.filter(
                name__startswith="Demo "
            ).count(),
            3,
        )
        self.assertIn("Demo data is ready.", output)

    def test_is_idempotent(self):
        self.run_command()
        self.run_command()

        self.assertEqual(
            User.objects.filter(
                username__startswith="demo-"
            ).count(),
            4,
        )
        self.assertEqual(
            LockerStation.objects.filter(
                code="DEMO-MAADI-001"
            ).count(),
            1,
        )
        self.assertEqual(Drawer.objects.count(), 3)
        self.assertEqual(LockerDevice.objects.count(), 1)
        self.assertEqual(
            Product.objects.filter(
                name__startswith="Demo "
            ).count(),
            3,
        )

    @override_settings(DEBUG=False)
    def test_rejects_production_execution(self):
        with self.assertRaisesMessage(
            CommandError,
            "seed_demo_data can only run when DEBUG=True.",
        ):
            self.run_command()