from rest_framework import generics
from rest_framework.permissions import AllowAny

from accounts.models import UserProfile
from accounts.permissions import IsAdminRole

from .models import Product
from .serializers import ProductSerializer


class ProductListCreateAPIView(generics.ListCreateAPIView):
    serializer_class = ProductSerializer

    def get_queryset(self):
        queryset = Product.objects.all()

        if self.request.method == "GET":
            queryset = queryset.filter(is_active=True)

        return queryset

    def get_permissions(self):
        if self.request.method == "POST":
            return [IsAdminRole()]

        return [AllowAny()]


class ProductRetrieveUpdateAPIView(generics.RetrieveUpdateAPIView):
    serializer_class = ProductSerializer

    def get_queryset(self):
        queryset = Product.objects.all()

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