from datetime import timedelta
from django.conf import settings
from django.db.models import Count, Q

from django.core.exceptions import ValidationError
import secrets


from django.contrib.auth import get_user_model
from django.db import transaction

from .models import Drawer, LockerDevice, LockerStation

from accounts.models import UserProfile
from django.utils import timezone
from audit.models import AuditLog
from audit.services import create_audit_log


User = get_user_model()


@transaction.atomic
def create_drawer(*, locker_station_id, number, size, actor=None):
    try:
        locker_station = (
            LockerStation.objects.select_for_update()
            .get(pk=locker_station_id)
        )
    except LockerStation.DoesNotExist as error:
        raise ValidationError(
            {"locker_station": "Locker station not found."}
        ) from error

    if Drawer.objects.filter(
        locker_station=locker_station,
        number=number,
    ).exists():
        raise ValidationError(
            {"number": "Drawer number already exists in this locker."}
        )

    drawer = Drawer.objects.create(
    locker_station=locker_station,
    number=number,
    size=size,
    )  

    create_audit_log(
        actor=actor,
        action=AuditLog.Action.DRAWER_CREATED,
        target_type=AuditLog.TargetType.DRAWER,
        target_id=drawer.id,
        metadata={
            "locker_station_id": locker_station.id,
            "drawer_number": drawer.number,
            "size": drawer.size,
        },
    )

    return drawer


@transaction.atomic
def update_drawer_maintenance_status(*, drawer_id, target_status,actor=None):
    try:
        drawer = Drawer.objects.select_for_update().get(pk=drawer_id)
    except Drawer.DoesNotExist as error:
        raise ValidationError(
            {"drawer": "Drawer not found."}
        ) from error
    previous_status = drawer.status
    allowed_statuses = {
        Drawer.Status.AVAILABLE,
        Drawer.Status.OUT_OF_SERVICE,
    }

    if target_status not in allowed_statuses:
        raise ValidationError(
            {"status": "Only maintenance statuses can be changed here."}
        )

    if drawer.status == target_status:
        return drawer

    allowed_transitions = {
        Drawer.Status.AVAILABLE: {
            Drawer.Status.OUT_OF_SERVICE,
        },
        Drawer.Status.OUT_OF_SERVICE: {
            Drawer.Status.AVAILABLE,
        },
    }

    if target_status not in allowed_transitions.get(
        drawer.status,
        set(),
    ):
        raise ValidationError(
            {
                "status": (
                    "Only an available drawer can be taken out of service, "
                    "and only an out-of-service drawer can be restored."
                )
            }
        )

    drawer.status = target_status
    drawer.save(update_fields=("status", "updated_at"))
    create_audit_log(
    actor=actor,
    action=AuditLog.Action.DRAWER_MAINTENANCE_STATUS_CHANGED,
    target_type=AuditLog.TargetType.DRAWER,
    target_id=drawer.id,
    metadata={
        "previous_status": previous_status,
        "new_status": drawer.status,
        "locker_station_id": drawer.locker_station_id,
    },
    )

    return drawer



@transaction.atomic
def provision_locker_device(*, locker_station_id, device_code, actor=None):
    try:
        locker_station = (
            LockerStation.objects.select_for_update()
            .get(pk=locker_station_id)
        )
    except LockerStation.DoesNotExist as error:
        raise ValidationError(
            {"locker_station": "Locker station not found."}
        ) from error

    if LockerDevice.objects.filter(
        locker_station=locker_station
    ).exists():
        raise ValidationError(
            {"locker_station": "This locker already has a device."}
        )

    if LockerDevice.objects.filter(
        device_code=device_code
    ).exists():
        raise ValidationError(
            {"device_code": "Device code already exists."}
        )

    username = (
        f"locker-device-{locker_station.id}-"
        f"{secrets.token_hex(4)}"
    )

    initial_password = secrets.token_urlsafe(32)

    user = User.objects.create_user(
        username=username,
        password=initial_password,
    )

    user.profile.role = UserProfile.Role.LOCKER_DEVICE
    user.profile.save(update_fields=("role",))

    locker_device = LockerDevice(
        locker_station=locker_station,
        user=user,
        device_code=device_code,
    )
    locker_device.full_clean()
    locker_device.save()

    create_audit_log(
    actor=actor,
    action=AuditLog.Action.LOCKER_DEVICE_PROVISIONED,
    target_type=AuditLog.TargetType.LOCKER_DEVICE,
    target_id=locker_device.id,
    metadata={
        "locker_station_id": locker_station.id,
        "device_code": locker_device.device_code,
        "username": username,
    },
    )

    return locker_device, username, initial_password    


@transaction.atomic
def record_locker_heartbeat(*, device_user):
    if not device_user or not device_user.pk:
        raise ValidationError(
            {"device": "A valid locker device is required."}
        )

    try:
        locker_device = (
            LockerDevice.objects.select_for_update()
            .select_related("locker_station")
            .get(
                user=device_user,
                is_active=True,
            )
        )
    except LockerDevice.DoesNotExist as error:
        raise ValidationError(
            {"device": "Active locker device not found."}
        ) from error

    locker_device.last_heartbeat_at = timezone.now()
    locker_device.save(
        update_fields=(
            "last_heartbeat_at",
            "updated_at",
        )
    )

    return locker_device


def get_locker_device_connection_status(*, locker_device, now=None):
    if not locker_device.is_active:
        return LockerDevice.ConnectionStatus.INACTIVE

    if locker_device.last_heartbeat_at is None:
        return LockerDevice.ConnectionStatus.NEVER_CONNECTED

    now = now or timezone.now()

    stale_after = now - timedelta(
        seconds=settings.LOCKER_DEVICE_HEARTBEAT_TIMEOUT_SECONDS
    )

    if locker_device.last_heartbeat_at < stale_after:
        return LockerDevice.ConnectionStatus.STALE

    return LockerDevice.ConnectionStatus.ONLINE


def get_status_counts(*, model, choices, field_name="status"):
    counts = {
        value: 0
        for value, _label in choices
    }

    grouped_counts = (
        model.objects.values(field_name)
        .annotate(count=Count("id"))
    )

    for item in grouped_counts:
        counts[item[field_name]] = item["count"]

    return counts


def get_admin_dashboard_summary(*, now=None):
    from notifications.models import Notification
    from orders.models import Order

    now = now or timezone.now()

    stale_after = now - timedelta(
        seconds=settings.LOCKER_DEVICE_HEARTBEAT_TIMEOUT_SECONDS
    )

    device_counts = LockerDevice.objects.aggregate(
        online=Count(
            "id",
            filter=Q(
                is_active=True,
                last_heartbeat_at__gte=stale_after,
            ),
        ),
        stale=Count(
            "id",
            filter=Q(
                is_active=True,
                last_heartbeat_at__lt=stale_after,
            ),
        ),
        never_connected=Count(
            "id",
            filter=Q(
                is_active=True,
                last_heartbeat_at__isnull=True,
            ),
        ),
        inactive=Count(
            "id",
            filter=Q(is_active=False),
        ),
    )

    unhealthy_device_count = (
        device_counts["stale"]
        + device_counts["never_connected"]
        + device_counts["inactive"]
    )

    return {
        "generated_at": now,
        "totals": {
            "orders": Order.objects.count(),
            "locker_stations": LockerStation.objects.count(),
            "drawers": Drawer.objects.count(),
            "locker_devices": LockerDevice.objects.count(),
            "notifications": Notification.objects.count(),
        },
        "orders_by_status": get_status_counts(
            model=Order,
            choices=Order.Status.choices,
        ),
        "locker_stations_by_status": get_status_counts(
            model=LockerStation,
            choices=LockerStation.Status.choices,
        ),
        "drawers_by_status": get_status_counts(
            model=Drawer,
            choices=Drawer.Status.choices,
        ),
        "devices_by_connection_status": {
            LockerDevice.ConnectionStatus.ONLINE: device_counts["online"],
            LockerDevice.ConnectionStatus.STALE: device_counts["stale"],
            LockerDevice.ConnectionStatus.NEVER_CONNECTED: (
                device_counts["never_connected"]
            ),
            LockerDevice.ConnectionStatus.INACTIVE: device_counts["inactive"],
        },
        "notifications_by_delivery_status": get_status_counts(
            model=Notification,
            choices=Notification.DeliveryStatus.choices,
            field_name="delivery_status",
        ),
        "action_required": {
            "awaiting_locker_orders": Order.objects.filter(
                status=Order.Status.AWAITING_LOCKER,
            ).count(),
            "expired_orders": Order.objects.filter(
                status=Order.Status.EXPIRED,
            ).count(),
            "failed_notifications": Notification.objects.filter(
                delivery_status=Notification.DeliveryStatus.FAILED,
            ).count(),
            "pending_notifications": Notification.objects.filter(
                delivery_status=Notification.DeliveryStatus.PENDING,
            ).count(),
            "unhealthy_devices": unhealthy_device_count,
        },
    }

    return {
        "generated_at": now,
        "orders_by_status": get_status_counts(
            model=Order,
            choices=Order.Status.choices,
        ),
        "locker_stations_by_status": get_status_counts(
            model=LockerStation,
            choices=LockerStation.Status.choices,
        ),
        "drawers_by_status": get_status_counts(
            model=Drawer,
            choices=Drawer.Status.choices,
        ),
        "devices_by_connection_status": {
            LockerDevice.ConnectionStatus.ONLINE: device_counts["online"],
            LockerDevice.ConnectionStatus.STALE: device_counts["stale"],
            LockerDevice.ConnectionStatus.NEVER_CONNECTED: (
                device_counts["never_connected"]
            ),
            LockerDevice.ConnectionStatus.INACTIVE: device_counts["inactive"],
        },
    }



@transaction.atomic
def set_locker_device_active(
    *,
    device_id,
    is_active,
    actor,
):
    try:
        locker_device = (
            LockerDevice.objects.select_for_update()
            .select_related("locker_station")
            .get(pk=device_id)
        )
    except LockerDevice.DoesNotExist as error:
        raise ValidationError(
            {"device": "Locker device not found."}
        ) from error

    if locker_device.is_active == is_active:
        return locker_device

    previous_is_active = locker_device.is_active

    locker_device.is_active = is_active
    locker_device.save(
        update_fields=(
            "is_active",
            "updated_at",
        )
    )

    locker_station = locker_device.locker_station
    station_status_changed = False

    if (
        not is_active
        and locker_station.status == LockerStation.Status.ONLINE
    ):
        locker_station.status = LockerStation.Status.OFFLINE
        locker_station.save(
            update_fields=(
                "status",
                "updated_at",
            )
        )
        station_status_changed = True

    action = (
        AuditLog.Action.LOCKER_DEVICE_ACTIVATED
        if is_active
        else AuditLog.Action.LOCKER_DEVICE_DEACTIVATED
    )

    create_audit_log(
        actor=actor,
        action=action,
        target_type=AuditLog.TargetType.LOCKER_DEVICE,
        target_id=locker_device.id,
        metadata={
            "previous_is_active": previous_is_active,
            "new_is_active": locker_device.is_active,
            "locker_station_id": locker_station.id,
            "station_status_changed": station_status_changed,
            "locker_station_status": locker_station.status,
        },
    )

    return locker_device