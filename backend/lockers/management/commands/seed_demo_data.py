from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from accounts.models import UserProfile
from lockers.models import Drawer, LockerDevice, LockerStation
from products.models import Product


User = get_user_model()


class Command(BaseCommand):
    help = "Creates repeatable local demo data for the smart delivery workflow."

    def add_arguments(self, parser):
        parser.add_argument(
            "--password",
            required=True,
            help="Password assigned to the local demo accounts.",
        )

    def handle(self, *args, **options):
        if not settings.DEBUG:
            raise CommandError(
                "seed_demo_data can only run when DEBUG=True."
            )

        password = options["password"]

        if len(password) < 12:
            raise CommandError(
                "--password must contain at least 12 characters."
            )

        with transaction.atomic():
            admin, admin_created = self.ensure_user(
                username="demo-admin",
                password=password,
                role=UserProfile.Role.ADMIN,
                is_staff=True,
            )
            customer, customer_created = self.ensure_user(
                username="demo-customer",
                password=password,
                role=UserProfile.Role.CUSTOMER,
            )
            courier, courier_created = self.ensure_user(
                username="demo-courier",
                password=password,
                role=UserProfile.Role.COURIER,
            )
            device_user, device_user_created = self.ensure_user(
                username="demo-locker-device",
                password=password,
                role=UserProfile.Role.LOCKER_DEVICE,
            )

            locker_station, locker_created = (
                LockerStation.objects.get_or_create(
                    code="DEMO-MAADI-001",
                    defaults={
                        "name": "Demo Locker Maadi",
                        "address": "Maadi, Cairo, Egypt",
                        "latitude": "29.960235",
                        "longitude": "31.256537",
                        "status": LockerStation.Status.ONLINE,
                    },
                )
            )

            if locker_station.status != LockerStation.Status.ONLINE:
                raise CommandError(
                    "The demo locker station must be online."
                )

            drawer_specs = (
                (1, Drawer.Size.SMALL),
                (2, Drawer.Size.MEDIUM),
                (3, Drawer.Size.LARGE),
            )
            drawers = []

            for number, size in drawer_specs:
                drawer, created = Drawer.objects.get_or_create(
                    locker_station=locker_station,
                    number=number,
                    defaults={
                        "size": size,
                        "status": Drawer.Status.AVAILABLE,
                    },
                )

                if drawer.size != size:
                    raise CommandError(
                        f"Demo drawer {number} has an unexpected size."
                    )

                drawers.append((drawer, created))

            device, device_created = LockerDevice.objects.get_or_create(
                device_code="DEMO-DEVICE-MAADI-001",
                defaults={
                    "locker_station": locker_station,
                    "user": device_user,
                    "is_active": True,
                },
            )

            if (
                device.locker_station_id != locker_station.id
                or device.user_id != device_user.id
            ):
                raise CommandError(
                    "The demo locker device is linked to unexpected data."
                )

            product_specs = (
                {
                    "name": "Demo Phone Case",
                    "description": "Small demo product for locker pickup.",
                    "price": "250.00",
                    "stock": 20,
                    "size": Product.Size.SMALL,
                },
                {
                    "name": "Demo Backpack",
                    "description": "Medium demo product for locker pickup.",
                    "price": "850.00",
                    "stock": 15,
                    "size": Product.Size.MEDIUM,
                },
                {
                    "name": "Demo Monitor",
                    "description": "Large demo product for locker pickup.",
                    "price": "6500.00",
                    "stock": 10,
                    "size": Product.Size.LARGE,
                },
            )
            products = []

            for product_data in product_specs:
                product, created = Product.objects.get_or_create(
                    name=product_data["name"],
                    defaults=product_data,
                )
                products.append((product, created))

        self.stdout.write(self.style.SUCCESS("Demo data is ready."))

        self.stdout.write(
            "Accounts: "
            f"admin={admin.id}, customer={customer.id}, "
            f"courier={courier.id}, device_user={device_user.id}"
        )
        self.stdout.write(
            "Created accounts: "
            f"admin={admin_created}, customer={customer_created}, "
            f"courier={courier_created}, device_user={device_user_created}"
        )
        self.stdout.write(
            f"Locker: id={locker_station.id}, "
            f"code={locker_station.code}, created={locker_created}"
        )
        self.stdout.write(
            "Drawers: "
            + ", ".join(
                f"id={drawer.id}/number={drawer.number}/created={created}"
                for drawer, created in drawers
            )
        )
        self.stdout.write(
            "Products: "
            + ", ".join(
                f"id={product.id}/name={product.name}/created={created}"
                for product, created in products
            )
        )
        self.stdout.write(
            "Demo usernames: demo-admin, demo-customer, "
            "demo-courier, demo-locker-device"
        )

    @staticmethod
    def ensure_user(*, username, password, role, is_staff=False):
        user, created = User.objects.get_or_create(username=username)

        user.is_staff = is_staff
        user.is_active = True
        user.set_password(password)
        user.save(
            update_fields=(
                "is_staff",
                "is_active",
                "password",
            )
        )

        profile, _ = UserProfile.objects.get_or_create(user=user)

        if profile.role != role:
            profile.role = role
            profile.save(update_fields=("role", "updated_at"))

        return user, created