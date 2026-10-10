from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from audit.models import AuditLog

from lockers.models import (
    Drawer,
    LockerDevice,
    LockerDeviceRequest,
    LockerEventLog,
    LockerStation,
)

from orders.models import Order
from products.models import Product


User = get_user_model()

DEMO_CUSTOMER_USERNAME = "demo-customer"
DEMO_DEVICE_USERNAME = "demo-locker-device"
DEMO_LOCKER_CODE = "DEMO-MAADI-001"
DEMO_DEVICE_CODE = "DEMO-DEVICE-MAADI-001"

DEMO_DRAWER_NUMBERS = (1, 2, 3)

DEMO_PRODUCT_STOCKS = {
    "Demo Phone Case": 20,
    "Demo Backpack": 15,
    "Demo Monitor": 10,
}


class Command(BaseCommand):
    help = "Resets runtime data created by the local demo workflow."

    def add_arguments(self, parser):
        parser.add_argument(
            "--yes",
            action="store_true",
            help="Confirms that demo workflow records should be deleted.",
        )

    def handle(self, *args, **options):
        if not settings.DEBUG:
            raise CommandError(
                "reset_demo_workflow can only run when DEBUG=True."
            )

        if not options["yes"]:
            raise CommandError(
                "Pass --yes to confirm the demo workflow reset."
            )

        try:
            customer = User.objects.get(
                username=DEMO_CUSTOMER_USERNAME
            )
            device_user = User.objects.get(
                username=DEMO_DEVICE_USERNAME
            )
            locker_station = LockerStation.objects.get(
                code=DEMO_LOCKER_CODE
            )
            locker_device = LockerDevice.objects.get(
                device_code=DEMO_DEVICE_CODE
            )
        except (
            User.DoesNotExist,
            LockerStation.DoesNotExist,
            LockerDevice.DoesNotExist,
        ) as error:
            raise CommandError(
                "Demo data was not found. Run seed_demo_data first."
            ) from error

        if (
            locker_device.locker_station_id != locker_station.id
            or locker_device.user_id != device_user.id
        ):
            raise CommandError(
                "The demo locker device is linked to unexpected data."
            )

        drawers = list(
            Drawer.objects.filter(
                locker_station=locker_station,
                number__in=DEMO_DRAWER_NUMBERS,
            ).order_by("number")
        )

        if len(drawers) != len(DEMO_DRAWER_NUMBERS):
            raise CommandError(
                "Expected demo drawers were not found."
            )

        products = []

        for product_name, initial_stock in DEMO_PRODUCT_STOCKS.items():
            matching_products = Product.objects.filter(
                name=product_name
            )

            if matching_products.count() != 1:
                raise CommandError(
                    f"Expected one demo product named '{product_name}'."
                )

            products.append(
                (matching_products.get(), initial_stock)
            )

        foreign_order_count = (
            Order.objects.filter(locker_station=locker_station)
            .exclude(customer=customer)
            .count()
        )

        if foreign_order_count:
            raise CommandError(
                "Reset aborted because this demo locker has "
                "orders from other customers."
            )

        with transaction.atomic():
            demo_orders = Order.objects.filter(customer=customer)

            order_ids = list(
                demo_orders.values_list("id", flat=True)
            )
            order_public_ids = [
                str(public_id)
                for public_id in demo_orders.values_list(
                    "public_id",
                    flat=True,
                )
            ]

            deleted_order_count = len(order_ids)

            deleted_receipt_count, _ = LockerDeviceRequest.objects.filter(
                        order_id__in=order_ids,
            ).delete()

            deleted_event_count, _ = LockerEventLog.objects.filter(
                order_id__in=order_ids
            ).delete()

            deleted_audit_count, _ = AuditLog.objects.filter(
                target_type=AuditLog.TargetType.ORDER,
                target_id__in=order_public_ids,
            ).delete()

            demo_orders.delete()
            self.stdout.write(
                f"Deleted device request receipts: {deleted_receipt_count}"
            )

            for drawer in drawers:
                drawer.status = Drawer.Status.AVAILABLE
                drawer.save(
                    update_fields=(
                        "status",
                        "updated_at",
                    )
                )

            locker_station.status = LockerStation.Status.ONLINE
            locker_station.save(
                update_fields=(
                    "status",
                    "updated_at",
                )
            )

            locker_device.is_active = True
            locker_device.last_heartbeat_at = None
            locker_device.save(
                update_fields=(
                    "is_active",
                    "last_heartbeat_at",
                    "updated_at",
                )
            )

            for product, initial_stock in products:
                product.stock = initial_stock
                product.is_active = True
                product.save(
                    update_fields=(
                        "stock",
                        "is_active",
                        "updated_at",
                    )
                )

        self.stdout.write(
            self.style.SUCCESS("Demo workflow reset is complete.")
        )
        self.stdout.write(
            f"Deleted demo orders: {deleted_order_count}"
        )
        self.stdout.write(
            f"Deleted locker events: {deleted_event_count}"
        )
        self.stdout.write(
            f"Deleted order audit logs: {deleted_audit_count}"
        )
        self.stdout.write(
            "Restored demo drawers, products, locker, and device."
        )