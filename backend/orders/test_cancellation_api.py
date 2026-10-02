from decimal import Decimal

from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from lockers.models import Drawer, LockerEventLog, LockerStation
from products.models import Product

from .models import Order
from .services import assign_order_to_drawer, create_order


User = get_user_model()


class OrderCancellationAPIViewTests(APITestCase):
    def setUp(self):
        self.customer = User.objects.create_user(
            username="customer",
            password="test-password",
        )

        self.other_customer = User.objects.create_user(
            username="other-customer",
            password="test-password",
        )

        self.product = Product.objects.create(
            name="USB Cable",
            price=Decimal("20.00"),
            stock=10,
            size=Product.Size.SMALL,
        )

        self.locker = LockerStation.objects.create(
            name="Nasr City Locker",
            code="NASR-001",
            address="Nasr City, Cairo",
            latitude="30.062630",
            longitude="31.335220",
            status=LockerStation.Status.ONLINE,
        )

        self.drawer = Drawer.objects.create(
            locker_station=self.locker,
            number=1,
            size=Drawer.Size.SMALL,
            status=Drawer.Status.AVAILABLE,
        )

        self.order = create_order(
            customer=self.customer,
            items=[
                {
                    "product_id": self.product.id,
                    "quantity": 2,
                }
            ],
        )

    def cancel_url(self, order):
        return reverse(
            "order-cancel",
            kwargs={"public_id": order.public_id},
        )

    def test_unauthenticated_user_cannot_cancel_order(self):
        response = self.client.post(self.cancel_url(self.order))

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_customer_can_cancel_order_awaiting_locker(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.post(self.cancel_url(self.order))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            response.data["status"],
            Order.Status.CANCELLED,
        )
        self.assertIsNotNone(response.data["cancelled_at"])

        self.order.refresh_from_db()
        self.product.refresh_from_db()

        self.assertEqual(self.order.status, Order.Status.CANCELLED)
        self.assertIsNotNone(self.order.cancelled_at)
        self.assertEqual(self.product.stock, 10)

    def test_customer_can_cancel_assigned_order_and_release_drawer(self):
        self.order = assign_order_to_drawer(
            order_public_id=self.order.public_id,
            locker_station_id=self.locker.id,
            drawer_id=self.drawer.id,
        )

        self.client.force_authenticate(user=self.customer)

        response = self.client.post(self.cancel_url(self.order))

        self.assertEqual(response.status_code, status.HTTP_200_OK)

        self.order.refresh_from_db()
        self.drawer.refresh_from_db()
        self.product.refresh_from_db()

        self.assertEqual(self.order.status, Order.Status.CANCELLED)
        self.assertEqual(self.drawer.status, Drawer.Status.AVAILABLE)
        self.assertEqual(self.product.stock, 10)

        self.assertTrue(
            LockerEventLog.objects.filter(
                order=self.order,
                event_type=LockerEventLog.EventType.ORDER_CANCELLED,
            ).exists()
        )

    def test_customer_cannot_cancel_another_customers_order(self):
        other_order = create_order(
            customer=self.other_customer,
            items=[
                {
                    "product_id": self.product.id,
                    "quantity": 1,
                }
            ],
        )

        self.client.force_authenticate(user=self.customer)

        response = self.client.post(self.cancel_url(other_order))

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

        other_order.refresh_from_db()

        self.assertEqual(
            other_order.status,
            Order.Status.AWAITING_LOCKER,
        )

    def test_customer_cannot_cancel_ready_for_pickup_order(self):
        self.order.status = Order.Status.READY_FOR_PICKUP
        self.order.save(update_fields=("status",))

        self.client.force_authenticate(user=self.customer)

        response = self.client.post(self.cancel_url(self.order))

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

        self.order.refresh_from_db()
        self.product.refresh_from_db()

        self.assertEqual(
            self.order.status,
            Order.Status.READY_FOR_PICKUP,
        )
        self.assertEqual(self.product.stock, 8)

    def test_order_cannot_be_cancelled_twice(self):
        self.client.force_authenticate(user=self.customer)

        first_response = self.client.post(self.cancel_url(self.order))
        second_response = self.client.post(self.cancel_url(self.order))

        self.assertEqual(first_response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            second_response.status_code,
            status.HTTP_400_BAD_REQUEST,
        )

        self.product.refresh_from_db()

        self.assertEqual(self.product.stock, 10)