from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models

from accounts.models import UserProfile


class LockerStation(models.Model):
    class Status(models.TextChoices):
        ONLINE = "online", "Online"
        OFFLINE = "offline", "Offline"
        MAINTENANCE = "maintenance", "Maintenance"

    name = models.CharField(max_length=255)
    code = models.CharField(max_length=50, unique=True)
    address = models.TextField()
    latitude = models.DecimalField(max_digits=9, decimal_places=6)
    longitude = models.DecimalField(max_digits=9, decimal_places=6)
    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.ONLINE,
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["name"]
        indexes = [
            models.Index(fields=["code"]),
            models.Index(fields=["status"]),
        ]

    def __str__(self):
        return f"{self.name} ({self.code})"


class Drawer(models.Model):
    class Size(models.TextChoices):
        SMALL = "small", "Small"
        MEDIUM = "medium", "Medium"
        LARGE = "large", "Large"

    class Status(models.TextChoices):
        AVAILABLE = "available", "Available"
        RESERVED = "reserved", "Reserved"
        OCCUPIED = "occupied", "Occupied"
        OUT_OF_SERVICE = "out_of_service", "Out Of Service"
        RETURN_PENDING = "return_pending", "Return Pending"

    locker_station = models.ForeignKey(
        LockerStation,
        on_delete=models.CASCADE,
        related_name="drawers",
    )
    number = models.PositiveIntegerField()
    size = models.CharField(
        max_length=10,
        choices=Size.choices,
    )
    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.AVAILABLE,
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["locker_station", "number"]
        constraints = [
            models.UniqueConstraint(
                fields=["locker_station", "number"],
                name="unique_drawer_number_per_locker",
            )
        ]
        indexes = [
            models.Index(fields=["locker_station", "status"]),
            models.Index(fields=["size", "status"]),
        ]

    def __str__(self):
        return f"{self.locker_station.code} - Drawer {self.number}"


class LockerDevice(models.Model):
    class ConnectionStatus(models.TextChoices):
        ONLINE = "online", "Online"
        STALE = "stale", "Stale"
        NEVER_CONNECTED = "never_connected", "Never Connected"
        INACTIVE = "inactive", "Inactive"
    
    locker_station = models.OneToOneField(
        LockerStation,
        on_delete=models.PROTECT,
        related_name="device",
    )
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="locker_device",
    )
    device_code = models.CharField(max_length=100, unique=True)
    is_active = models.BooleanField(default=True)
    last_heartbeat_at = models.DateTimeField(
    null=True,
    blank=True,
    db_index=True,
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def clean(self):
        profile = getattr(self.user, "profile", None)

        if (
            profile is None
            or profile.role != UserProfile.Role.LOCKER_DEVICE
        ):
            raise ValidationError(
                {
                    "user": (
                        "Locker device users must have the locker_device role."
                    )
                }
            )

    def __str__(self):
        return f"{self.device_code} -> {self.locker_station.code}"


class LockerEventLog(models.Model):
    class EventType(models.TextChoices):
        DRAWER_RESERVED = "drawer_reserved", "Drawer Reserved"
        PACKAGE_DEPOSITED = "package_deposited", "Package Deposited"
        PICKUP_OPENED = "pickup_opened", "Pickup Opened"
        PACKAGE_COLLECTED = "package_collected", "Package Collected"
        DRAWER_RELEASED = "drawer_released", "Drawer Released"
        PICKUP_TOKEN_ISSUED = "pickup_token_issued", "Pickup Token Issued"
        PICKUP_EXPIRED = "pickup_expired", "Pickup Expired"
        RETURN_TOKEN_ISSUED = "return_token_issued", "Return Token Issued"
        RETURN_OPENED = "return_opened", "Return Opened"
        PACKAGE_RETURNED = "package_returned", "Package Returned"
        ORDER_CANCELLED = "order_cancelled", "Order Cancelled"

    locker_station = models.ForeignKey(
        LockerStation,
        on_delete=models.PROTECT,
        related_name="event_logs",
    )
    drawer = models.ForeignKey(
        Drawer,
        on_delete=models.PROTECT,
        related_name="event_logs",
    )
    order = models.ForeignKey(
        "orders.Order",
        on_delete=models.PROTECT,
        related_name="locker_events",
    )
    actor = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="locker_events",
    )
    event_type = models.CharField(
        max_length=30,
        choices=EventType.choices,
    )
    metadata = models.JSONField(default=dict, blank=True)
    occurred_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-occurred_at"]
        indexes = [
            models.Index(
                fields=["locker_station", "event_type", "occurred_at"]
            ),
            models.Index(fields=["order", "occurred_at"]),
        ]

    def __str__(self):
        return f"{self.event_type} - {self.order.public_id}"