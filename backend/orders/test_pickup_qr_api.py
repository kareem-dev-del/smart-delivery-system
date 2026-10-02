from datetime import timedelta
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.urls import reverse
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from lockers.models import Drawer, LockerStation

from .models import Order, QRToken
from .services import hash_qr_token


User = get_user_model()


class OrderPickupQRAPIViewTests(APITestCase):
    def setUp(self):
        self.customer = User.objects.create_user(
            username="customer",
            password="test-password",
        )

        self.other_customer = User.objects.create_user(
            username="other-customer",
            password="test-password",
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
            status=Drawer.Status.OCCUPIED,
        )

        self.order = Order.objects.create(
            customer=self.customer,
            status=Order.Status.READY_FOR_PICKUP,
            locker_station=self.locker,
            assigned_drawer=self.drawer,
            total_amount=Decimal("20.00"),
            delivery_deadline=timezone.now() + timedelta(hours=48),
        )

    def pickup_qr_url(self):
        return reverse(
            "order-pickup-qr",
            kwargs={"public_id": self.order.public_id},
        )

    def test_unauthenticated_user_cannot_request_pickup_qr(self):
        response = self.client.post(self.pickup_qr_url())

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_customer_can_request_pickup_qr_for_own_order(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.post(self.pickup_qr_url())

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("token", response.data)
        self.assertIn("expires_at", response.data)
        self.assertEqual(
            response.data["order_public_id"],
            str(self.order.public_id),
        )
        self.assertEqual(response.data["locker_code"], "NASR-001")
        self.assertNotIn("drawer_id", response.data)
        self.assertEqual(response["Cache-Control"], "no-store")

        self.assertTrue(
            QRToken.objects.filter(
                order=self.order,
                token_hash=hash_qr_token(response.data["token"]),
            ).exists()
        )

    def test_customer_cannot_request_qr_for_another_customers_order(self):
        self.client.force_authenticate(user=self.other_customer)

        response = self.client.post(self.pickup_qr_url())

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(QRToken.objects.count(), 0)

    def test_new_pickup_qr_revokes_previous_qr(self):
        self.client.force_authenticate(user=self.customer)

        first_response = self.client.post(self.pickup_qr_url())
        second_response = self.client.post(self.pickup_qr_url())

        first_token = QRToken.objects.get(
            token_hash=hash_qr_token(first_response.data["token"])
        )

        second_token = QRToken.objects.get(
            token_hash=hash_qr_token(second_response.data["token"])
        )

        self.assertEqual(first_response.status_code, status.HTTP_200_OK)
        self.assertEqual(second_response.status_code, status.HTTP_200_OK)
        self.assertNotEqual(
            first_response.data["token"],
            second_response.data["token"],
        )
        self.assertIsNotNone(first_token.revoked_at)
        self.assertIsNone(second_token.revoked_at)

    def test_rejects_qr_request_before_order_is_ready(self):
        self.order.status = Order.Status.ASSIGNED
        self.order.save(update_fields=("status",))

        self.client.force_authenticate(user=self.customer)

        response = self.client.post(self.pickup_qr_url())

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(QRToken.objects.count(), 0)

    def test_rejects_qr_request_after_pickup_deadline(self):
        self.order.delivery_deadline = timezone.now() - timedelta(seconds=1)
        self.order.save(update_fields=("delivery_deadline",))

        self.client.force_authenticate(user=self.customer)

        response = self.client.post(self.pickup_qr_url())

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(QRToken.objects.count(), 0)