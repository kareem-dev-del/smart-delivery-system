from django.urls import path

from .views import (
    AdminManagedAccountListCreateAPIView,
    AdminManagedAccountStatusAPIView,
    AdminCourierListAPIView,
    AdminCourierShiftAPIView,
    CourierSelfShiftAPIView,
    ChangePasswordAPIView,
    CustomerRegistrationAPIView,
    LogoutAPIView,
    MyAccountAPIView,
)


urlpatterns = [
    path(
        "admin/users/",
        AdminManagedAccountListCreateAPIView.as_view(),
        name="admin-managed-user-list-create",
    ),
    path(
        "admin/users/<int:user_id>/status/",
        AdminManagedAccountStatusAPIView.as_view(),
        name="admin-managed-user-status",
    ),
    path(
        "admin/couriers/",
        AdminCourierListAPIView.as_view(),
        name="admin-courier-list",
    ),
    path(
        "admin/couriers/<int:user_id>/shift/",
        AdminCourierShiftAPIView.as_view(),
        name="admin-courier-shift",
    ),
    path(
        "couriers/me/shift/",
        CourierSelfShiftAPIView.as_view(),
        name="courier-self-shift",
    ),
    path(
        "register/",
        CustomerRegistrationAPIView.as_view(),
        name="account-register",
    ),
    path(
        "me/",
        MyAccountAPIView.as_view(),
        name="account-me",
    ),
    path(
        "change-password/",
        ChangePasswordAPIView.as_view(),
        name="account-change-password",
    ),
    path(
        "logout/",
        LogoutAPIView.as_view(),
        name="account-logout",
    ),
]
