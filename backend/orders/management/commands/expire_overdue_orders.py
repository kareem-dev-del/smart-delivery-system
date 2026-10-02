from django.core.management.base import BaseCommand, CommandError
from django.utils import timezone

from orders.services import (
    expire_overdue_orders,
    get_overdue_order_ids,
)


class Command(BaseCommand):
    help = "Expires orders whose pickup deadline has passed."

    def add_arguments(self, parser):
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Shows how many orders would expire without changing data.",
        )
        parser.add_argument(
            "--limit",
            type=int,
            default=None,
            help="Maximum number of orders to process in one run.",
        )

    def handle(self, *args, **options):
        limit = options["limit"]

        if limit is not None and limit < 1:
            raise CommandError("--limit must be at least 1.")

        now = timezone.now()

        if options["dry_run"]:
            overdue_order_ids = get_overdue_order_ids(now=now)

            if limit is not None:
                overdue_order_ids = overdue_order_ids[:limit]

            self.stdout.write(
                f"Would expire {overdue_order_ids.count()} order(s)."
            )
            return

        expired_count = expire_overdue_orders(
            now=now,
            limit=limit,
        )

        self.stdout.write(
            self.style.SUCCESS(
                f"Expired {expired_count} order(s)."
            )
        )