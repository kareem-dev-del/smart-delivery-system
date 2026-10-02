from django.urls import path

from .views import ProductListCreateAPIView, ProductRetrieveUpdateAPIView

urlpatterns = [
    path("", ProductListCreateAPIView.as_view(), name="product-list-create"),
    path("<int:pk>/", ProductRetrieveUpdateAPIView.as_view(), name="product-detail"),
]