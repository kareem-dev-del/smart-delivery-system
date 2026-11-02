from django.conf import settings
from django.db import models


class AuditLog(models.Model):
    class TargetType(models.TextChoices):
        ORDER = "order", "Order"
        LOCKER_STATION = "locker_station", "Locker Station"
        DRAWER = "drawer", "Drawer"
        LOCKER_DEVICE = "locker_device", "Locker Device"
        USER = "user", "User"

    class Action(models.TextChoices):
        ORDER_DRAWER_ASSIGNED = (
            "order_drawer_assigned",
            "Order Drawer Assigned",
        )
        ORDER_COURIER_ASSIGNED = (
            "order_courier_assigned",
            "Order Courier Assigned",
        )
        ORDER_CANCELLED = "order_cancelled", "Order Cancelled"
        LOCKER_STATION_CREATED = (
            "locker_station_created",
            "Locker Station Created",
        )
        LOCKER_STATION_UPDATED = (
            "locker_station_updated",
            "Locker Station Updated",
        )
        DRAWER_CREATED = "drawer_created", "Drawer Created"
        DRAWER_MAINTENANCE_STATUS_CHANGED = (
            "drawer_maintenance_status_changed",
            "Drawer Maintenance Status Changed",
        )
        LOCKER_DEVICE_PROVISIONED = (
            "locker_device_provisioned",
            "Locker Device Provisioned",
        )
        LOCKER_DEVICE_DEACTIVATED = (
            "locker_device_deactivated",
            "Locker Device Deactivated",
    )
        LOCKER_DEVICE_ACTIVATED = (
            "locker_device_activated",
            "Locker Device Activated",
        )
        ACCOUNT_CREATED = "account_created", "Account Created"
        ACCOUNT_STATUS_CHANGED = "account_status_changed", "Account Status Changed"
        COURIER_SHIFT_CHANGED = "courier_shift_changed", "Courier Shift Changed"

    actor = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        related_name="audit_logs",
        null=True,
        blank=True,
    )
    action = models.CharField(
        max_length=50,
        choices=Action.choices,
    )
    target_type = models.CharField(
        max_length=30,
        choices=TargetType.choices,
    )
    target_id = models.CharField(max_length=100)
    metadata = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["actor", "action", "created_at"]),
            models.Index(
                fields=["target_type", "target_id", "created_at"]
            ),
        ]

    def __str__(self):
        return f"{self.action} - {self.target_type}:{self.target_id}"
