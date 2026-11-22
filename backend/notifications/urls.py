from django.urls import path

from .views import (
    AdminNotificationListAPIView,
    NotificationListAPIView,
    NotificationMarkAllReadAPIView,
    NotificationMarkReadAPIView,
    PushDeviceAPIView,
)


urlpatterns = [
    path("devices/", PushDeviceAPIView.as_view(), name="push-device"),
    path(
        "admin/",
        AdminNotificationListAPIView.as_view(),
        name="admin-notification-list",
    ),
    path("", NotificationListAPIView.as_view(), name="notification-list"),
    path(
        "read-all/",
        NotificationMarkAllReadAPIView.as_view(),
        name="notification-mark-all-read",
    ),
    path(
        "<int:pk>/read/",
        NotificationMarkReadAPIView.as_view(),
        name="notification-mark-read",
    ),
]
