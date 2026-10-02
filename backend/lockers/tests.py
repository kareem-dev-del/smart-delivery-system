from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import UserProfile
from .models import Drawer, LockerStation


User = get_user_model()


class LockerStationAPIViewTests(APITestCase):
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

        self.online_locker = LockerStation.objects.create(
            name="Nasr City Locker",
            code="NASR-001",
            address="Nasr City, Cairo",
            latitude="30.062630",
            longitude="31.335220",
            status=LockerStation.Status.ONLINE,
        )

        self.offline_locker = LockerStation.objects.create(
            name="Maadi Locker",
            code="MAADI-001",
            address="Maadi, Cairo",
            latitude="29.960235",
            longitude="31.256540",
            status=LockerStation.Status.OFFLINE,
        )

        Drawer.objects.create(
            locker_station=self.online_locker,
            number=1,
            size=Drawer.Size.SMALL,
            status=Drawer.Status.AVAILABLE,
        )

        Drawer.objects.create(
            locker_station=self.online_locker,
            number=2,
            size=Drawer.Size.MEDIUM,
            status=Drawer.Status.OCCUPIED,
        )

        Drawer.objects.create(
            locker_station=self.offline_locker,
            number=1,
            size=Drawer.Size.LARGE,
            status=Drawer.Status.AVAILABLE,
        )

    def test_unauthenticated_user_cannot_list_lockers(self):
        response = self.client.get(reverse("locker-list"))

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_customer_sees_only_online_lockers(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.get(reverse("locker-list"))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]["id"], self.online_locker.id)
        self.assertEqual(response.data[0]["available_drawers_count"], 1)

    def test_admin_sees_all_lockers(self):
        self.client.force_authenticate(user=self.admin_user)

        response = self.client.get(reverse("locker-list"))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 2)

    def test_customer_can_retrieve_online_locker_details(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.get(
            reverse("locker-detail", kwargs={"pk": self.online_locker.id})
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["code"], "NASR-001")
        self.assertEqual(len(response.data["drawers"]), 2)

    def test_customer_cannot_retrieve_offline_locker(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.get(
            reverse("locker-detail", kwargs={"pk": self.offline_locker.id})
        )

        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_admin_can_retrieve_offline_locker(self):
        self.client.force_authenticate(user=self.admin_user)

        response = self.client.get(
            reverse("locker-detail", kwargs={"pk": self.offline_locker.id})
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["code"], "MAADI-001")