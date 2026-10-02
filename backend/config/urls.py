from django.contrib import admin
from django.urls import include, path

from accounts.views import (
    ThrottledTokenObtainPairView,
    ThrottledTokenRefreshView,
)


urlpatterns = [
    path("admin/", admin.site.urls),
   path(
    "api/token/",
    ThrottledTokenObtainPairView.as_view(),
    name="token-obtain-pair",
    ),

    path(
        "api/token/refresh/",
        ThrottledTokenRefreshView.as_view(),
        name="token-refresh",
    ),
    path("api/accounts/", include("accounts.urls")),
    path("api/products/", include("products.urls")),
    path("api/lockers/", include("lockers.urls")),
    path("api/orders/", include("orders.urls")),
    path("api/notifications/", include("notifications.urls")),
    path("api/audit/", include("audit.urls")),
]