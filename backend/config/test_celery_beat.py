from django.conf import settings
from django.test import SimpleTestCase


class CeleryBeatSettingsTests(SimpleTestCase):
    def test_order_expiration_task_is_scheduled(self):
        schedule = settings.CELERY_BEAT_SCHEDULE["expire-overdue-orders"]

        self.assertEqual(
            schedule["task"],
            "orders.tasks.expire_overdue_orders_task",
        )
        self.assertEqual(
            schedule["schedule"],
            settings.CELERY_ORDER_EXPIRATION_INTERVAL_SECONDS,
        )
        self.assertGreater(
            settings.CELERY_ORDER_EXPIRATION_INTERVAL_SECONDS,
            0,
        )