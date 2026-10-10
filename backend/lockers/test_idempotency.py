from uuid import uuid4

from django.utils import timezone
from datetime import timedelta

from django.contrib.auth import get_user_model
from django.test import RequestFactory, TestCase

from accounts.models import UserProfile
from lockers.idempotency import (
    IdempotencyConflict,
    build_request_hash,
    get_replay_receipt,
    parse_idempotency_key,
    can_replay_open_command,
)
from lockers.models import (
    LockerDevice,
    LockerDeviceRequest,
    LockerStation,
)


User = get_user_model()


class LockerIdempotencyTests(TestCase):
    def setUp(self):
        self.factory = RequestFactory()

        locker_station = LockerStation.objects.create(
            name="Nasr City Locker",
            code="NASR-001",
            address="Nasr City, Cairo",
            latitude="30.062630",
            longitude="31.335220",
            status=LockerStation.Status.ONLINE,
        )

        device_user = User.objects.create_user(
            username="nasr-device",
            password="test-password",
        )
        device_user.profile.role = UserProfile.Role.LOCKER_DEVICE
        device_user.profile.save(update_fields=("role",))

        self.locker_device = LockerDevice.objects.create(
            locker_station=locker_station,
            user=device_user,
            device_code="NASR-001-CONTROLLER",
        )

    def test_parses_a_valid_idempotency_key_from_request_header(self):
        idempotency_key = uuid4()
        request = self.factory.post(
            "/",
            HTTP_IDEMPOTENCY_KEY=str(idempotency_key),
        )

        parsed_key = parse_idempotency_key(request)

        self.assertEqual(parsed_key, idempotency_key)

    def test_request_hash_is_stable_for_same_payload(self):
        payload = {
            "order_public_id": "00000000-0000-0000-0000-000000000001",
        }

        first_hash = build_request_hash(
            operation=(
                LockerDeviceRequest.Operation.DEPOSIT_CONFIRMATION
            ),
            payload=payload,
        )
        second_hash = build_request_hash(
            operation=(
                LockerDeviceRequest.Operation.DEPOSIT_CONFIRMATION
            ),
            payload=payload,
        )

        self.assertEqual(first_hash, second_hash)

    def test_replay_receipt_is_returned_for_same_request(self):
        idempotency_key = uuid4()
        request_hash = build_request_hash(
            operation=(
                LockerDeviceRequest.Operation.DEPOSIT_CONFIRMATION
            ),
            payload={"order_public_id": "example-order"},
        )

        receipt = LockerDeviceRequest.objects.create(
            locker_device=self.locker_device,
            operation=(
                LockerDeviceRequest.Operation.DEPOSIT_CONFIRMATION
            ),
            idempotency_key=idempotency_key,
            request_hash=request_hash,
            response_status=200,
            response_body={"status": "ready_for_pickup"},
        )

        replay_receipt = get_replay_receipt(
            locker_device=self.locker_device,
            idempotency_key=idempotency_key,
            operation=(
                LockerDeviceRequest.Operation.DEPOSIT_CONFIRMATION
            ),
            request_hash=request_hash,
        )

        self.assertEqual(replay_receipt.id, receipt.id)

    def test_reused_key_with_different_request_is_rejected(self):
        idempotency_key = uuid4()

        LockerDeviceRequest.objects.create(
            locker_device=self.locker_device,
            operation=(
                LockerDeviceRequest.Operation.DEPOSIT_CONFIRMATION
            ),
            idempotency_key=idempotency_key,
            request_hash="a" * 64,
            response_status=200,
            response_body={"status": "ready_for_pickup"},
        )

        with self.assertRaises(IdempotencyConflict) as context:
            get_replay_receipt(
                locker_device=self.locker_device,
                idempotency_key=idempotency_key,
                operation=(
                    LockerDeviceRequest.Operation.DEPOSIT_CONFIRMATION
                ),
                request_hash="b" * 64,
            )

        self.assertEqual(context.exception.status_code, 409)

    def test_open_command_can_only_be_replayed_inside_window(self):
        receipt = LockerDeviceRequest.objects.create(
            locker_device=self.locker_device,
            operation=LockerDeviceRequest.Operation.PICKUP_SCAN,
            idempotency_key=uuid4(),
            request_hash="a" * 64,
            response_status=200,
            response_body={
                "command": "open_drawer",
                "drawer_number": 1,
            },
        )

        now = timezone.now()

        receipt.processed_at = now - timedelta(seconds=30)
        receipt.save(update_fields=("processed_at",))

        self.assertTrue(
            can_replay_open_command(
                receipt=receipt,
                now=now,
            )
        )

        receipt.processed_at = now - timedelta(seconds=61)
        receipt.save(update_fields=("processed_at",))

        self.assertFalse(
            can_replay_open_command(
                receipt=receipt,
                now=now,
            )
        )

