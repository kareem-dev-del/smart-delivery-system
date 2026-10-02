from django.contrib import admin

from .models import Order, OrderItem, QRToken



class OrderItemInline(admin.TabularInline):
    model = OrderItem
    extra = 0
    readonly_fields = ("line_total",)


@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    list_display = (
        "public_id",
        "customer",
        "status",
        "locker_station",
        "assigned_drawer",
        "total_amount",
        "created_at",
        "assigned_courier",
    )
    list_filter = ("status", "locker_station")
    search_fields = (
        "public_id",
        "customer__username",
        "locker_station__code",
    )
    readonly_fields = (
        "public_id",
        "created_at",
        "updated_at",
        "assigned_at",
        "ready_for_pickup_at",
        "collected_at",
        "return_opened_at",
        "returned_at",
        "cancelled_at",
    )
    list_select_related = (
        "customer",
        "locker_station",
        "assigned_drawer",
        "assigned_courier",
    )
    inlines = [OrderItemInline]


@admin.register(OrderItem)
class OrderItemAdmin(admin.ModelAdmin):
    list_display = (
        "order",
        "product_name",
        "product_size",
        "unit_price",
        "quantity",
        "line_total",
    )
    list_filter = ("product_size",)
    search_fields = ("product_name", "order__public_id")

@admin.register(QRToken)
class QRTokenAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "order",
        "expires_at",
        "used_at",
        "revoked_at",
        "created_at",
        "purpose",
    )
    search_fields = ("order__public_id",)
    readonly_fields = (
        "token_hash",
        "created_at",
        "used_at",
        "revoked_at",
       
    )
    list_select_related = ("order",)