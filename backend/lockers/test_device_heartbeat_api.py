from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import UserProfile
from .models import LockerDevice, LockerStation


User = get_user_model()


class LockerDeviceHeartbeatAPIViewTests(APITestCase):
    def setUp(self):
        self.locker_station = LockerStation.objects.create(
            name="Nasr City Locker",
            code="NASR-001",
            address="Nasr City, Cairo",
            latitude="30.062630",
            longitude="31.335220",
            status=LockerStation.Status.ONLINE,
        )

        self.device_user = User.objects.create_user(
            username="nasr-device",
            password="test-password",
        )
        self.device_user.profile.role = UserProfile.Role.LOCKER_DEVICE
        self.device_user.profile.save(update_fields=("role",))

        self.locker_device = LockerDevice.objects.create(
            locker_station=self.locker_station,
            user=self.device_user,
            device_code="NASR-001-CONTROLLER",
        )

        self.customer = User.objects.create_user(
            username="customer",
            password="test-password",
        )
        self.customer.profile.role = UserProfile.Role.CUSTOMER
        self.customer.profile.save(update_fields=("role",))

    def test_unauthenticated_request_is_rejected(self):
        response = self.client.post(
            reverse("locker-device-heartbeat"),
            {},
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_401_UNAUTHORIZED,
        )

    def test_customer_cannot_send_device_heartbeat(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.post(
            reverse("locker-device-heartbeat"),
            {},
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_403_FORBIDDEN,
        )

    def test_active_locker_device_can_send_heartbeat(self):
        self.client.force_authenticate(user=self.device_user)

        response = self.client.post(
            reverse("locker-device-heartbeat"),
            {},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            response.data["device_code"],
            "NASR-001-CONTROLLER",
        )
        self.assertEqual(response.data["locker_code"], "NASR-001")
        self.assertEqual(
            response.data["locker_status"],
            LockerStation.Status.ONLINE,
        )

        self.locker_device.refresh_from_db()
        self.assertIsNotNone(self.locker_device.last_heartbeat_at)

    def test_inactive_device_cannot_send_heartbeat(self):
        self.locker_device.is_active = False
        self.locker_device.save(update_fields=("is_active",))

        self.client.force_authenticate(user=self.device_user)

        response = self.client.post(
            reverse("locker-device-heartbeat"),
            {},
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_400_BAD_REQUEST,
        )
        self.assertIn("device", response.data)