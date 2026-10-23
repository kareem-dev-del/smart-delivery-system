from django.conf import settings
from django.core.cache import cache
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
from notifications.models import Notification
from orders.models import Order
from products.models import Product


class Command(BaseCommand):
    help = (
        "Clears local SmartDrop business data while preserving user accounts."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--yes",
            action="store_true",
            help="Confirms deletion of local business data.",
        )

    def handle(self, *args, **options):
        if not settings.DEBUG:
            raise CommandError(
                "reset_demo_environment can only run when DEBUG=True."
            )

        database = settings.DATABASES["default"]
        database_name = str(database["NAME"])
        database_engine = str(database["ENGINE"]).lower()
        database_host = str(database.get("HOST", "")).lower()
        if (
            database_name != "smart_delivery"
            or not database_engine.endswith("postgresql")
            or database_host not in {"db", "localhost", "127.0.0.1"}
        ):
            raise CommandError(
                "Reset refused: the active database is not the local "
                "SmartDrop PostgreSQL database."
            )

        if not options["yes"]:
            raise CommandError(
                "Pass --yes to confirm deletion of local business data."
            )

        with transaction.atomic():
            deleted = {}
            for label, queryset in (
                ("locker events", LockerEventLog.objects.all()),
                ("device request records", LockerDeviceRequest.objects.all()),
                ("notifications", Notification.objects.all()),
                ("audit records", AuditLog.objects.all()),
                ("orders", Order.objects.all()),
                ("locker devices", LockerDevice.objects.all()),
                ("drawers", Drawer.objects.all()),
                ("locker stations", LockerStation.objects.all()),
                ("products", Product.objects.all()),
            ):
                deleted[label] = queryset.delete()[0]

        cache.clear()

        self.stdout.write(
            self.style.SUCCESS(
                "Local business data cleared. User accounts and schema were preserved."
            )
        )
        for label, count in deleted.items():
            self.stdout.write(f"Deleted {label}: {count}")
