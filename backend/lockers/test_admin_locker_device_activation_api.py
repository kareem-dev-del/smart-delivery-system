from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import UserProfile
from audit.models import AuditLog

from .models import LockerDevice, LockerStation


User = get_user_model()


class AdminLockerDeviceActivationAPIViewTests(APITestCase):
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

    def url(self):
        return reverse(
            "admin-locker-device-activation",
            kwargs={"device_id": self.locker_device.id},
        )

    def test_customer_cannot_change_device_activation(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.patch(
            self.url(),
            {"is_active": False},
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_403_FORBIDDEN,
        )

    def test_admin_can_deactivate_device_and_offline_locker(self):
        self.client.force_authenticate(user=self.admin)

        response = self.client.patch(
            self.url(),
            {"is_active": False},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertFalse(response.data["is_active"])

        self.locker_device.refresh_from_db()
        self.locker_station.refresh_from_db()

        self.assertFalse(self.locker_device.is_active)
        self.assertEqual(
            self.locker_station.status,
            LockerStation.Status.OFFLINE,
        )

        self.assertTrue(
            AuditLog.objects.filter(
                actor=self.admin,
                action=AuditLog.Action.LOCKER_DEVICE_DEACTIVATED,
                target_id=str(self.locker_device.id),
            ).exists()
        )

    def test_reactivation_does_not_automatically_online_locker(self):
        self.locker_device.is_active = False
        self.locker_device.save(update_fields=("is_active",))

        self.locker_station.status = LockerStation.Status.OFFLINE
        self.locker_station.save(update_fields=("status",))

        self.client.force_authenticate(user=self.admin)

        response = self.client.patch(
            self.url(),
            {"is_active": True},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data["is_active"])

        self.locker_station.refresh_from_db()

        self.assertEqual(
            self.locker_station.status,
            LockerStation.Status.OFFLINE,
        )