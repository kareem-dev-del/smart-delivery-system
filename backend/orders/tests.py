from decimal import Decimal

from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError
from django.test import TestCase

from products.models import Product

from .models import Order, OrderItem
from .services import create_order


User = get_user_model()


class CreateOrderServiceTests(TestCase):
    def setUp(self):
        self.customer = User.objects.create_user(
            username="customer",
            password="test-password",
        )

        self.product_one = Product.objects.create(
            name="USB Cable",
            price=Decimal("19.99"),
            stock=5,
            size=Product.Size.SMALL,
        )

        self.product_two = Product.objects.create(
            name="Phone Case",
            price=Decimal("10.50"),
            stock=4,
            size=Product.Size.SMALL,
        )

    def test_creates_order_items_and_decreases_stock(self):
        order = create_order(
            customer=self.customer,
            items=[
                {"product_id": self.product_one.id, "quantity": 2},
                {"product_id": self.product_two.id, "quantity": 1},
            ],
        )

        self.assertEqual(order.status, Order.Status.AWAITING_LOCKER)
        self.assertEqual(order.total_amount, Decimal("50.48"))
        self.assertEqual(order.items.count(), 2)

        first_item = order.items.get(product=self.product_one)
        self.assertEqual(first_item.product_name, "USB Cable")
        self.assertEqual(first_item.unit_price, Decimal("19.99"))
        self.assertEqual(first_item.quantity, 2)
        self.assertEqual(first_item.line_total, Decimal("39.98"))

        self.product_one.refresh_from_db()
        self.product_two.refresh_from_db()

        self.assertEqual(self.product_one.stock, 3)
        self.assertEqual(self.product_two.stock, 3)

    def test_rejects_empty_order(self):
        with self.assertRaises(ValidationError):
            create_order(customer=self.customer, items=[])

        self.assertEqual(Order.objects.count(), 0)

    def test_rejects_duplicate_product_in_order(self):
        with self.assertRaises(ValidationError):
            create_order(
                customer=self.customer,
                items=[
                    {"product_id": self.product_one.id, "quantity": 1},
                    {"product_id": self.product_one.id, "quantity": 1},
                ],
            )

        self.assertEqual(Order.objects.count(), 0)

    def test_rejects_inactive_product(self):
        self.product_one.is_active = False
        self.product_one.save(update_fields=("is_active",))

        with self.assertRaises(ValidationError):
            create_order(
                customer=self.customer,
                items=[
                    {"product_id": self.product_one.id, "quantity": 1},
                ],
            )

        self.product_one.refresh_from_db()

        self.assertEqual(Order.objects.count(), 0)
        self.assertEqual(self.product_one.stock, 5)

    def test_rejects_order_when_stock_is_insufficient(self):
        with self.assertRaises(ValidationError):
            create_order(
                customer=self.customer,
                items=[
                    {"product_id": self.product_one.id, "quantity": 6},
                ],
            )

        self.product_one.refresh_from_db()

        self.assertEqual(Order.objects.count(), 0)
        self.assertEqual(OrderItem.objects.count(), 0)
        self.assertEqual(self.product_one.stock, 5)