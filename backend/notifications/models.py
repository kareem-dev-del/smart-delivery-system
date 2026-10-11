from django.conf import settings
from django.db import models


class Notification(models.Model):
    class Type(models.TextChoices):
        ORDER_READY_FOR_PICKUP = (
            "order_ready_for_pickup",
            "Order Ready For Pickup",
        )
        ORDER_PICKUP_EXPIRED = (
            "order_pickup_expired",
            "Order Pickup Expired",
        )
        COURIER_ASSIGNED = (
            "courier_assigned",
            "Courier Assigned",
        )
        COURIER_RETURN_REQUIRED = (
            "courier_return_required",
            "Courier Return Required",
        )

    class DeliveryStatus(models.TextChoices):
        PENDING = "pending", "Pending"
        SENT = "sent", "Sent"
        FAILED = "failed", "Failed"
        SKIPPED = "skipped", "Skipped"

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="notifications",
    )
    order = models.ForeignKey(
        "orders.Order",
        on_delete=models.CASCADE,
        related_name="notifications",
        null=True,
        blank=True,
    )
    notification_type = models.CharField(
        max_length=40,
        choices=Type.choices,
    )
    title = models.CharField(max_length=255)
    message = models.TextField()
    data = models.JSONField(default=dict, blank=True)
    is_read = models.BooleanField(default=False)
    delivery_status = models.CharField(
        max_length=20,
        choices=DeliveryStatus.choices,
        default=DeliveryStatus.PENDING,
    )
    delivery_attempts = models.PositiveSmallIntegerField(default=0)
    delivered_at = models.DateTimeField(null=True, blank=True)
    delivery_error = models.TextField(blank=True)
    read_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["user", "is_read", "created_at"]),
            models.Index(fields=["order", "created_at"]),
            models.Index(fields=["delivery_status", "created_at"]),
        ]

    def __str__(self):
        return f"{self.user.username} - {self.notification_type}"