from uuid import uuid4

from django.contrib.auth import get_user_model
from django.db import IntegrityError, transaction
from django.test import TestCase

from accounts.models import UserProfile
from lockers.models import (
    LockerDevice,
    LockerDeviceRequest,
    LockerStation,
)


User = get_user_model()


class LockerDeviceRequestModelTests(TestCase):
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

    def create_request_receipt(self, *, idempotency_key):
        return LockerDeviceRequest.objects.create(
            locker_device=self.locker_device,
            operation=(
                LockerDeviceRequest.Operation.DEPOSIT_CONFIRMATION
            ),
            idempotency_key=idempotency_key,
            request_hash="a" * 64,
            response_status=200,
            response_body={
                "status": "ready_for_pickup",
                "drawer_number": 1,
            },
        )

    def test_stores_a_device_request_receipt(self):
        idempotency_key = uuid4()

        receipt = self.create_request_receipt(
            idempotency_key=idempotency_key,
        )

        self.assertEqual(
            receipt.operation,
            LockerDeviceRequest.Operation.DEPOSIT_CONFIRMATION,
        )
        self.assertEqual(receipt.idempotency_key, idempotency_key)
        self.assertEqual(receipt.response_status, 200)
        self.assertEqual(
            receipt.response_body["status"],
            "ready_for_pickup",
        )
        self.assertIsNotNone(receipt.processed_at)

    def test_same_device_cannot_reuse_an_idempotency_key(self):
        idempotency_key = uuid4()
        self.create_request_receipt(
            idempotency_key=idempotency_key,
        )

        with self.assertRaises(IntegrityError):
            with transaction.atomic():
                self.create_request_receipt(
                    idempotency_key=idempotency_key,
                )

        self.assertEqual(LockerDeviceRequest.objects.count(), 1)