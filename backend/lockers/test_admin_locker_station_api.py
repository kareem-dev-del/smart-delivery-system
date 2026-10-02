from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import UserProfile

from .models import LockerStation


User = get_user_model()


class AdminLockerStationAPIViewTests(APITestCase):
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

    def create_url(self):
        return reverse("admin-locker-station-create")

    def update_url(self):
        return reverse(
            "admin-locker-station-update",
            kwargs={"pk": self.locker.id},
        )

    def test_unauthenticated_user_cannot_create_locker(self):
        response = self.client.post(
            self.create_url(),
            {},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_customer_cannot_create_locker(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.post(
            self.create_url(),
            {},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_admin_can_create_locker_with_normalized_code(self):
        self.client.force_authenticate(user=self.admin_user)

        response = self.client.post(
            self.create_url(),
            {
                "name": "Dokki Locker",
                "code": "dokki-001",
                "address": "Dokki, Giza",
                "latitude": "30.038345",
                "longitude": "31.210984",
                "status": LockerStation.Status.ONLINE,
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["code"], "DOKKI-001")

        self.assertTrue(
            LockerStation.objects.filter(
                code="DOKKI-001",
                name="Dokki Locker",
            ).exists()
        )

    def test_admin_can_partially_update_locker_status(self):
        self.client.force_authenticate(user=self.admin_user)

        response = self.client.patch(
            self.update_url(),
            {
                "status": LockerStation.Status.MAINTENANCE,
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            response.data["status"],
            LockerStation.Status.MAINTENANCE,
        )

        self.locker.refresh_from_db()

        self.assertEqual(
            self.locker.status,
            LockerStation.Status.MAINTENANCE,
        )

    def test_rejects_invalid_locker_coordinates(self):
        self.client.force_authenticate(user=self.admin_user)

        response = self.client.post(
            self.create_url(),
            {
                "name": "Invalid Locker",
                "code": "INVALID-001",
                "address": "Unknown",
                "latitude": "91.000000",
                "longitude": "31.210984",
                "status": LockerStation.Status.ONLINE,
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("latitude", response.data)

        self.assertFalse(
            LockerStation.objects.filter(
                code="INVALID-001"
            ).exists()
        )

    def test_rejects_duplicate_locker_code(self):
        self.client.force_authenticate(user=self.admin_user)

        response = self.client.post(
            self.create_url(),
            {
                "name": "Duplicate Locker",
                "code": "nasr-001",
                "address": "Another address",
                "latitude": "30.000000",
                "longitude": "31.000000",
                "status": LockerStation.Status.ONLINE,
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("code", response.data)