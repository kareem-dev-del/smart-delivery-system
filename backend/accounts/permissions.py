from rest_framework.permissions import BasePermission

from .models import UserProfile


def get_user_role(user):
    if not user or not user.is_authenticated:
        return None

    profile = getattr(user, "profile", None)

    if profile is None:
        return None

    return profile.role


class IsCustomer(BasePermission):
    message = "Only customers are allowed to perform this action."

    def has_permission(self, request, view):
        return get_user_role(request.user) == UserProfile.Role.CUSTOMER


class IsCourier(BasePermission):
    message = "Only couriers are allowed to perform this action."

    def has_permission(self, request, view):
        return get_user_role(request.user) == UserProfile.Role.COURIER


class IsAdminRole(BasePermission):
    message = "Only admins are allowed to perform this action."

    def has_permission(self, request, view):
        return get_user_role(request.user) == UserProfile.Role.ADMIN


class IsLockerDevice(BasePermission):
    message = "Only locker devices are allowed to perform this action."

    def has_permission(self, request, view):
        return get_user_role(request.user) == UserProfile.Role.LOCKER_DEVICE