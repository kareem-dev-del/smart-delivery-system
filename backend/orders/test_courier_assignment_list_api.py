from decimal import Decimal

from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import UserProfile
from lockers.models import Drawer, LockerStation

from .models import Order


User = get_user_model()


class CourierAssignmentListAPIViewTests(APITestCase):
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
            number=3,
            size=Drawer.Size.SMALL,
            status=Drawer.Status.RESERVED,
        )

        self.return_drawer = Drawer.objects.create(
            locker_station=self.locker,
            number=4,
            size=Drawer.Size.SMALL,
            status=Drawer.Status.RETURN_PENDING,
        )

        self.assigned_order = Order.objects.create(
            customer=self.customer,
            assigned_courier=self.courier,
            status=Order.Status.ASSIGNED,
            locker_station=self.locker,
            assigned_drawer=self.drawer,
            total_amount=Decimal("20.00"),
        )

        self.awaiting_locker_order = Order.objects.create(
            customer=self.customer,
            assigned_courier=self.courier,
            status=Order.Status.AWAITING_LOCKER,
            total_amount=Decimal("30.00"),
        )

        self.expired_order = Order.objects.create(
            customer=self.customer,
            assigned_courier=self.courier,
            status=Order.Status.EXPIRED,
            locker_station=self.locker,
            assigned_drawer=self.return_drawer,
            total_amount=Decimal("40.00"),
        )

        self.other_courier_order = Order.objects.create(
            customer=self.customer,
            assigned_courier=self.other_courier,
            status=Order.Status.ASSIGNED,
            locker_station=self.locker,
            assigned_drawer=self.drawer,
            total_amount=Decimal("50.00"),
        )

    def assignments_url(self):
        return reverse("courier-assignment-list")

    def test_unauthenticated_user_cannot_see_assignments(self):
        response = self.client.get(self.assignments_url())

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_customer_cannot_see_courier_assignments(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.get(self.assignments_url())

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_courier_sees_only_own_active_assignments(self):
        self.client.force_authenticate(user=self.courier)

        response = self.client.get(self.assignments_url())

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 2)

        orders_by_id = {
            order["public_id"]: order
            for order in response.data
        }

        self.assertEqual(
            set(orders_by_id),
            {
                str(self.assigned_order.public_id),
                str(self.awaiting_locker_order.public_id),
            },
        )

        assigned_order = orders_by_id[
            str(self.assigned_order.public_id)
        ]

        self.assertEqual(
            assigned_order["status"],
            Order.Status.ASSIGNED,
        )
        self.assertEqual(
            assigned_order["locker_code"],
            "NASR-001",
        )
        self.assertEqual(
            assigned_order["drawer_number"],
            3,
        )

        awaiting_order = orders_by_id[
            str(self.awaiting_locker_order.public_id)
        ]

        self.assertEqual(
            awaiting_order["status"],
            Order.Status.AWAITING_LOCKER,
        )
        self.assertIsNone(awaiting_order["locker_name"])
        self.assertIsNone(awaiting_order["drawer_number"])