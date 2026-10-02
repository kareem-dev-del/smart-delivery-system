from django.contrib import admin

from .models import (
    Drawer,
    LockerDevice,
    LockerEventLog,
    LockerStation,
)


class DrawerInline(admin.TabularInline):
    model = Drawer
    extra = 0


@admin.register(LockerStation)
class LockerStationAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "name",
        "code",
        "status",
        "address",
        "created_at",
    )
    list_filter = ("status",)
    search_fields = ("name", "code", "address")
    inlines = [DrawerInline]


@admin.register(Drawer)
class DrawerAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "locker_station",
        "number",
        "size",
        "status",
        "created_at",
    )
    list_filter = ("size", "status", "locker_station")
    search_fields = (
        "locker_station__name",
        "locker_station__code",
    )


@admin.register(LockerDevice)
class LockerDeviceAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "device_code",
        "locker_station",
        "user",
        "is_active",
    )
    list_filter = ("is_active",)
    search_fields = (
        "device_code",
        "locker_station__code",
        "user__username",
    )


@admin.register(LockerEventLog)
class LockerEventLogAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "event_type",
        "order",
        "locker_station",
        "drawer",
        "actor",
        "occurred_at",
    )
    list_filter = ("event_type", "locker_station")
    search_fields = (
        "order__public_id",
        "locker_station__code",
        "actor__username",
    )
    list_select_related = (
        "order",
        "locker_station",
        "drawer",
        "actor",
    )
    readonly_fields = ("occurred_at",)