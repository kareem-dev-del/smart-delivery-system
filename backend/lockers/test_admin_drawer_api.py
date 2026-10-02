from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import UserProfile

from .models import Drawer, LockerStation


User = get_user_model()


class AdminDrawerAPIViewTests(APITestCase):
    def setUp(self):
        self.customer = User.objects.create_user(
            username="customer",
            password="test-password",
        )

        self.admin_user = User.objects.create_user(
            username="admin",
            password="test-password",
            is_staff=True,
        )

        self.customer.profile.role = UserProfile.Role.CUSTOMER
        self.customer.profile.save(update_fields=("role",))

        self.admin_user.profile.role = UserProfile.Role.ADMIN
        self.admin_user.profile.save(update_fields=("role",))

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

    def create_url(self):
        return reverse(
            "admin-drawer-create",
            kwargs={"locker_station_id": self.locker.id},
        )

    def maintenance_url(self, drawer):
        return reverse(
            "admin-drawer-maintenance-status",
            kwargs={"drawer_id": drawer.id},
        )

    def test_unauthenticated_user_cannot_create_drawer(self):
        response = self.client.post(
            self.create_url(),
            {},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_customer_cannot_create_drawer(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.post(
            self.create_url(),
            {
                "number": 3,
                "size": Drawer.Size.LARGE,
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_admin_can_create_available_drawer(self):
        self.client.force_authenticate(user=self.admin_user)

        response = self.client.post(
            self.create_url(),
            {
                "number": 3,
                "size": Drawer.Size.LARGE,
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["number"], 3)
        self.assertEqual(response.data["size"], Drawer.Size.LARGE)
        self.assertEqual(
            response.data["status"],
            Drawer.Status.AVAILABLE,
        )

    def test_admin_cannot_create_duplicate_drawer_number(self):
        self.client.force_authenticate(user=self.admin_user)

        response = self.client.post(
            self.create_url(),
            {
                "number": 1,
                "size": Drawer.Size.LARGE,
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("number", response.data)

    def test_admin_can_take_available_drawer_out_of_service(self):
        self.client.force_authenticate(user=self.admin_user)

        response = self.client.patch(
            self.maintenance_url(self.available_drawer),
            {
                "status": Drawer.Status.OUT_OF_SERVICE,
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            response.data["status"],
            Drawer.Status.OUT_OF_SERVICE,
        )

        self.available_drawer.refresh_from_db()

        self.assertEqual(
            self.available_drawer.status,
            Drawer.Status.OUT_OF_SERVICE,
        )

    def test_admin_can_restore_drawer_to_available(self):
        self.available_drawer.status = Drawer.Status.OUT_OF_SERVICE
        self.available_drawer.save(update_fields=("status",))

        self.client.force_authenticate(user=self.admin_user)

        response = self.client.patch(
            self.maintenance_url(self.available_drawer),
            {
                "status": Drawer.Status.AVAILABLE,
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)

        self.available_drawer.refresh_from_db()

        self.assertEqual(
            self.available_drawer.status,
            Drawer.Status.AVAILABLE,
        )

    def test_admin_cannot_take_occupied_drawer_out_of_service(self):
        self.client.force_authenticate(user=self.admin_user)

        response = self.client.patch(
            self.maintenance_url(self.occupied_drawer),
            {
                "status": Drawer.Status.OUT_OF_SERVICE,
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

        self.occupied_drawer.refresh_from_db()

        self.assertEqual(
            self.occupied_drawer.status,
            Drawer.Status.OCCUPIED,
        )

    def test_admin_cannot_manually_set_drawer_to_occupied(self):
        self.client.force_authenticate(user=self.admin_user)

        response = self.client.patch(
            self.maintenance_url(self.available_drawer),
            {
                "status": Drawer.Status.OCCUPIED,
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)