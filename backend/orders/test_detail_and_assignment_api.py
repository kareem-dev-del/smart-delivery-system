from decimal import Decimal

from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import UserProfile
from lockers.models import Drawer, LockerStation
from products.models import Product

from .models import Order
from .services import create_order


User = get_user_model()


class OrderDetailAndAssignmentAPIViewTests(APITestCase):
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

        self.customer.profile.role = UserProfile.Role.CUSTOMER
        self.customer.profile.save(update_fields=("role",))

        self.other_customer.profile.role = UserProfile.Role.CUSTOMER
        self.other_customer.profile.save(update_fields=("role",))

        self.admin_user.profile.role = UserProfile.Role.ADMIN
        self.admin_user.profile.save(update_fields=("role",))

        self.product = Product.objects.create(
            name="USB Cable",
            price=Decimal("20.00"),
            stock=20,
            size=Product.Size.SMALL,
        )

        self.customer_order = create_order(
            customer=self.customer,
            items=[
                {"product_id": self.product.id, "quantity": 1},
            ],
        )

        self.other_customer_order = create_order(
            customer=self.other_customer,
            items=[
                {"product_id": self.product.id, "quantity": 1},
            ],
        )

        self.locker = LockerStation.objects.create(
            name="Nasr City Locker",
            code="NASR-001",
            address="Nasr City, Cairo",
            latitude="30.062630",
            longitude="31.335220",
            status=LockerStation.Status.ONLINE,
        )

        self.available_drawer = Drawer.objects.create(
            locker_station=self.locker,
            number=1,
            size=Drawer.Size.SMALL,
            status=Drawer.Status.AVAILABLE,
        )

        self.occupied_drawer = Drawer.objects.create(
            locker_station=self.locker,
            number=2,
            size=Drawer.Size.MEDIUM,
            status=Drawer.Status.OCCUPIED,
        )

    def detail_url(self, order):
        return reverse(
            "order-detail",
            kwargs={"public_id": order.public_id},
        )

    def assignment_url(self, order):
        return reverse(
            "order-assign-drawer",
            kwargs={"public_id": order.public_id},
        )

    def test_unauthenticated_user_cannot_retrieve_order(self):
        response = self.client.get(self.detail_url(self.customer_order))

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_customer_can_retrieve_own_order(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.get(self.detail_url(self.customer_order))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            response.data["public_id"],
            str(self.customer_order.public_id),
        )

    def test_customer_cannot_retrieve_another_customers_order(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.get(self.detail_url(self.other_customer_order))

        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_admin_can_retrieve_any_order(self):
        self.client.force_authenticate(user=self.admin_user)

        response = self.client.get(self.detail_url(self.customer_order))

        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_customer_cannot_assign_drawer(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.post(
            self.assignment_url(self.customer_order),
            {
                "locker_station_id": self.locker.id,
                "drawer_id": self.available_drawer.id,
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_admin_can_assign_order_to_available_drawer(self):
        self.client.force_authenticate(user=self.admin_user)

        response = self.client.post(
            self.assignment_url(self.customer_order),
            {
                "locker_station_id": self.locker.id,
                "drawer_id": self.available_drawer.id,
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["status"], Order.Status.ASSIGNED)
        self.assertEqual(response.data["locker_station"], self.locker.id)
        self.assertEqual(response.data["assigned_drawer"], self.available_drawer.id)

        self.available_drawer.refresh_from_db()
        self.assertEqual(self.available_drawer.status, Drawer.Status.RESERVED)

    def test_admin_cannot_assign_unavailable_drawer(self):
        self.client.force_authenticate(user=self.admin_user)

        response = self.client.post(
            self.assignment_url(self.customer_order),
            {
                "locker_station_id": self.locker.id,
                "drawer_id": self.occupied_drawer.id,
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

        self.customer_order.refresh_from_db()
        self.assertEqual(self.customer_order.status, Order.Status.AWAITING_LOCKER)