from django.urls import path

from .views import (
    LockerStationListAPIView,
    LockerStationRetrieveAPIView,
    LockerPickupScanAPIView,
    LockerCollectionConfirmationAPIView,
    LockerReturnScanAPIView,
    LockerReturnConfirmationAPIView,
    AdminLockerStationCreateAPIView,
    AdminLockerStationUpdateAPIView,
    AdminDrawerCreateAPIView,
    AdminDrawerMaintenanceStatusAPIView,
    AdminLockerDeviceProvisionAPIView,
    LockerDeviceHeartbeatAPIView,
    AdminLockerDeviceListAPIView,
    AdminDashboardSummaryAPIView,
    AdminLockerDeviceActivationAPIView,
)


urlpatterns = [
    path("", LockerStationListAPIView.as_view(), name="locker-list"),
    path("<int:pk>/", LockerStationRetrieveAPIView.as_view(), name="locker-detail"),
    path(
    "pickup-scan/",
    LockerPickupScanAPIView.as_view(),
    name="locker-pickup-scan"),

    path(
    "orders/<uuid:public_id>/confirm-collection/",
    LockerCollectionConfirmationAPIView.as_view(),
    name="locker-confirm-collection"),

    path(
    "return-scan/",
    LockerReturnScanAPIView.as_view(),
    name="locker-return-scan",
    ),

    path(
    "orders/<uuid:public_id>/confirm-return/",
    LockerReturnConfirmationAPIView.as_view(),
    name="locker-confirm-return",
   ),

   path(
    "admin/stations/",
    AdminLockerStationCreateAPIView.as_view(),
    name="admin-locker-station-create",
    ),
    path(
        "admin/stations/<int:pk>/",
        AdminLockerStationUpdateAPIView.as_view(),
        name="admin-locker-station-update",
    ),


    path(
    "admin/stations/<int:locker_station_id>/drawers/",
    AdminDrawerCreateAPIView.as_view(),
    name="admin-drawer-create",
    ),
    path(
        "admin/drawers/<int:drawer_id>/maintenance-status/",
        AdminDrawerMaintenanceStatusAPIView.as_view(),
        name="admin-drawer-maintenance-status",
    ),

    path(
    "admin/stations/<int:locker_station_id>/device/",
    AdminLockerDeviceProvisionAPIView.as_view(),
    name="admin-locker-device-provision",
    ),

    path(
    "device/heartbeat/",
    LockerDeviceHeartbeatAPIView.as_view(),
    name="locker-device-heartbeat",
    ),


    path(
    "admin/devices/",
    AdminLockerDeviceListAPIView.as_view(),
    name="admin-locker-device-list",
    ),

    path(
    "admin/dashboard/",
    AdminDashboardSummaryAPIView.as_view(),
    name="admin-dashboard-summary",
    ),

    path(
    "admin/devices/<int:device_id>/activation/",
    AdminLockerDeviceActivationAPIView.as_view(),
    name="admin-locker-device-activation",
    ),
                                      
]