from django.core.cache import cache
from django.db.models import Count
from rest_framework import generics
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from accounts.models import UserProfile
from accounts.permissions import IsAdminRole

from .models import Category, Product
from .serializers import CategorySerializer, ProductSerializer


from .cache import ACTIVE_PRODUCT_LIST_CACHE_KEY


class ProductListCreateAPIView(generics.ListCreateAPIView):
    serializer_class = ProductSerializer

    def get_queryset(self):
        queryset = Product.objects.all()
        queryset = queryset.select_related("category")

        if self.request.method == "GET":
            queryset = queryset.filter(is_active=True)

        return queryset

    def get_permissions(self):
        if self.request.method == "POST":
            return [IsAdminRole()]

        return [AllowAny()]


    def list(self, request, *args, **kwargs):
        cached_products = cache.get(
            ACTIVE_PRODUCT_LIST_CACHE_KEY
        )

        if cached_products is not None:
            return Response(cached_products)

        response = super().list(request, *args, **kwargs)

        cache.set(
            ACTIVE_PRODUCT_LIST_CACHE_KEY,
            response.data,
        )

        return response   


class AdminProductListAPIView(generics.ListAPIView):
    serializer_class = ProductSerializer
    permission_classes = [IsAdminRole]

    def get_queryset(self):
        return Product.objects.select_related("category").all()


class ActiveCategoryListAPIView(generics.ListAPIView):
    serializer_class = CategorySerializer
    permission_classes = [AllowAny]

    def get_queryset(self):
        return Category.objects.filter(is_active=True).annotate(
            product_count=Count("products")
        )


class AdminCategoryListCreateAPIView(generics.ListCreateAPIView):
    queryset = Category.objects.annotate(product_count=Count("products"))
    serializer_class = CategorySerializer
    permission_classes = [IsAdminRole]


class AdminCategoryDetailAPIView(generics.RetrieveUpdateAPIView):
    queryset = Category.objects.annotate(product_count=Count("products"))
    serializer_class = CategorySerializer
    permission_classes = [IsAdminRole]


class ProductRetrieveUpdateAPIView(generics.RetrieveUpdateAPIView):
    serializer_class = ProductSerializer

    def get_queryset(self):
        queryset = Product.objects.all()
        queryset = queryset.select_related("category")

        if self.request.method == "GET":
            user = self.request.user
            is_admin = (
                user.is_authenticated
                and hasattr(user, "profile")
                and user.profile.role == UserProfile.Role.ADMIN
            )

            if not is_admin:
                queryset = queryset.filter(is_active=True)

        return queryset

    def get_permissions(self):
        if self.request.method in ("PUT", "PATCH"):
            return [IsAdminRole()]

        return [AllowAny()]
