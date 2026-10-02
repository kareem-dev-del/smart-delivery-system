from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import UserProfile

from .models import LockerDevice, LockerStation


User = get_user_model()


class AdminLockerDeviceProvisionAPIViewTests(APITestCase):
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

        self.other_locker = LockerStation.objects.create(
            name="Maadi Locker",
            code="MAADI-001",
            address="Maadi, Cairo",
            latitude="29.960235",
            longitude="31.256540",
            status=LockerStation.Status.ONLINE,
        )

    def provision_url(self, locker):
        return reverse(
            "admin-locker-device-provision",
            kwargs={"locker_station_id": locker.id},
        )

    def test_unauthenticated_user_cannot_provision_device(self):
        response = self.client.post(
            self.provision_url(self.locker),
            {},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_customer_cannot_provision_device(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.post(
            self.provision_url(self.locker),
            {
                "device_code": "NASR-001-CONTROLLER",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_admin_can_provision_locker_device(self):
        self.client.force_authenticate(user=self.admin_user)

        response = self.client.post(
            self.provision_url(self.locker),
            {
                "device_code": "nasr-001-controller",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(
            response.data["device_code"],
            "NASR-001-CONTROLLER",
        )
        self.assertEqual(response.data["locker_code"], "NASR-001")
        self.assertIn("username", response.data)
        self.assertIn("initial_password", response.data)
        self.assertEqual(response["Cache-Control"], "no-store")

        device = LockerDevice.objects.get(
            locker_station=self.locker
        )

        self.assertTrue(device.is_active)
        self.assertEqual(
            device.user.profile.role,
            UserProfile.Role.LOCKER_DEVICE,
        )
        self.assertTrue(
            device.user.check_password(
                response.data["initial_password"]
            )
        )

    def test_admin_cannot_provision_second_device_for_same_locker(self):
        self.client.force_authenticate(user=self.admin_user)

        self.client.post(
            self.provision_url(self.locker),
            {
                "device_code": "NASR-001-CONTROLLER",
            },
            format="json",
        )

        response = self.client.post(
            self.provision_url(self.locker),
            {
                "device_code": "NASR-001-BACKUP",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("locker_station", response.data)

    def test_admin_cannot_reuse_device_code_for_another_locker(self):
        self.client.force_authenticate(user=self.admin_user)

        self.client.post(
            self.provision_url(self.locker),
            {
                "device_code": "SHARED-CONTROLLER",
            },
            format="json",
        )

        response = self.client.post(
            self.provision_url(self.other_locker),
            {
                "device_code": "SHARED-CONTROLLER",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("device_code", response.data)