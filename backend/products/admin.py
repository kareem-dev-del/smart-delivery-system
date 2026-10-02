from django.contrib import admin

from .models import Product


@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = ("name", "price", "stock", "size", "is_active", "created_at")
    list_filter = ("size", "is_active")
    search_fields = ("name", "description")
    ordering = ("name",)