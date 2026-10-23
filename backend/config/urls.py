from django.contrib import admin
from django.conf.urls.static import static
from django.urls import include, path

from django.conf import settings
from drf_spectacular.views import (
    SpectacularAPIView,
    SpectacularSwaggerView,
)

from accounts.views import (
    ThrottledTokenObtainPairView,
    ThrottledTokenRefreshView,
)



from config.health import health, readiness


urlpatterns = [

    path("health/", health, name="health"),
    path("ready/", readiness, name="readiness"),
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


if settings.API_DOCUMENTATION_ENABLED:
    urlpatterns += [
        path(
            "api/schema/",
            SpectacularAPIView.as_view(),
            name="api-schema",
        ),
        path(
            "api/docs/",
            SpectacularSwaggerView.as_view(
                url_name="api-schema",
            ),
            name="api-docs",
        ),
    ]

if settings.DEBUG:
    urlpatterns += static(
        settings.MEDIA_URL,
        document_root=settings.MEDIA_ROOT,
    )
