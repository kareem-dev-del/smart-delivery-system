from django.urls import path

from .views import (
    AdminCourierListAPIView,
    ChangePasswordAPIView,
    CustomerRegistrationAPIView,
    LogoutAPIView,
    MyAccountAPIView,
)


urlpatterns = [
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
