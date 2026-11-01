import re

from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.db import transaction
from rest_framework import serializers
from django.core.exceptions import ValidationError as DjangoValidationError

from .models import UserProfile


User = get_user_model()


def normalize_phone(value):
    normalized_phone = (
        value.strip()
        .replace(" ", "")
        .replace("-", "")
    )

    if not re.fullmatch(r"\+?[0-9]{8,15}", normalized_phone):
        raise serializers.ValidationError(
            "Enter a valid phone number."
        )

    return normalized_phone


class AccountProfileSerializer(serializers.ModelSerializer):
    phone = serializers.CharField(
        source="profile.phone",
        read_only=True,
    )
    role = serializers.CharField(
        source="profile.role",
        read_only=True,
    )

    class Meta:
        model = User
        fields = (
            "id",
            "username",
            "first_name",
            "last_name",
            "email",
            "phone",
            "role",
        )


class AdminCourierSerializer(AccountProfileSerializer):
    """The courier directory exposed to admin operations screens."""

    is_active = serializers.BooleanField(read_only=True)
    is_on_shift = serializers.BooleanField(
        source="profile.is_on_shift",
        read_only=True,
    )
    shift_updated_at = serializers.DateTimeField(
        source="profile.shift_updated_at",
        read_only=True,
        allow_null=True,
    )
    active_order_count = serializers.IntegerField(read_only=True, default=0)
    dispatch_status = serializers.SerializerMethodField()

    class Meta(AccountProfileSerializer.Meta):
        fields = AccountProfileSerializer.Meta.fields + (
            "is_active",
            "is_on_shift",
            "shift_updated_at",
            "active_order_count",
            "dispatch_status",
        )

    def get_dispatch_status(self, obj):
        if not obj.is_active:
            return "inactive"
        if not obj.profile.is_on_shift:
            return "off_shift"
        if getattr(obj, "active_order_count", 0):
            return "busy"
        return "available"


class AdminManagedAccountSerializer(AccountProfileSerializer):
    is_active = serializers.BooleanField(read_only=True)
    is_on_shift = serializers.BooleanField(
        source="profile.is_on_shift",
        read_only=True,
    )
    shift_updated_at = serializers.DateTimeField(
        source="profile.shift_updated_at",
        read_only=True,
        allow_null=True,
    )
    active_order_count = serializers.IntegerField(read_only=True, default=0)
    dispatch_status = serializers.SerializerMethodField()

    class Meta(AccountProfileSerializer.Meta):
        fields = AccountProfileSerializer.Meta.fields + (
            "is_active",
            "is_on_shift",
            "shift_updated_at",
            "active_order_count",
            "dispatch_status",
        )

    def get_dispatch_status(self, obj):
        if obj.profile.role != UserProfile.Role.COURIER:
            return "not_applicable"
        return AdminCourierSerializer.get_dispatch_status(self, obj)


class AdminManagedAccountCreateSerializer(serializers.Serializer):
    username = serializers.CharField(min_length=3, max_length=150)
    password = serializers.CharField(write_only=True, trim_whitespace=False)
    password_confirm = serializers.CharField(write_only=True, trim_whitespace=False)
    first_name = serializers.CharField(max_length=150, required=False, allow_blank=True)
    last_name = serializers.CharField(max_length=150, required=False, allow_blank=True)
    email = serializers.EmailField(required=False, allow_blank=True)
    phone = serializers.CharField(max_length=20)
    role = serializers.ChoiceField(
        choices=(
            (UserProfile.Role.CUSTOMER, "Customer"),
            (UserProfile.Role.COURIER, "Courier"),
            (UserProfile.Role.ADMIN, "Admin"),
        )
    )

    def validate_username(self, value):
        normalized_username = value.strip().lower()
        if len(normalized_username) < 3:
            raise serializers.ValidationError("Username must contain at least 3 characters.")
        if User.objects.filter(username__iexact=normalized_username).exists():
            raise serializers.ValidationError("This username is already in use.")
        return normalized_username

    def validate_phone(self, value):
        return normalize_phone(value)

    def validate(self, attrs):
        if attrs["password"] != attrs["password_confirm"]:
            raise serializers.ValidationError({"password_confirm": "Password confirmation does not match."})

        user = User(
            username=attrs["username"],
            first_name=attrs.get("first_name", ""),
            last_name=attrs.get("last_name", ""),
            email=attrs.get("email", ""),
        )
        try:
            validate_password(attrs["password"], user)
        except DjangoValidationError as error:
            raise serializers.ValidationError({"password": list(error.messages)}) from error
        return attrs

    @transaction.atomic
    def create(self, validated_data):
        validated_data.pop("password_confirm")
        phone = validated_data.pop("phone")
        role = validated_data.pop("role")
        password = validated_data.pop("password")
        user = User.objects.create_user(password=password, **validated_data)
        user.profile.role = role
        user.profile.phone = phone
        user.profile.save(update_fields=("role", "phone", "updated_at"))
        return user


class AdminAccountStatusSerializer(serializers.Serializer):
    is_active = serializers.BooleanField()


class AdminCourierShiftSerializer(serializers.Serializer):
    is_on_shift = serializers.BooleanField()


class AuthenticationResponseSerializer(serializers.Serializer):
    user = AccountProfileSerializer(read_only=True)
    access = serializers.CharField(read_only=True)
    refresh = serializers.CharField(read_only=True)


class CustomerRegistrationSerializer(serializers.Serializer):
    username = serializers.CharField(
        min_length=3,
        max_length=150,
    )
    password = serializers.CharField(
        write_only=True,
        trim_whitespace=False,
    )
    password_confirm = serializers.CharField(
        write_only=True,
        trim_whitespace=False,
    )
    first_name = serializers.CharField(
        max_length=150,
        required=False,
        allow_blank=True,
    )
    last_name = serializers.CharField(
        max_length=150,
        required=False,
        allow_blank=True,
    )
    email = serializers.EmailField(
        required=False,
        allow_blank=True,
    )
    phone = serializers.CharField(max_length=20)

    def validate_username(self, value):
        normalized_username = value.strip().lower()

        if User.objects.filter(
            username__iexact=normalized_username
        ).exists():
            raise serializers.ValidationError(
                "This username is already in use."
            )

        return normalized_username

    def validate_phone(self, value):
        return normalize_phone(value)

    def validate(self, attrs):
        if attrs["password"] != attrs["password_confirm"]:
            raise serializers.ValidationError(
                {
                    "password_confirm": (
                        "Password confirmation does not match."
                    )
                }
            )

        user = User(
            username=attrs["username"],
            first_name=attrs.get("first_name", ""),
            last_name=attrs.get("last_name", ""),
            email=attrs.get("email", ""),
        )

        try:
            validate_password(attrs["password"], user)
        except Exception as error:
            raise serializers.ValidationError(
                {"password": list(error.messages)}
            ) from error

        return attrs

    @transaction.atomic
    def create(self, validated_data):
        validated_data.pop("password_confirm")

        phone = validated_data.pop("phone")
        password = validated_data.pop("password")

        user = User.objects.create_user(
            password=password,
            **validated_data,
        )

        user.profile.role = UserProfile.Role.CUSTOMER
        user.profile.phone = phone
        user.profile.save(
            update_fields=(
                "role",
                "phone",
                "updated_at",
            )
        )

        return user


class AccountProfileUpdateSerializer(serializers.Serializer):
    first_name = serializers.CharField(
        max_length=150,
        required=False,
        allow_blank=True,
    )
    last_name = serializers.CharField(
        max_length=150,
        required=False,
        allow_blank=True,
    )
    email = serializers.EmailField(
        required=False,
        allow_blank=True,
    )
    phone = serializers.CharField(
        max_length=20,
        required=False,
    )

    def validate_phone(self, value):
        return normalize_phone(value)

    def update(self, instance, validated_data):
        phone = validated_data.pop("phone", None)

        user_fields = (
            "first_name",
            "last_name",
            "email",
        )

        changed_user_fields = []

        for field in user_fields:
            if field in validated_data:
                setattr(instance, field, validated_data[field])
                changed_user_fields.append(field)

        if changed_user_fields:
            instance.save(update_fields=changed_user_fields)

        if phone is not None:
            instance.profile.phone = phone
            instance.profile.save(
                update_fields=(
                    "phone",
                    "updated_at",
                )
            )

        return instance


class ChangePasswordSerializer(serializers.Serializer):
    current_password = serializers.CharField(
        write_only=True,
        trim_whitespace=False,
    )
    new_password = serializers.CharField(
        write_only=True,
        trim_whitespace=False,
    )
    new_password_confirm = serializers.CharField(
        write_only=True,
        trim_whitespace=False,
    )

    def validate(self, attrs):
        user = self.context["request"].user

        if not user.check_password(attrs["current_password"]):
            raise serializers.ValidationError(
                {
                    "current_password": (
                        "Current password is incorrect."
                    )
                }
            )

        if attrs["new_password"] != attrs["new_password_confirm"]:
            raise serializers.ValidationError(
                {
                    "new_password_confirm": (
                        "Password confirmation does not match."
                    )
                }
            )

        try:
            validate_password(attrs["new_password"], user)
        except DjangoValidationError as error:
            raise serializers.ValidationError(
                {"new_password": list(error.messages)}
            ) from error

        return attrs


class LogoutSerializer(serializers.Serializer):
    refresh = serializers.CharField(
        trim_whitespace=False,
    )
