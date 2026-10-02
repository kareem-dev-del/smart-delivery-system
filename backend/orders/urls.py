from django.urls import path

from .views import (
    OrderDepositAPIView,
    OrderDetailAPIView,
    OrderDrawerAssignmentAPIView,
    OrderListCreateAPIView,
    OrderPickupQRAPIView,
    OrderCourierAssignmentAPIView,
    CourierReturnOrderListAPIView,
    OrderReturnQRAPIView,
    CourierAssignmentListAPIView,
    OrderCancellationAPIView,
    AdminOrderListAPIView,
)


urlpatterns = [
    path("", OrderListCreateAPIView.as_view(), name="order-list-create"),
    path(
    "<uuid:public_id>/cancel/",
    OrderCancellationAPIView.as_view(),
    name="order-cancel",
    ),

    path(
        "<uuid:public_id>/assign/",
        OrderDrawerAssignmentAPIView.as_view(),
        name="order-assign-drawer",
    ),
    path(
        "<uuid:public_id>/deposit/",
        OrderDepositAPIView.as_view(),
        name="order-deposit",
    ),
    path(
    "<uuid:public_id>/pickup-qr/",
    OrderPickupQRAPIView.as_view(),
    name="order-pickup-qr",
    ),
    path(
        "<uuid:public_id>/",
        OrderDetailAPIView.as_view(),
        name="order-detail",
    ),

    path(
    "<uuid:public_id>/assign-courier/",
    OrderCourierAssignmentAPIView.as_view(),
    name="order-assign-courier",
    ),

    path(
    "courier/returns/",
    CourierReturnOrderListAPIView.as_view(),
    name="courier-return-order-list",
    ),
    path(
        "<uuid:public_id>/return-qr/",
        OrderReturnQRAPIView.as_view(),
        name="order-return-qr",
    ),

    path(
    "courier/assignments/",
    CourierAssignmentListAPIView.as_view(),
    name="courier-assignment-list",
    ),

    path(
    "admin/",
    AdminOrderListAPIView.as_view(),
    name="admin-order-list",
    ),

    
]