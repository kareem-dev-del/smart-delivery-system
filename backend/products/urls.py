from django.urls import path

from .views import (
    AdminProductListAPIView,
    ActiveCategoryListAPIView,
    AdminCategoryDetailAPIView,
    AdminCategoryListCreateAPIView,
    ProductListCreateAPIView,
    ProductRetrieveUpdateAPIView,
)

urlpatterns = [
    path("categories/", ActiveCategoryListAPIView.as_view(), name="category-list"),
    path("admin/", AdminProductListAPIView.as_view(), name="admin-product-list"),
    path(
        "admin/categories/",
        AdminCategoryListCreateAPIView.as_view(),
        name="admin-category-list-create",
    ),
    path(
        "admin/categories/<int:pk>/",
        AdminCategoryDetailAPIView.as_view(),
        name="admin-category-detail",
    ),
    path("", ProductListCreateAPIView.as_view(), name="product-list-create"),
    path("<int:pk>/", ProductRetrieveUpdateAPIView.as_view(), name="product-detail"),
]
