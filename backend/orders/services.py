from datetime import timedelta
from decimal import Decimal

from django.core.exceptions import ValidationError
from django.db import transaction
from django.utils import timezone

from notifications.models import Notification
from notifications.services import create_notification

from audit.models import AuditLog
from audit.services import create_audit_log



import hashlib
import secrets

from lockers.models import (
    Drawer,
    LockerDevice,
    LockerEventLog,
    LockerStation,
)
from products.models import Product

from .models import Order, OrderItem, QRToken


from django.contrib.auth import get_user_model

from accounts.models import UserProfile
User = get_user_model()

PICKUP_WINDOW = timedelta(hours=48)
QR_TOKEN_LIFETIME = timedelta(minutes=10)
RETURN_QR_TOKEN_LIFETIME = timedelta(minutes=10)
SIZE_RANK = {
    Product.Size.SMALL: 1,
    Product.Size.MEDIUM: 2,
    Product.Size.LARGE: 3,
}


def validate_order_items(items):
    if not isinstance(items, (list, tuple)) or not items:
        raise ValidationError(
            {"items": "An order must contain at least one item."}
        )

    normalized_items = []
    product_ids = set()

    for item in items:
        if not isinstance(item, dict):
            raise ValidationError(
                {"items": "Each item must be an object."}
            )

        product_id = item.get("product_id")
        quantity = item.get("quantity")

        if (
            isinstance(product_id, bool)
            or not isinstance(product_id, int)
            or product_id <= 0
        ):
            raise ValidationError(
                {"items": "Each item must contain a valid product_id."}
            )

        if (
            isinstance(quantity, bool)
            or not isinstance(quantity, int)
            or quantity <= 0
        ):
            raise ValidationError(
                {"items": "Each item must contain a quantity greater than zero."}
            )

        if product_id in product_ids:
            raise ValidationError(
                {"items": "A product can appear only once in an order."}
            )

        product_ids.add(product_id)
        normalized_items.append(
            {
                "product_id": product_id,
                "quantity": quantity,
            }
        )

    return normalized_items


@transaction.atomic
def create_order(*, customer, items, locker_station_id=None):
    if not customer or not customer.pk:
        raise ValidationError(
            {"customer": "A valid customer is required."}
        )

    validated_items = validate_order_items(items)
    product_ids = [item["product_id"] for item in validated_items]

    products = Product.objects.select_for_update().filter(
        id__in=product_ids,
        is_active=True,
    )

    products_by_id = {product.id: product for product in products}

    if len(products_by_id) != len(product_ids):
        raise ValidationError(
            {"items": "One or more requested products are unavailable."}
        )

    for item in validated_items:
        product = products_by_id[item["product_id"]]

        if product.stock < item["quantity"]:
            raise ValidationError(
                {
                    "items": (
                        f"Insufficient stock for product '{product.name}'."
                    )
                }
            )

    total_amount = sum(
        (
            products_by_id[item["product_id"]].price * item["quantity"]
            for item in validated_items
        ),
        Decimal("0.00"),
    )

    order = Order.objects.create(
        customer=customer,
        status=Order.Status.AWAITING_LOCKER,
        total_amount=total_amount,
    )

    for item in validated_items:
        product = products_by_id[item["product_id"]]

        OrderItem.objects.create(
            order=order,
            product=product,
            product_name=product.name,
            product_size=product.size,
            unit_price=product.price,
            quantity=item["quantity"],
        )

        product.stock -= item["quantity"]
        product.save(update_fields=("stock", "updated_at"))

    if locker_station_id is not None:
        try:
            locker_station = LockerStation.objects.select_for_update().get(
                id=locker_station_id,
                status=LockerStation.Status.ONLINE,
            )
        except LockerStation.DoesNotExist as error:
            raise ValidationError(
                {"locker_station_id": "This locker station is unavailable."}
            ) from error

        required_size = max(
            (products_by_id[item["product_id"]].size for item in validated_items),
            key=lambda size: SIZE_RANK[size],
        )
        drawer = None
        compatible_sizes = sorted(
            (
                (size, rank)
                for size, rank in SIZE_RANK.items()
                if rank >= SIZE_RANK[required_size]
            ),
            key=lambda item: item[1],
        )
        for size, _ in compatible_sizes:
            drawer = (
                Drawer.objects.select_for_update(skip_locked=True)
                .filter(
                    locker_station=locker_station,
                    status=Drawer.Status.AVAILABLE,
                    size=size,
                )
                .order_by("number")
                .first()
            )
            if drawer is not None:
                break

        if drawer is None:
            raise ValidationError(
                {
                    "locker_station_id": (
                        "This locker has no available drawer large enough "
                        "for the selected products. Choose another locker."
                    )
                }
            )

        order = assign_order_to_drawer(
            order_public_id=order.public_id,
            locker_station_id=locker_station.id,
            drawer_id=drawer.id,
            actor=customer,
        )

    return order



@transaction.atomic
def cancel_order(*, order_public_id, customer):
    if not customer or not customer.pk:
        raise ValidationError(
            {"customer": "A valid customer is required."}
        )

    try:
        order = (
            Order.objects.select_for_update(of=("self",))
            .select_related(
                "locker_station",
                "assigned_drawer",
            )
            .prefetch_related("items")
            .get(public_id=order_public_id)
        )
    except Order.DoesNotExist as error:
        raise ValidationError({"order": "Order not found."}) from error

    if order.customer_id != customer.id:
        raise ValidationError({"order": "Order not found."})

    allowed_statuses = (
        Order.Status.AWAITING_LOCKER,
        Order.Status.ASSIGNED,
    )

    if order.status not in allowed_statuses:
        raise ValidationError(
            {
                "order": (
                    "Order cannot be cancelled in its current status."
                )
            }
        )

    now = timezone.now()
    drawer = None

    if order.status == Order.Status.ASSIGNED:
        if not order.locker_station_id or not order.assigned_drawer_id:
            raise ValidationError(
                {"order": "Assigned order has no locker and drawer."}
            )

        drawer = Drawer.objects.select_for_update().get(
            id=order.assigned_drawer_id
        )

        if drawer.status != Drawer.Status.RESERVED:
            raise ValidationError(
                {"drawer": "Assigned order drawer must be reserved."}
            )

    order_items = list(order.items.all())
    product_ids = [item.product_id for item in order_items]

    products_by_id = {
        product.id: product
        for product in Product.objects.select_for_update().filter(
            id__in=product_ids
        )
    }

    if len(products_by_id) != len(product_ids):
        raise ValidationError(
            {"order": "One or more order products are unavailable."}
        )

    for item in order_items:
        product = products_by_id[item.product_id]
        product.stock += item.quantity
        product.save(update_fields=("stock", "updated_at"))

    QRToken.objects.filter(
        order=order,
        used_at__isnull=True,
        revoked_at__isnull=True,
    ).update(revoked_at=now)

    if drawer:
        drawer.status = Drawer.Status.AVAILABLE
        drawer.save(update_fields=("status", "updated_at"))

    previous_status = order.status
    order.status = Order.Status.CANCELLED

    order.cancelled_at = now
    order.save(
        update_fields=(
            "status",
            "cancelled_at",
            "updated_at",
        )
    )

    if drawer:
        LockerEventLog.objects.create(
            locker_station=order.locker_station,
            drawer=drawer,
            order=order,
            actor=customer,
            event_type=LockerEventLog.EventType.ORDER_CANCELLED,
        )

        LockerEventLog.objects.create(
            locker_station=order.locker_station,
            drawer=drawer,
            order=order,
            actor=customer,
            event_type=LockerEventLog.EventType.DRAWER_RELEASED,
        )


    create_audit_log(
    actor=customer,
    action=AuditLog.Action.ORDER_CANCELLED,
    target_type=AuditLog.TargetType.ORDER,
    target_id=order.public_id,
    metadata={
        "previous_status": previous_status,
        "drawer_id": drawer.id if drawer else None,
       },
   )    

    return order

@transaction.atomic
def assign_order_to_drawer(
    *,
    order_public_id,
    locker_station_id,
    drawer_id,
    actor=None,
):
    try:
        order = (
            Order.objects.select_for_update(of=("self",))
            .prefetch_related("items")
            .get(public_id=order_public_id)
        )
    except Order.DoesNotExist as error:
        raise ValidationError({"order": "Order not found."}) from error

    try:
        locker_station = LockerStation.objects.select_for_update().get(
            id=locker_station_id
        )
    except LockerStation.DoesNotExist as error:
        raise ValidationError(
            {"locker_station_id": "Locker station not found."}
        ) from error

    try:
        drawer = Drawer.objects.select_for_update().get(id=drawer_id)
    except Drawer.DoesNotExist as error:
        raise ValidationError({"drawer_id": "Drawer not found."}) from error

    if order.status != Order.Status.AWAITING_LOCKER:
        raise ValidationError(
            {"order": "Only orders awaiting a locker can be assigned."}
        )

    if locker_station.status != LockerStation.Status.ONLINE:
        raise ValidationError(
            {"locker_station_id": "Locker station must be online."}
        )

    if drawer.locker_station_id != locker_station.id:
        raise ValidationError(
            {"drawer_id": "Drawer does not belong to this locker station."}
        )

    if drawer.status != Drawer.Status.AVAILABLE:
        raise ValidationError(
            {"drawer_id": "Drawer is not available."}
        )

    order_items = list(order.items.all())

    if not order_items:
        raise ValidationError(
            {"order": "Order must contain at least one item."}
        )

    required_size = max(
        (item.product_size for item in order_items),
        key=lambda size: SIZE_RANK[size],
    )

    if SIZE_RANK[drawer.size] < SIZE_RANK[required_size]:
        raise ValidationError(
            {"drawer_id": "Drawer is too small for this order."}
        )

    order.locker_station = locker_station
    order.assigned_drawer = drawer
    order.status = Order.Status.ASSIGNED
    order.assigned_at = timezone.now()
    order.full_clean()

    drawer.status = Drawer.Status.RESERVED
    drawer.save(update_fields=("status", "updated_at"))

    order.save(
        update_fields=(
            "locker_station",
            "assigned_drawer",
            "status",
            "assigned_at",
            "updated_at",
        )
    )

    LockerEventLog.objects.create(
        locker_station=locker_station,
        drawer=drawer,
        order=order,
        actor=actor,
        event_type=LockerEventLog.EventType.DRAWER_RESERVED,
    )


    create_audit_log(
    actor=actor,
    action=AuditLog.Action.ORDER_DRAWER_ASSIGNED,
    target_type=AuditLog.TargetType.ORDER,
    target_id=order.public_id,
    metadata={
        "locker_station_id": locker_station.id,
        "locker_code": locker_station.code,
        "drawer_id": drawer.id,
        "drawer_number": drawer.number,
      },
   )
    
    return order


@transaction.atomic
def confirm_order_deposit(*, order_public_id, device_user):
    if not device_user or not device_user.pk:
        raise ValidationError(
            {"device": "A valid locker device is required."}
        )

    try:
        locker_device = (
            LockerDevice.objects.select_for_update()
            .select_related("locker_station")
            .get(user=device_user, is_active=True)
        )
    except LockerDevice.DoesNotExist as error:
        raise ValidationError(
            {"device": "Active locker device not found."}
        ) from error

    try:
        order = (
            Order.objects.select_for_update(of=("self",))
            .select_related("locker_station", "assigned_drawer")
            .get(public_id=order_public_id)
        )
    except Order.DoesNotExist as error:
        raise ValidationError({"order": "Order not found."}) from error

    if order.status != Order.Status.ASSIGNED:
        raise ValidationError(
            {"order": "Only assigned orders can be deposited."}
        )

    if not order.locker_station_id or not order.assigned_drawer_id:
        raise ValidationError(
            {"order": "Order has no assigned locker and drawer."}
        )

    if order.locker_station_id != locker_device.locker_station_id:
        raise ValidationError(
            {"device": "This device does not belong to the order locker."}
        )

    if locker_device.locker_station.status != LockerStation.Status.ONLINE:
        raise ValidationError(
            {"locker_station": "Locker station must be online."}
        )

    drawer = Drawer.objects.select_for_update().get(
        id=order.assigned_drawer_id
    )

    if drawer.locker_station_id != locker_device.locker_station_id:
        raise ValidationError(
            {"drawer": "Assigned drawer does not belong to this device locker."}
        )

    if drawer.status != Drawer.Status.RESERVED:
        raise ValidationError(
            {"drawer": "Drawer must be reserved before package deposit."}
        )

    now = timezone.now()

    drawer.status = Drawer.Status.OCCUPIED
    drawer.save(update_fields=("status", "updated_at"))

    order.status = Order.Status.READY_FOR_PICKUP
    order.ready_for_pickup_at = now
    order.delivery_deadline = now + PICKUP_WINDOW
    order.save(
        update_fields=(
            "status",
            "ready_for_pickup_at",
            "delivery_deadline",
            "updated_at",
        )
    )

    LockerEventLog.objects.create(
        locker_station=locker_device.locker_station,
        drawer=drawer,
        order=order,
        actor=device_user,
        event_type=LockerEventLog.EventType.PACKAGE_DEPOSITED,
        metadata={
            "device_code": locker_device.device_code,
        },
    )


    create_notification(
    user=order.customer,
    order=order,
    notification_type=Notification.Type.ORDER_READY_FOR_PICKUP,
    title="Order ready for pickup",
    message=(
        f"Your order is ready for pickup from "
        f"{order.locker_station.name}."
    ),
    data={
        "order_public_id": str(order.public_id),
        "locker_code": order.locker_station.code,
        "delivery_deadline": order.delivery_deadline.isoformat(),
    },
     )

    return order

def hash_qr_token(raw_token):
    return hashlib.sha256(raw_token.encode("utf-8")).hexdigest()


@transaction.atomic
def issue_pickup_qr_token(*, order_public_id, customer):
    if not customer or not customer.pk:
        raise ValidationError(
            {"customer": "A valid customer is required."}
        )

    try:
        order = (
            Order.objects.select_for_update(of=("self",))
            .select_related(
                "locker_station",
                "assigned_drawer",
            )
            .get(public_id=order_public_id)
        )
    except Order.DoesNotExist as error:
        raise ValidationError({"order": "Order not found."}) from error

    if order.customer_id != customer.pk:
        raise ValidationError({"order": "Order not found."})

    if order.status != Order.Status.READY_FOR_PICKUP:
        raise ValidationError(
            {"order": "Order is not ready for pickup."}
        )

    now = timezone.now()

    if not order.delivery_deadline or order.delivery_deadline <= now:
        raise ValidationError(
            {"order": "The pickup window has expired."}
        )

    if not order.locker_station_id or not order.assigned_drawer_id:
        raise ValidationError(
            {"order": "Order has no assigned locker and drawer."}
        )

    QRToken.objects.filter(
       order=order,
       purpose=QRToken.Purpose.CUSTOMER_PICKUP,
       used_at__isnull=True,
       revoked_at__isnull=True,
   ).update(revoked_at=now)

   

    raw_token = secrets.token_urlsafe(32)
    expires_at = min(
        now + QR_TOKEN_LIFETIME,
        order.delivery_deadline,
    )

    qr_token = QRToken.objects.create(
    order=order,
    purpose=QRToken.Purpose.CUSTOMER_PICKUP,
    token_hash=hash_qr_token(raw_token),
    expires_at=expires_at,
    )
    LockerEventLog.objects.create(
        locker_station=order.locker_station,
        drawer=order.assigned_drawer,
        order=order,
        actor=customer,
        event_type=LockerEventLog.EventType.PICKUP_TOKEN_ISSUED,
        metadata={
            "expires_at": expires_at.isoformat(),
        },
    )

    return qr_token, raw_token

@transaction.atomic
def authorize_pickup_by_qr(*, raw_token, device_user):
    if not isinstance(raw_token, str) or not raw_token.strip():
        raise ValidationError(
            {"token": "A valid QR token is required."}
        )

    if not device_user or not device_user.pk:
        raise ValidationError(
            {"device": "A valid locker device is required."}
        )

    try:
        locker_device = (
            LockerDevice.objects.select_for_update()
            .select_related("locker_station")
            .get(user=device_user, is_active=True)
        )
    except LockerDevice.DoesNotExist as error:
        raise ValidationError(
            {"device": "Active locker device not found."}
        ) from error

    token_hash = hash_qr_token(raw_token.strip())

    try:
        qr_token = QRToken.objects.select_for_update().get(
            token_hash=token_hash
        )
    except QRToken.DoesNotExist as error:
        raise ValidationError(
            {"token": "Invalid or expired QR token."}
        ) from error

    if qr_token.purpose != QRToken.Purpose.CUSTOMER_PICKUP:
        raise ValidationError(
            {"token": "Invalid or expired QR token."}
        )

    now = timezone.now()

    if qr_token.used_at or qr_token.revoked_at or qr_token.expires_at <= now:
        raise ValidationError(
            {"token": "Invalid or expired QR token."}
        )

    order = (
        Order.objects.select_for_update(of=("self",))
        .select_related(
            "locker_station",
            "assigned_drawer",
        )
        .get(id=qr_token.order_id)
    )

    if order.status != Order.Status.READY_FOR_PICKUP:
        raise ValidationError(
            {"order": "Order is not ready for pickup."}
        )

    if order.return_opened_at:
     raise ValidationError(
        {"order": "Return retrieval is already in progress."}
    )

    if not order.delivery_deadline or order.delivery_deadline <= now:
        raise ValidationError(
            {"order": "The pickup window has expired."}
        )

    if (
        not order.locker_station_id
        or not order.assigned_drawer_id
        or order.locker_station_id != locker_device.locker_station_id
    ):
        raise ValidationError(
            {"device": "This device cannot open the order drawer."}
        )

    if locker_device.locker_station.status != LockerStation.Status.ONLINE:
        raise ValidationError(
            {"locker_station": "Locker station must be online."}
        )

    drawer = Drawer.objects.select_for_update().get(
        id=order.assigned_drawer_id
    )

    if drawer.locker_station_id != locker_device.locker_station_id:
        raise ValidationError(
            {"drawer": "Drawer does not belong to this locker device."}
        )

    if drawer.status != Drawer.Status.OCCUPIED:
        raise ValidationError(
            {"drawer": "Drawer is not ready for pickup."}
        )

    qr_token.used_at = now
    qr_token.save(update_fields=("used_at",))

    order.pickup_opened_at = now
    order.save(
        update_fields=(
            "pickup_opened_at",
            "updated_at",
        )
    )

    LockerEventLog.objects.create(
        locker_station=locker_device.locker_station,
        drawer=drawer,
        order=order,
        actor=device_user,
        event_type=LockerEventLog.EventType.PICKUP_OPENED,
        metadata={
            "device_code": locker_device.device_code,
        },
    )

    return order, drawer
@transaction.atomic
def confirm_package_collection(*, order_public_id, device_user):
    if not device_user or not device_user.pk:
        raise ValidationError(
            {"device": "A valid locker device is required."}
        )

    try:
        locker_device = (
            LockerDevice.objects.select_for_update()
            .select_related("locker_station")
            .get(user=device_user, is_active=True)
        )
    except LockerDevice.DoesNotExist as error:
        raise ValidationError(
            {"device": "Active locker device not found."}
        ) from error

    try:
        order = (
            Order.objects.select_for_update(of=("self",))
            .select_related(
                "locker_station",
                "assigned_drawer",
            )
            .get(public_id=order_public_id)
        )
    except Order.DoesNotExist as error:
        raise ValidationError({"order": "Order not found."}) from error

    if order.status != Order.Status.READY_FOR_PICKUP:
        raise ValidationError(
            {"order": "Order cannot be collected in its current status."}
        )

    if not order.pickup_opened_at:
        raise ValidationError(
            {"order": "Pickup QR must be scanned before collection."}
        )

    if (
        not order.locker_station_id
        or not order.assigned_drawer_id
        or order.locker_station_id != locker_device.locker_station_id
    ):
        raise ValidationError(
            {"device": "This device cannot confirm this order collection."}
        )

    if locker_device.locker_station.status != LockerStation.Status.ONLINE:
        raise ValidationError(
            {"locker_station": "Locker station must be online."}
        )

    drawer = Drawer.objects.select_for_update().get(
        id=order.assigned_drawer_id
    )

    if drawer.locker_station_id != locker_device.locker_station_id:
        raise ValidationError(
            {"drawer": "Drawer does not belong to this locker device."}
        )

    if drawer.status != Drawer.Status.OCCUPIED:
        raise ValidationError(
            {"drawer": "Drawer is not occupied."}
        )

    now = timezone.now()

    QRToken.objects.filter(
        order=order,
        used_at__isnull=True,
        revoked_at__isnull=True,
    ).update(revoked_at=now)

    drawer.status = Drawer.Status.AVAILABLE
    drawer.save(update_fields=("status", "updated_at"))

    order.status = Order.Status.COLLECTED
    order.collected_at = now
    order.save(
        update_fields=(
            "status",
            "collected_at",
            "updated_at",
        )
    )

    LockerEventLog.objects.create(
        locker_station=locker_device.locker_station,
        drawer=drawer,
        order=order,
        actor=device_user,
        event_type=LockerEventLog.EventType.PACKAGE_COLLECTED,
        metadata={
            "device_code": locker_device.device_code,
        },
    )

    LockerEventLog.objects.create(
        locker_station=locker_device.locker_station,
        drawer=drawer,
        order=order,
        actor=device_user,
        event_type=LockerEventLog.EventType.DRAWER_RELEASED,
        metadata={
            "device_code": locker_device.device_code,
        },
    )

    return order, drawer 

@transaction.atomic
def expire_order_if_overdue(*, order_id, now=None):
    now = now or timezone.now()

    try:
        order = (
            Order.objects.select_for_update(of=("self",))
            .select_related(
                "locker_station",
                "assigned_drawer",
            )
            .get(id=order_id)
        )
    except Order.DoesNotExist:
        return False

    if (
        order.status != Order.Status.READY_FOR_PICKUP
        or not order.delivery_deadline
        or order.delivery_deadline > now
    ):
        return False

    # Do not automatically expire an order while a pickup attempt is active.
    if order.pickup_opened_at:
        return False

    if not order.locker_station_id or not order.assigned_drawer_id:
        raise ValidationError(
            {"order": "Ready order has no assigned locker and drawer."}
        )

    drawer = Drawer.objects.select_for_update().get(
        id=order.assigned_drawer_id
    )

    if drawer.status != Drawer.Status.OCCUPIED:
        raise ValidationError(
            {"drawer": "Expired order drawer must be occupied."}
        )

    QRToken.objects.filter(
        order=order,
        used_at__isnull=True,
        revoked_at__isnull=True,
    ).update(revoked_at=now)

    order.status = Order.Status.EXPIRED
    order.save(
        update_fields=(
            "status",
            "updated_at",
        )
    )

    drawer.status = Drawer.Status.RETURN_PENDING
    drawer.save(update_fields=("status", "updated_at"))

    LockerEventLog.objects.create(
        locker_station=order.locker_station,
        drawer=drawer,
        order=order,
        event_type=LockerEventLog.EventType.PICKUP_EXPIRED,
        metadata={
            "delivery_deadline": order.delivery_deadline.isoformat(),
        },
    )

    create_notification(
    user=order.customer,
    order=order,
    notification_type=Notification.Type.ORDER_PICKUP_EXPIRED,
    title="Pickup window expired",
    message="Your order pickup window has expired.",
    data={
        "order_public_id": str(order.public_id),
        "locker_code": order.locker_station.code,
    },
    )

    if order.assigned_courier_id:
        create_notification(
            user=order.assigned_courier,
            order=order,
            notification_type=Notification.Type.COURIER_RETURN_REQUIRED,
            title="Order return required",
            message=(
                "An expired order assigned to you requires return "
                "from the locker."
            ),
            data={
                "order_public_id": str(order.public_id),
                "locker_code": order.locker_station.code,
            },
        )


    

    return True


def get_overdue_order_ids(*, now=None):
    now = now or timezone.now()

    return (
        Order.objects.filter(
            status=Order.Status.READY_FOR_PICKUP,
            delivery_deadline__lte=now,
            pickup_opened_at__isnull=True,
        )
        .order_by("id")
        .values_list("id", flat=True)
    )


def expire_overdue_orders(*, now=None, limit=None):
    now = now or timezone.now()

    overdue_order_ids = get_overdue_order_ids(now=now)

    if limit is not None:
        overdue_order_ids = overdue_order_ids[:limit]

    expired_count = 0

    for order_id in overdue_order_ids.iterator(chunk_size=100):
        if expire_order_if_overdue(order_id=order_id, now=now):
            expired_count += 1

    return expired_count 



@transaction.atomic
def assign_courier_to_order(*,order_public_id, courier_id,actor=None):

    try:
        order = Order.objects.select_for_update(of=("self",)).get(
            public_id=order_public_id
        )
    except Order.DoesNotExist as error:
        raise ValidationError({"order": "Order not found."}) from error

    if order.status not in (
        Order.Status.AWAITING_LOCKER,
        Order.Status.ASSIGNED,
        Order.Status.EXPIRED,
    ):
        raise ValidationError(
            {
                "order": (
                    "Courier cannot be assigned in the current order status."
                )
            }
        )

    try:
        courier = (
            User.objects.select_for_update(of=("self",))
            .select_related("profile")
            .get(id=courier_id)
        )
    except User.DoesNotExist as error:
        raise ValidationError(
            {"courier_id": "Courier not found."}
        ) from error

    profile = getattr(courier, "profile", None)

    if (
        profile is None
        or profile.role != UserProfile.Role.COURIER
    ):
        raise ValidationError(
            {"courier_id": "Selected user is not a courier."}
        )

    if order.assigned_courier_id == courier.id:
        return order

    if not courier.is_active:
        raise ValidationError({"courier_id": "Selected courier account is inactive."})
    if not profile.is_on_shift:
        raise ValidationError({"courier_id": "Selected courier is not on shift."})

    active_courier_statuses = (
        Order.Status.AWAITING_LOCKER,
        Order.Status.ASSIGNED,
        Order.Status.EXPIRED,
    )
    if Order.objects.filter(
        assigned_courier=courier,
        status__in=active_courier_statuses,
    ).exclude(pk=order.pk).exists():
        raise ValidationError({"courier_id": "Selected courier already has an active order."})

    order.assigned_courier = courier
    order.courier_assigned_at = timezone.now()
    order.full_clean()

    order.save(
        update_fields=(
            "assigned_courier",
            "courier_assigned_at",
            "updated_at",
        )
    )

    notification_type = Notification.Type.COURIER_ASSIGNED
    title = "New order assignment"
    message = "A new order has been assigned to you."

    if order.status == Order.Status.EXPIRED:
        notification_type = Notification.Type.COURIER_RETURN_REQUIRED
        title = "Order return required"
        message = "An expired order has been assigned to you for return."

    create_notification(
        user=courier,
        order=order,
        notification_type=notification_type,
        title=title,
        message=message,
        data={
            "order_public_id": str(order.public_id),
            "status": order.status,
        },
    )


    create_audit_log(
    actor=actor,
    action=AuditLog.Action.ORDER_COURIER_ASSIGNED,
    target_type=AuditLog.TargetType.ORDER,
    target_id=order.public_id,
    metadata={
        "courier_id": courier.id,
        "courier_username": courier.username,
    },
   )


    return order


@transaction.atomic
def issue_return_qr_token(*, order_public_id, courier):
    if not courier or not courier.pk:
        raise ValidationError(
            {"courier": "A valid courier is required."}
        )

    profile = getattr(courier, "profile", None)

    if (
        profile is None
        or profile.role != UserProfile.Role.COURIER
    ):
        raise ValidationError(
            {"courier": "A valid courier is required."}
        )

    try:
        order = (
            Order.objects.select_for_update(of=("self",))
            .select_related(
                "locker_station",
                "assigned_drawer",
            )
            .get(public_id=order_public_id)
        )
    except Order.DoesNotExist as error:
        raise ValidationError({"order": "Order not found."}) from error

    if order.assigned_courier_id != courier.id:
        raise ValidationError({"order": "Order not found."})

    if order.status != Order.Status.EXPIRED:
        raise ValidationError(
            {"order": "Only expired orders can be returned."}
        )

    if not order.locker_station_id or not order.assigned_drawer_id:
        raise ValidationError(
            {"order": "Order has no assigned locker and drawer."}
        )

    if order.locker_station.status != LockerStation.Status.ONLINE:
        raise ValidationError(
            {"locker_station": "Locker station must be online."}
        )

    drawer = Drawer.objects.select_for_update().get(
        id=order.assigned_drawer_id
    )

    if drawer.status != Drawer.Status.RETURN_PENDING:
        raise ValidationError(
            {"drawer": "Drawer is not ready for courier return."}
        )

    now = timezone.now()

    QRToken.objects.filter(
        order=order,
        purpose=QRToken.Purpose.COURIER_RETURN,
        used_at__isnull=True,
        revoked_at__isnull=True,
    ).update(revoked_at=now)

    raw_token = secrets.token_urlsafe(32)
    expires_at = now + RETURN_QR_TOKEN_LIFETIME

    qr_token = QRToken.objects.create(
        order=order,
        purpose=QRToken.Purpose.COURIER_RETURN,
        token_hash=hash_qr_token(raw_token),
        expires_at=expires_at,
    )

    LockerEventLog.objects.create(
        locker_station=order.locker_station,
        drawer=drawer,
        order=order,
        actor=courier,
        event_type=LockerEventLog.EventType.RETURN_TOKEN_ISSUED,
        metadata={
            "expires_at": expires_at.isoformat(),
        },
    )

    return qr_token, raw_token


@transaction.atomic
def authorize_return_by_qr(*, raw_token, device_user):
    if not isinstance(raw_token, str) or not raw_token.strip():
        raise ValidationError(
            {"token": "A valid QR token is required."}
        )

    if not device_user or not device_user.pk:
        raise ValidationError(
            {"device": "A valid locker device is required."}
        )

    try:
        locker_device = (
            LockerDevice.objects.select_for_update()
            .select_related("locker_station")
            .get(user=device_user, is_active=True)
        )
    except LockerDevice.DoesNotExist as error:
        raise ValidationError(
            {"device": "Active locker device not found."}
        ) from error

    token_hash = hash_qr_token(raw_token.strip())

    try:
        qr_token = QRToken.objects.select_for_update().get(
            token_hash=token_hash
        )
    except QRToken.DoesNotExist as error:
        raise ValidationError(
            {"token": "Invalid or expired QR token."}
        ) from error

    if qr_token.purpose != QRToken.Purpose.COURIER_RETURN:
        raise ValidationError(
            {"token": "Invalid or expired QR token."}
        )

    now = timezone.now()

    if qr_token.used_at or qr_token.revoked_at or qr_token.expires_at <= now:
        raise ValidationError(
            {"token": "Invalid or expired QR token."}
        )

    order = (
        Order.objects.select_for_update(of=("self",))
        .select_related(
            "locker_station",
            "assigned_drawer",
        )
        .get(id=qr_token.order_id)
    )

    if order.status != Order.Status.EXPIRED:
        raise ValidationError(
            {"order": "Order is not ready for return."}
        )

    if order.return_opened_at:
        raise ValidationError(
            {"order": "Return retrieval is already in progress."}
        )

    if (
        not order.locker_station_id
        or not order.assigned_drawer_id
        or order.locker_station_id != locker_device.locker_station_id
    ):
        raise ValidationError(
            {"device": "This device cannot open the order drawer."}
        )

    if locker_device.locker_station.status != LockerStation.Status.ONLINE:
        raise ValidationError(
            {"locker_station": "Locker station must be online."}
        )

    drawer = Drawer.objects.select_for_update().get(
        id=order.assigned_drawer_id
    )

    if drawer.locker_station_id != locker_device.locker_station_id:
        raise ValidationError(
            {"drawer": "Drawer does not belong to this locker device."}
        )

    if drawer.status != Drawer.Status.RETURN_PENDING:
        raise ValidationError(
            {"drawer": "Drawer is not ready for courier return."}
        )

    qr_token.used_at = now
    qr_token.save(update_fields=("used_at",))

    order.return_opened_at = now
    order.save(
        update_fields=(
            "return_opened_at",
            "updated_at",
        )
    )

    LockerEventLog.objects.create(
        locker_station=locker_device.locker_station,
        drawer=drawer,
        order=order,
        actor=device_user,
        event_type=LockerEventLog.EventType.RETURN_OPENED,
        metadata={
            "device_code": locker_device.device_code,
        },
    )

    return order, drawer


@transaction.atomic
def confirm_package_return(*, order_public_id, device_user):
    if not device_user or not device_user.pk:
        raise ValidationError(
            {"device": "A valid locker device is required."}
        )

    try:
        locker_device = (
            LockerDevice.objects.select_for_update()
            .select_related("locker_station")
            .get(user=device_user, is_active=True)
        )
    except LockerDevice.DoesNotExist as error:
        raise ValidationError(
            {"device": "Active locker device not found."}
        ) from error

    try:
        order = (
            Order.objects.select_for_update(of=("self",))
            .select_related(
                "locker_station",
                "assigned_drawer",
            )
            .get(public_id=order_public_id)
        )
    except Order.DoesNotExist as error:
        raise ValidationError({"order": "Order not found."}) from error

    if order.status != Order.Status.EXPIRED:
        raise ValidationError(
            {"order": "Order cannot be returned in its current status."}
        )

    if not order.return_opened_at:
        raise ValidationError(
            {"order": "Return QR must be scanned before confirmation."}
        )

    if (
        not order.locker_station_id
        or not order.assigned_drawer_id
        or order.locker_station_id != locker_device.locker_station_id
    ):
        raise ValidationError(
            {"device": "This device cannot confirm this order return."}
        )

    if locker_device.locker_station.status != LockerStation.Status.ONLINE:
        raise ValidationError(
            {"locker_station": "Locker station must be online."}
        )

    drawer = Drawer.objects.select_for_update().get(
        id=order.assigned_drawer_id
    )

    if drawer.locker_station_id != locker_device.locker_station_id:
        raise ValidationError(
            {"drawer": "Drawer does not belong to this locker device."}
        )

    if drawer.status != Drawer.Status.RETURN_PENDING:
        raise ValidationError(
            {"drawer": "Drawer is not ready for return confirmation."}
        )

    now = timezone.now()

    QRToken.objects.filter(
        order=order,
        used_at__isnull=True,
        revoked_at__isnull=True,
    ).update(revoked_at=now)

    drawer.status = Drawer.Status.AVAILABLE
    drawer.save(update_fields=("status", "updated_at"))

    order.status = Order.Status.RETURNED
    order.returned_at = now
    order.save(
        update_fields=(
            "status",
            "returned_at",
            "updated_at",
        )
    )

    LockerEventLog.objects.create(
        locker_station=locker_device.locker_station,
        drawer=drawer,
        order=order,
        actor=device_user,
        event_type=LockerEventLog.EventType.PACKAGE_RETURNED,
        metadata={
            "device_code": locker_device.device_code,
        },
    )

    LockerEventLog.objects.create(
        locker_station=locker_device.locker_station,
        drawer=drawer,
        order=order,
        actor=device_user,
        event_type=LockerEventLog.EventType.DRAWER_RELEASED,
        metadata={
            "device_code": locker_device.device_code,
        },
    )

    return order, drawer
