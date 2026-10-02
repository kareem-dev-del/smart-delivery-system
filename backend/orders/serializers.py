from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework import serializers

from lockers.models import LockerStation

from .models import Order, OrderItem

from .services import create_order


class OrderItemCreateSerializer(serializers.Serializer):
    product_id = serializers.IntegerField(min_value=1)
    quantity = serializers.IntegerField(min_value=1)


class OrderCreateSerializer(serializers.Serializer):
    items = OrderItemCreateSerializer(many=True, allow_empty=False)

    def validate_items(self, items):
        product_ids = [item["product_id"] for item in items]

        if len(product_ids) != len(set(product_ids)):
            raise serializers.ValidationError(
                "A product can appear only once in an order."
            )

        return items

    def create(self, validated_data):
        try:
            return create_order(
                customer=validated_data["customer"],
                items=validated_data["items"],
            )
        except DjangoValidationError as error:
            detail = getattr(error, "message_dict", error.messages)
            raise serializers.ValidationError(detail) from error


class OrderItemReadSerializer(serializers.ModelSerializer):
    line_total = serializers.DecimalField(
        max_digits=12,
        decimal_places=2,
        read_only=True,
    )

    class Meta:
        model = OrderItem
        fields = (
            "product",
            "product_name",
            "product_size",
            "unit_price",
            "quantity",
            "line_total",
        )

class LockerSummarySerializer(serializers.ModelSerializer):
    class Meta:
        model = LockerStation
        fields = (
            "id",
            "name",
            "code",
            "address",
            "latitude",
            "longitude",
        )


class OrderReadSerializer(serializers.ModelSerializer):
    items = OrderItemReadSerializer(many=True, read_only=True)
    locker = LockerSummarySerializer(
        source="locker_station",
        read_only=True,
        allow_null=True,
    )

    class Meta:
        model = Order
        fields = (
            "public_id",
            "status",
            "total_amount",
            "locker",
            "courier_assigned_at",
            "assigned_at",
            "ready_for_pickup_at",
            "delivery_deadline",
            "collected_at",
            "returned_at",
            "cancelled_at",
            "created_at",
            "updated_at",
            "items",
        )
        read_only_fields = fields


class OrderAdminReadSerializer(OrderReadSerializer):
    customer = serializers.IntegerField(
        source="customer_id",
        read_only=True,
    )
    customer_username = serializers.CharField(
        source="customer.username",
        read_only=True,
    )

    assigned_courier = serializers.IntegerField(
        source="assigned_courier_id",
        read_only=True,
        allow_null=True,
    )
    assigned_courier_username = serializers.CharField(
        source="assigned_courier.username",
        read_only=True,
        allow_null=True,
    )

    locker_station = serializers.IntegerField(
        source="locker_station_id",
        read_only=True,
        allow_null=True,
    )
    assigned_drawer = serializers.IntegerField(
        source="assigned_drawer_id",
        read_only=True,
        allow_null=True,
    )
    assigned_drawer_number = serializers.IntegerField(
        source="assigned_drawer.number",
        read_only=True,
        allow_null=True,
    )

    class Meta(OrderReadSerializer.Meta):
        fields = OrderReadSerializer.Meta.fields + (
            "customer",
            "customer_username",
            "assigned_courier",
            "assigned_courier_username",
            "locker_station",
            "assigned_drawer",
            "assigned_drawer_number",
            "pickup_opened_at",
            "return_opened_at",

        )
        read_only_fields = fields

class CourierOrderItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = OrderItem
        fields = (
            "product_name",
            "product_size",
            "quantity",
        )


class CourierAssignmentOrderSerializer(serializers.ModelSerializer):
    items = CourierOrderItemSerializer(many=True, read_only=True)

    locker_name = serializers.CharField(
        source="locker_station.name",
        read_only=True,
        allow_null=True,
    )
    locker_code = serializers.CharField(
        source="locker_station.code",
        read_only=True,
        allow_null=True,
    )
    locker_address = serializers.CharField(
        source="locker_station.address",
        read_only=True,
        allow_null=True,
    )
    drawer_number = serializers.IntegerField(
        source="assigned_drawer.number",
        read_only=True,
        allow_null=True,
    )

    class Meta:
        model = Order
        fields = (
            "public_id",
            "status",
            "locker_name",
            "locker_code",
            "locker_address",
            "drawer_number",
            "courier_assigned_at",
            "assigned_at",
            "created_at",
            "items",
        )


class OrderDrawerAssignmentSerializer(serializers.Serializer):
    locker_station_id = serializers.IntegerField(min_value=1)
    drawer_id = serializers.IntegerField(min_value=1)  


class PickupQRResponseSerializer(serializers.Serializer):
    token = serializers.CharField(read_only=True)
    expires_at = serializers.DateTimeField(read_only=True)
    order_public_id = serializers.UUIDField(read_only=True)
    locker_name = serializers.CharField(read_only=True)
    locker_code = serializers.CharField(read_only=True)
    locker_address = serializers.CharField(read_only=True)

class CourierReturnQRResponseSerializer(serializers.Serializer):
    token = serializers.CharField(read_only=True)
    expires_at = serializers.DateTimeField(read_only=True)
    order_public_id = serializers.UUIDField(read_only=True)
    locker_name = serializers.CharField(read_only=True)
    locker_code = serializers.CharField(read_only=True)
    locker_address = serializers.CharField(read_only=True)    



class OrderCourierAssignmentSerializer(serializers.Serializer):
    courier_id = serializers.IntegerField(min_value=1)


class OrderCourierAssignmentResponseSerializer(serializers.Serializer):
    order_public_id = serializers.UUIDField(read_only=True)
    courier_id = serializers.IntegerField(read_only=True)
    courier_username = serializers.CharField(read_only=True)
    courier_assigned_at = serializers.DateTimeField(read_only=True)  


class AdminOrderListFilterSerializer(serializers.Serializer):
    status = serializers.ChoiceField(
        choices=Order.Status.choices,
        required=False,
    )
    locker_station_id = serializers.IntegerField(
        min_value=1,
        required=False,
    )
    courier_id = serializers.IntegerField(
        min_value=1,
        required=False,
    )
    customer_id = serializers.IntegerField(
        min_value=1,
        required=False,
    )
    search = serializers.CharField(
        required=False,
        allow_blank=True,
        trim_whitespace=True,
        max_length=100,
    )    

