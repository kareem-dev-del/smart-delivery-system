from rest_framework import serializers

from .models import Category, Product


class CategorySerializer(serializers.ModelSerializer):
    product_count = serializers.IntegerField(read_only=True, default=0)

    class Meta:
        model = Category
        fields = (
            "id",
            "name",
            "description",
            "is_active",
            "product_count",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("id", "created_at", "updated_at")


class ProductSerializer(serializers.ModelSerializer):
    clear_image = serializers.BooleanField(write_only=True, required=False)
    category = serializers.PrimaryKeyRelatedField(read_only=True)
    category_name = serializers.CharField(
        source="category.name",
        read_only=True,
        allow_null=True,
    )
    category_id = serializers.PrimaryKeyRelatedField(
        source="category",
        queryset=Category.objects.all(),
        required=False,
        allow_null=True,
        write_only=True,
    )

    class Meta:
        model = Product
        fields = (
            "id",
            "name",
            "category",
            "category_name",
            "category_id",
            "image",
            "clear_image",
            "description",
            "price",
            "stock",
            "size",
            "is_active",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("id", "created_at", "updated_at")

    def validate_image(self, value):
        if value is None:
            return value

        if value.size > 5 * 1024 * 1024:
            raise serializers.ValidationError("Image must be 5 MB or smaller.")

        image = value.image
        if image.format not in {"JPEG", "PNG", "WEBP"}:
            raise serializers.ValidationError(
                "Use a JPEG, PNG, or WebP image."
            )
        if image.width > 6000 or image.height > 6000:
            raise serializers.ValidationError(
                "Image dimensions must be 6000 pixels or smaller."
            )

        return value

    def validate(self, attrs):
        if attrs.get("clear_image") and attrs.get("image"):
            raise serializers.ValidationError(
                {"image": "Choose a new image or remove the current image, not both."}
            )
        return attrs

    def update(self, instance, validated_data):
        clear_image = validated_data.pop("clear_image", False)
        if clear_image:
            instance.image = None
        return super().update(instance, validated_data)

    def create(self, validated_data):
        validated_data.pop("clear_image", None)
        return super().create(validated_data)
