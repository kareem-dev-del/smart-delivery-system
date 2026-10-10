from drf_spectacular.utils import OpenApiParameter, OpenApiTypes


LOCKER_DEVICE_IDEMPOTENCY_KEY_PARAMETER = OpenApiParameter(
    name="Idempotency-Key",
    type=OpenApiTypes.UUID,
    location=OpenApiParameter.HEADER,
    required=True,
    description=(
        "A UUID generated once for one physical device operation. "
        "Reuse the same value only when retrying that exact request."
    ),
)