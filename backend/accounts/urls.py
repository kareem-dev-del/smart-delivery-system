from django.urls import path

from .views import (
    AdminManagedAccountListCreateAPIView,
    AdminManagedAccountStatusAPIView,
    AdminCourierListAPIView,
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
