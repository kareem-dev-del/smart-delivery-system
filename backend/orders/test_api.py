from decimal import Decimal

from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from .models import Order
from .services import create_order
from products.models import Product


User = get_user_model()


class OrderAPIViewTests(APITestCase):
    def setUp(self):
        self.customer = User.objects.create_user(
            username="customer",
            password="test-password",
        )

        self.other_customer = User.objects.create_user(
            username="other-customer",
            password="test-password",
        )

        self.admin_user = User.objects.create_user(
            username="admin",
            password="test-password",
            is_staff=True,
        )

        self.product_one = Product.objects.create(
            name="USB Cable",
            price=Decimal("19.99"),
            stock=20,
            size=Product.Size.SMALL,
        )

        self.product_two = Product.objects.create(
            name="Phone Case",
            price=Decimal("10.50"),
            stock=20,
            size=Product.Size.SMALL,
        )

        self.url = reverse("order-list-create")

    def test_customer_can_create_order(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.post(
            self.url,
            {
                "items": [
                    {"product_id": self.product_one.id, "quantity": 2},
                    {"product_id": self.product_two.id, "quantity": 1},
                ]
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["status"], Order.Status.AWAITING_LOCKER)
        self.assertEqual(response.data["total_amount"], "50.48")
        self.assertEqual(len(response.data["items"]), 2)

        self.product_one.refresh_from_db()
        self.assertEqual(self.product_one.stock, 18)

    def test_unauthenticated_user_cannot_create_order(self):
        response = self.client.post(
            self.url,
            {
                "items": [
                    {"product_id": self.product_one.id, "quantity": 1},
                ]
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_admin_cannot_create_customer_order(self):
        self.client.force_authenticate(user=self.admin_user)

        response = self.client.post(
            self.url,
            {
                "items": [
                    {"product_id": self.product_one.id, "quantity": 1},
                ]
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_customer_sees_only_own_orders(self):
        own_order = create_order(
            customer=self.customer,
            items=[
                {"product_id": self.product_one.id, "quantity": 1},
            ],
        )

        create_order(
            customer=self.other_customer,
            items=[
                {"product_id": self.product_two.id, "quantity": 1},
            ],
        )

        self.client.force_authenticate(user=self.customer)

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(
            response.data[0]["public_id"],
            str(own_order.public_id),
        )

    def test_admin_sees_all_orders(self):
        create_order(
            customer=self.customer,
            items=[
                {"product_id": self.product_one.id, "quantity": 1},
            ],
        )

        create_order(
            customer=self.other_customer,
            items=[
                {"product_id": self.product_two.id, "quantity": 1},
            ],
        )

        self.client.force_authenticate(user=self.admin_user)

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 2)

    def test_rejects_order_with_insufficient_stock(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.post(
            self.url,
            {
                "items": [
                    {"product_id": self.product_one.id, "quantity": 100},
                ]
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(Order.objects.count(), 0)