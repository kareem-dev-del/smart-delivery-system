from decimal import Decimal

from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError
from django.test import TestCase

from lockers.models import Drawer, LockerStation
from products.models import Product

from .models import Order
from .services import assign_order_to_drawer, create_order


User = get_user_model()


class AssignOrderToDrawerServiceTests(TestCase):
    def setUp(self):
        self.customer = User.objects.create_user(
            username="customer",
            password="test-password",
        )

        self.small_product = Product.objects.create(
            name="USB Cable",
            price=Decimal("20.00"),
            stock=30,
            size=Product.Size.SMALL,
        )

        self.large_product = Product.objects.create(
            name="Monitor",
            price=Decimal("5000.00"),
            stock=10,
            size=Product.Size.LARGE,
        )

        self.online_locker = LockerStation.objects.create(
            name="Nasr City Locker",
            code="NASR-001",
            address="Nasr City, Cairo",
            latitude="30.062630",
            longitude="31.335220",
            status=LockerStation.Status.ONLINE,
        )

        self.other_locker = LockerStation.objects.create(
            name="Maadi Locker",
            code="MAADI-001",
            address="Maadi, Cairo",
            latitude="29.960235",
            longitude="31.256540",
            status=LockerStation.Status.ONLINE,
        )

        self.offline_locker = LockerStation.objects.create(
            name="Dokki Locker",
            code="DOKKI-001",
            address="Dokki, Cairo",
            latitude="30.038000",
            longitude="31.210000",
            status=LockerStation.Status.OFFLINE,
        )

        self.small_drawer = Drawer.objects.create(
            locker_station=self.online_locker,
            number=1,
            size=Drawer.Size.SMALL,
            status=Drawer.Status.AVAILABLE,
        )

        self.large_drawer = Drawer.objects.create(
            locker_station=self.online_locker,
            number=2,
            size=Drawer.Size.LARGE,
            status=Drawer.Status.AVAILABLE,
        )

        self.occupied_drawer = Drawer.objects.create(
            locker_station=self.online_locker,
            number=3,
            size=Drawer.Size.MEDIUM,
            status=Drawer.Status.OCCUPIED,
        )

        self.other_locker_drawer = Drawer.objects.create(
            locker_station=self.other_locker,
            number=1,
            size=Drawer.Size.SMALL,
            status=Drawer.Status.AVAILABLE,
        )

        self.offline_locker_drawer = Drawer.objects.create(
            locker_station=self.offline_locker,
            number=1,
            size=Drawer.Size.SMALL,
            status=Drawer.Status.AVAILABLE,
        )

    def create_order_for_product(self, product):
        return create_order(
            customer=self.customer,
            items=[
                {"product_id": product.id, "quantity": 1},
            ],
        )

    def test_assigns_order_and_reserves_drawer(self):
        order = self.create_order_for_product(self.small_product)

        assigned_order = assign_order_to_drawer(
            order_public_id=order.public_id,
            locker_station_id=self.online_locker.id,
            drawer_id=self.small_drawer.id,
        )

        self.assertEqual(assigned_order.status, Order.Status.ASSIGNED)
        self.assertEqual(assigned_order.locker_station, self.online_locker)
        self.assertEqual(assigned_order.assigned_drawer, self.small_drawer)

        self.small_drawer.refresh_from_db()
        self.assertEqual(self.small_drawer.status, Drawer.Status.RESERVED)

    def test_rejects_drawer_from_another_locker(self):
        order = self.create_order_for_product(self.small_product)

        with self.assertRaises(ValidationError):
            assign_order_to_drawer(
                order_public_id=order.public_id,
                locker_station_id=self.online_locker.id,
                drawer_id=self.other_locker_drawer.id,
            )

        order.refresh_from_db()
        self.assertIsNone(order.assigned_drawer)

    def test_rejects_unavailable_drawer(self):
        order = self.create_order_for_product(self.small_product)

        with self.assertRaises(ValidationError):
            assign_order_to_drawer(
                order_public_id=order.public_id,
                locker_station_id=self.online_locker.id,
                drawer_id=self.occupied_drawer.id,
            )

        self.occupied_drawer.refresh_from_db()
        self.assertEqual(self.occupied_drawer.status, Drawer.Status.OCCUPIED)

    def test_rejects_offline_locker(self):
        order = self.create_order_for_product(self.small_product)

        with self.assertRaises(ValidationError):
            assign_order_to_drawer(
                order_public_id=order.public_id,
                locker_station_id=self.offline_locker.id,
                drawer_id=self.offline_locker_drawer.id,
            )

        order.refresh_from_db()
        self.assertEqual(order.status, Order.Status.AWAITING_LOCKER)

    def test_rejects_drawer_that_is_too_small(self):
        order = self.create_order_for_product(self.large_product)

        with self.assertRaises(ValidationError):
            assign_order_to_drawer(
                order_public_id=order.public_id,
                locker_station_id=self.online_locker.id,
                drawer_id=self.small_drawer.id,
            )

        self.small_drawer.refresh_from_db()
        self.assertEqual(self.small_drawer.status, Drawer.Status.AVAILABLE)