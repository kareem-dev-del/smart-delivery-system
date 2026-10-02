from django.urls import path

from .views import (
    NotificationListAPIView,
    NotificationMarkAllReadAPIView,
    NotificationMarkReadAPIView,
)


urlpatterns = [
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