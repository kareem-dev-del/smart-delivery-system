from unittest.mock import patch

from django.test import SimpleTestCase

from .tasks import expire_overdue_orders_task


class OrderTaskTests(SimpleTestCase):
    @patch(
        "orders.tasks.expire_overdue_orders",
        return_value=3,
    )
    def test_expire_overdue_orders_task_calls_service(
        self,
        expire_orders,
    ):
        result = expire_overdue_orders_task.run()

        self.assertEqual(result, 3)
        expire_orders.assert_called_once_with(limit=100)