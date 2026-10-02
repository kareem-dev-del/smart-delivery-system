from decimal import Decimal

from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import UserProfile
from lockers.models import Drawer, LockerEventLog, LockerStation

from .models import Order, QRToken
from .services import hash_qr_token


User = get_user_model()


class CourierReturnQRAPIViewTests(APITestCase):
    def setUp(self):
        self.customer = User.objects.create_user(
            username="customer",
            password="test-password",
        )

        self.courier = User.objects.create_user(
            username="courier-one",
            password="test-password",
        )

        self.other_courier = User.objects.create_user(
            username="courier-two",
            password="test-password",
        )

        self.courier.profile.role = UserProfile.Role.COURIER
        self.courier.profile.save(update_fields=("role",))

        self.other_courier.profile.role = UserProfile.Role.COURIER
        self.other_courier.profile.save(update_fields=("role",))

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
            status=Drawer.Status.RETURN_PENDING,
        )

        self.order = Order.objects.create(
            customer=self.customer,
            assigned_courier=self.courier,
            status=Order.Status.EXPIRED,
            locker_station=self.locker,
            assigned_drawer=self.drawer,
            total_amount=Decimal("20.00"),
        )

    def return_list_url(self):
        return reverse("courier-return-order-list")

    def return_qr_url(self):
        return reverse(
            "order-return-qr",
            kwargs={"public_id": self.order.public_id},
        )

    def test_unauthenticated_user_cannot_see_return_orders(self):
        response = self.client.get(self.return_list_url())

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_assigned_courier_can_see_own_expired_orders(self):
        self.client.force_authenticate(user=self.courier)

        response = self.client.get(self.return_list_url())

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(
            response.data[0]["public_id"],
            str(self.order.public_id),
        )

    def test_customer_cannot_request_return_qr(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.post(self.return_qr_url())

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_assigned_courier_can_request_return_qr(self):
        self.client.force_authenticate(user=self.courier)

        response = self.client.post(self.return_qr_url())

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

        qr_token = QRToken.objects.get(
            token_hash=hash_qr_token(response.data["token"])
        )

        self.assertEqual(qr_token.order, self.order)
        self.assertEqual(
            qr_token.purpose,
            QRToken.Purpose.COURIER_RETURN,
        )
        self.assertTrue(qr_token.is_active)

        self.assertTrue(
            LockerEventLog.objects.filter(
                order=self.order,
                actor=self.courier,
                event_type=LockerEventLog.EventType.RETURN_TOKEN_ISSUED,
            ).exists()
        )

    def test_other_courier_cannot_request_return_qr(self):
        self.client.force_authenticate(user=self.other_courier)

        response = self.client.post(self.return_qr_url())

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(QRToken.objects.count(), 0)

    def test_new_return_qr_revokes_previous_return_qr(self):
        self.client.force_authenticate(user=self.courier)

        first_response = self.client.post(self.return_qr_url())
        second_response = self.client.post(self.return_qr_url())

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