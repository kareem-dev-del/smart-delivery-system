import uuid
from decimal import Decimal

from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.validators import MinValueValidator
from django.db import models

from lockers.models import Drawer, LockerStation
from products.models import Product
from django.utils import timezone
from accounts.models import UserProfile





class Order(models.Model):
    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        AWAITING_LOCKER = "awaiting_locker", "Awaiting Locker"
        ASSIGNED = "assigned", "Assigned"
        READY_FOR_PICKUP = "ready_for_pickup", "Ready For Pickup"
        COLLECTED = "collected", "Collected"
        EXPIRED = "expired", "Expired"
        CANCELLED = "cancelled", "Cancelled"
        RETURNED = "returned", "Returned"

    public_id = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)

    
     
    customer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="orders",
    )
    assigned_courier = models.ForeignKey(
    settings.AUTH_USER_MODEL,
    on_delete=models.PROTECT,
    related_name="assigned_orders",
    null=True,
    blank=True,
    )

    courier_assigned_at = models.DateTimeField(
    null=True,
    blank=True,  
    )

    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.PENDING,
    )

    locker_station = models.ForeignKey(
        LockerStation,
        on_delete=models.PROTECT,
        related_name="orders",
        null=True,
        blank=True,
    )

    assigned_drawer = models.ForeignKey(
        Drawer,
        on_delete=models.PROTECT,
        related_name="orders",
        null=True,
        blank=True,
    )

    total_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=Decimal("0.00"),
        validators=[MinValueValidator(0)],
    )

    delivery_deadline = models.DateTimeField(null=True, blank=True)
    assigned_at = models.DateTimeField(null=True, blank=True)
    ready_for_pickup_at = models.DateTimeField(null=True, blank=True)
    pickup_opened_at = models.DateTimeField(null=True, blank=True)
    return_opened_at = models.DateTimeField(null=True, blank=True)
    collected_at = models.DateTimeField(null=True, blank=True)
    returned_at = models.DateTimeField(null=True, blank=True)
    cancelled_at = models.DateTimeField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)

    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["customer", "status"]),
            models.Index(fields=["locker_station", "status"]),
            models.Index(fields=["status"]),
            models.Index(fields=["assigned_courier", "status"]),
        ]

    def clean(self):
        if self.assigned_courier_id:
            profile = getattr(self.assigned_courier, "profile", None)

            if (
                profile is None
                or profile.role != UserProfile.Role.COURIER
            ):
                raise ValidationError(
                    {
                        "assigned_courier": (
                            "Assigned user must have the courier role."
                        )
                    }
                )

        if self.assigned_drawer_id and not self.locker_station_id:
            raise ValidationError(
                {"assigned_drawer": "A drawer requires an assigned locker station."}
            )

        if (
            self.assigned_drawer_id
            and self.locker_station_id
            and self.assigned_drawer.locker_station_id != self.locker_station_id
        ):
            raise ValidationError(
                {"assigned_drawer": "The drawer must belong to the assigned locker."}
            )

    def __str__(self):
        return f"Order {str(self.public_id)[:8]}"


class OrderItem(models.Model):
    order = models.ForeignKey(
        Order,
        on_delete=models.CASCADE,
        related_name="items",
    )

    product = models.ForeignKey(
        Product,
        on_delete=models.PROTECT,
        related_name="order_items",
    )

    product_name = models.CharField(max_length=255)

    product_size = models.CharField(
        max_length=10,
        choices=Product.Size.choices,
    )

    unit_price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        validators=[MinValueValidator(0)],
    )

    quantity = models.PositiveIntegerField(
        validators=[MinValueValidator(1)]
    )

    class Meta:
        ordering = ["id"]
        constraints = [
            models.UniqueConstraint(
                fields=["order", "product"],
                name="unique_product_per_order",
            )
        ]

    @property
    def line_total(self):
        return self.unit_price * self.quantity

    def __str__(self):
        return f"{self.product_name} x {self.quantity}"

class QRToken(models.Model):
    class Purpose(models.TextChoices):
        CUSTOMER_PICKUP = "customer_pickup", "Customer Pickup"
        COURIER_RETURN = "courier_return", "Courier Return"

    order = models.ForeignKey(
        Order,
        on_delete=models.CASCADE,
        related_name="qr_tokens",
    )
    purpose = models.CharField(
    max_length=20,
    choices=Purpose.choices,
    default=Purpose.CUSTOMER_PICKUP,
     )

    token_hash = models.CharField(
        max_length=64,
        unique=True,
        editable=False,
    )

    expires_at = models.DateTimeField()
    used_at = models.DateTimeField(null=True, blank=True)
    revoked_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["order", "expires_at"]),
            models.Index(fields=["expires_at"]),
        ]

    @property
    def is_active(self):
        return (
            self.used_at is None
            and self.revoked_at is None
            and timezone.now() < self.expires_at
        )

    def __str__(self):
        return f"QR token for order {str(self.order.public_id)[:8]}"    