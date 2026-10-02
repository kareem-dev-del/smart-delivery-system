from datetime import timedelta

from django.contrib.auth import get_user_model
from django.test import override_settings
from django.urls import reverse
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import UserProfile
from .models import LockerDevice, LockerStation


User = get_user_model()


@override_settings(LOCKER_DEVICE_HEARTBEAT_TIMEOUT_SECONDS=60)
class AdminLockerDeviceListAPIViewTests(APITestCase):
    def setUp(self):
        self.admin = User.objects.create_user(
            username="admin",
            password="test-password",
            is_staff=True,
        )
        self.admin.profile.role = UserProfile.Role.ADMIN
        self.admin.profile.save(update_fields=("role",))

        self.customer = User.objects.create_user(
            username="customer",
            password="test-password",
        )
        self.customer.profile.role = UserProfile.Role.CUSTOMER
        self.customer.profile.save(update_fields=("role",))

        self.online_device = self.create_device(
            locker_code="NASR-001",
            device_code="NASR-001-CONTROLLER",
            last_heartbeat_at=timezone.now(),
        )

        self.stale_device = self.create_device(
            locker_code="MAADI-001",
            device_code="MAADI-001-CONTROLLER",
            last_heartbeat_at=timezone.now() - timedelta(seconds=61),
        )

        self.never_connected_device = self.create_device(
            locker_code="ZAYED-001",
            device_code="ZAYED-001-CONTROLLER",
        )

        self.inactive_device = self.create_device(
            locker_code="HELIO-001",
            device_code="HELIO-001-CONTROLLER",
            is_active=False,
            last_heartbeat_at=timezone.now(),
        )

    def create_device(
        self,
        *,
        locker_code,
        device_code,
        is_active=True,
        last_heartbeat_at=None,
    ):
        locker_station = LockerStation.objects.create(
            name=f"{locker_code} Locker",
            code=locker_code,
            address="Cairo, Egypt",
            latitude="30.000000",
            longitude="31.000000",
            status=LockerStation.Status.ONLINE,
        )

        device_user = User.objects.create_user(
            username=f"{device_code.lower()}-user",
            password="test-password",
        )
        device_user.profile.role = UserProfile.Role.LOCKER_DEVICE
        device_user.profile.save(update_fields=("role",))

        return LockerDevice.objects.create(
            locker_station=locker_station,
            user=device_user,
            device_code=device_code,
            is_active=is_active,
            last_heartbeat_at=last_heartbeat_at,
        )

    def test_unauthenticated_user_cannot_list_devices(self):
        response = self.client.get(
            reverse("admin-locker-device-list")
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_401_UNAUTHORIZED,
        )

    def test_customer_cannot_list_devices(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.get(
            reverse("admin-locker-device-list")
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_403_FORBIDDEN,
        )

    def test_admin_can_see_device_connection_statuses(self):
        self.client.force_authenticate(user=self.admin)

        response = self.client.get(
            reverse("admin-locker-device-list")
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 4)

        statuses_by_device_code = {
            item["device_code"]: item["connection_status"]
            for item in response.data
        }

        self.assertEqual(
            statuses_by_device_code["NASR-001-CONTROLLER"],
            LockerDevice.ConnectionStatus.ONLINE,
        )
        self.assertEqual(
            statuses_by_device_code["MAADI-001-CONTROLLER"],
            LockerDevice.ConnectionStatus.STALE,
        )
        self.assertEqual(
            statuses_by_device_code["ZAYED-001-CONTROLLER"],
            LockerDevice.ConnectionStatus.NEVER_CONNECTED,
        )
        self.assertEqual(
            statuses_by_device_code["HELIO-001-CONTROLLER"],
            LockerDevice.ConnectionStatus.INACTIVE,
        )