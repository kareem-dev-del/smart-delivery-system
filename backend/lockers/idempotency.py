import json
from uuid import UUID
from datetime import timedelta

from django.conf import settings
from django.utils import timezone

from django.utils.crypto import constant_time_compare, salted_hmac
from rest_framework import status
from rest_framework.exceptions import APIException, ValidationError

from .models import LockerDeviceRequest


class IdempotencyConflict(APIException):
    status_code = status.HTTP_409_CONFLICT
    default_detail = (
        "This Idempotency-Key has already been used for "
        "a different request."
    )
    default_code = "idempotency_key_conflict"

class OpenCommandReplayUnavailable(APIException):
    status_code = status.HTTP_409_CONFLICT
    default_detail = (
        "The cached open-drawer command can no longer be replayed."
    )
    default_code = "open_command_replay_unavailable"



def parse_idempotency_key(request):
    raw_key = request.headers.get("Idempotency-Key")

    if not raw_key:
        raise ValidationError(
            {
                "idempotency_key": (
                    "The Idempotency-Key header is required."
                )
            }
        )

    try:
        return UUID(raw_key.strip())
    except (AttributeError, ValueError) as error:
        raise ValidationError(
            {
                "idempotency_key": (
                    "The Idempotency-Key header must be a valid UUID."
                )
            }
        ) from error


def build_request_hash(*, operation, payload):
    serialized_payload = json.dumps(
        {
            "operation": operation,
            "payload": payload,
        },
        ensure_ascii=True,
        separators=(",", ":"),
        sort_keys=True,
    )

    return salted_hmac(
        "locker-device-request-v1",
        serialized_payload,
    ).hexdigest()


def get_replay_receipt(
    *,
    locker_device,
    idempotency_key,
    operation,
    request_hash,
):
    receipt = (
        LockerDeviceRequest.objects.select_related("order")
        .filter(
            locker_device=locker_device,
            idempotency_key=idempotency_key,
        )
        .first()
    )

    if receipt is None:
        return None

    if (
        receipt.operation != operation
        or not constant_time_compare(
            receipt.request_hash,
            request_hash,
        )
    ):
        raise IdempotencyConflict()

    return receipt


def create_completed_receipt(
    *,
    locker_device,
    order,
    operation,
    idempotency_key,
    request_hash,
    response_status,
    response_body,
):
    return LockerDeviceRequest.objects.create(
        locker_device=locker_device,
        order=order,
        operation=operation,
        idempotency_key=idempotency_key,
        request_hash=request_hash,
        response_status=response_status,
        response_body=response_body,
    )


def can_replay_open_command(*, receipt, now=None):
    now = now or timezone.now()

    replay_window = timedelta(
        seconds=settings.LOCKER_DEVICE_OPEN_COMMAND_REPLAY_SECONDS
    )
    replay_deadline = receipt.processed_at + replay_window

    return now <= replay_deadline