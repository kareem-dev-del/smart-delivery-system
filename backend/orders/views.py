from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from drf_spectacular.utils import extend_schema, extend_schema_view
from lockers.openapi import LOCKER_DEVICE_IDEMPOTENCY_KEY_PARAMETER


from django.db import transaction

from lockers.idempotency import (
    build_request_hash,
    create_completed_receipt,
    get_replay_receipt,
    parse_idempotency_key,
)
from lockers.models import LockerDevice, LockerDeviceRequest

import uuid

from django.db.models import Q
from .pagination import AdminOrderPagination

from accounts.models import UserProfile
from accounts.permissions import (
    IsAdminRole,
    IsCustomer,
    IsLockerDevice,
    get_user_role,
    IsCourier,
)

from .models import Order
from .serializers import (
    OrderCreateSerializer,
    OrderDrawerAssignmentSerializer,
    OrderReadSerializer,
    PickupQRResponseSerializer,
    OrderCourierAssignmentResponseSerializer,
    OrderCourierAssignmentSerializer,
    CourierReturnQRResponseSerializer,
    CourierAssignmentOrderSerializer,
    OrderAdminReadSerializer,
    AdminOrderListFilterSerializer,
)
from .services import (
    assign_order_to_drawer,
    confirm_order_deposit,
    issue_pickup_qr_token,
    assign_courier_to_order,
    issue_return_qr_token,
    cancel_order,
)



class AdminOrderListAPIView(generics.ListAPIView):
    serializer_class = OrderAdminReadSerializer
    permission_classes = [IsAdminRole]
    pagination_class = AdminOrderPagination

    def get_queryset(self):
        filter_serializer = AdminOrderListFilterSerializer(
            data=self.request.query_params,
        )
        filter_serializer.is_valid(raise_exception=True)

        filters = filter_serializer.validated_data

        queryset = (
            Order.objects.select_related(
                "customer",
                "assigned_courier",
                "locker_station",
                "assigned_drawer",
            )
            .prefetch_related("items")
            .order_by("-created_at")
        )

        if "status" in filters:
            queryset = queryset.filter(status=filters["status"])

        if "locker_station_id" in filters:
            queryset = queryset.filter(
                locker_station_id=filters["locker_station_id"],
            )

        if "courier_id" in filters:
            queryset = queryset.filter(
                assigned_courier_id=filters["courier_id"],
            )

        if "customer_id" in filters:
            queryset = queryset.filter(
                customer_id=filters["customer_id"],
            )

        search = filters.get("search")

        if search:
            search_query = (
                Q(customer__username__icontains=search)
                | Q(assigned_courier__username__icontains=search)
                | Q(locker_station__code__icontains=search)
            )

            try:
                public_id = uuid.UUID(search)
            except ValueError:
                public_id = None

            if public_id:
                search_query |= Q(public_id=public_id)

            queryset = queryset.filter(search_query)

        return queryset




@extend_schema_view(
    get=extend_schema(
        tags=["Orders"],
        responses={status.HTTP_200_OK: OrderReadSerializer(many=True)},
    ),
    post=extend_schema(
        tags=["Orders"],
        request=OrderCreateSerializer,
        responses={status.HTTP_201_CREATED: OrderReadSerializer},
    ),
)
class OrderListCreateAPIView(generics.ListCreateAPIView):
    def get_serializer_class(self):
        if self.request.method == "POST":
           return OrderCreateSerializer

        if get_user_role(self.request.user) == UserProfile.Role.ADMIN:
           return OrderAdminReadSerializer

        return OrderReadSerializer

    def get_permissions(self):
        if self.request.method == "POST":
            return [IsCustomer()]

        return [IsAuthenticated()]

    def get_queryset(self):
        queryset = (
            Order.objects.select_related(
                "customer",
                "locker_station",
                "assigned_drawer",
            )
            .prefetch_related(
                "items",
                "items__product",
            )
            .order_by("-created_at")
        )

        if get_user_role(self.request.user) == UserProfile.Role.ADMIN:
            return queryset

        return queryset.filter(customer=self.request.user)

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        self.perform_create(serializer)

        response_serializer = OrderReadSerializer(
            serializer.instance,
            context=self.get_serializer_context(),
        )

        headers = self.get_success_headers(response_serializer.data)

        return Response(
            response_serializer.data,
            status=status.HTTP_201_CREATED,
            headers=headers,
        )

    def perform_create(self, serializer):
        serializer.save(customer=self.request.user)




@extend_schema(
    tags=["Orders"],
    responses={status.HTTP_200_OK: OrderReadSerializer},
)
class OrderDetailAPIView(generics.RetrieveAPIView):
    def get_serializer_class(self):
      if get_user_role(self.request.user) == UserProfile.Role.ADMIN:
         return OrderAdminReadSerializer

      return OrderReadSerializer
    permission_classes = [IsAuthenticated]
    lookup_field = "public_id"

    def get_queryset(self):
        queryset = (
            Order.objects.select_related(
                "customer",
                "locker_station",
                "assigned_drawer",
            )
            .prefetch_related(
                "items",
                "items__product",
            )
            .order_by("-created_at")
        )

        if get_user_role(self.request.user) == UserProfile.Role.ADMIN:
            return queryset

        return queryset.filter(customer=self.request.user)


class OrderDrawerAssignmentAPIView(generics.GenericAPIView):
    serializer_class = OrderDrawerAssignmentSerializer
    permission_classes = [IsAdminRole]

    def post(self, request, public_id):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            order = assign_order_to_drawer(
                order_public_id=public_id,
                locker_station_id=serializer.validated_data["locker_station_id"],
                drawer_id=serializer.validated_data["drawer_id"],
                actor=request.user,
            )
        except DjangoValidationError as error:
            detail = getattr(error, "message_dict", {"detail": error.messages})

            return Response(
                detail,
                status=status.HTTP_400_BAD_REQUEST,
            )

        response_serializer = OrderAdminReadSerializer(
            order,
            context=self.get_serializer_context(),
        )

        return Response(response_serializer.data, status=status.HTTP_200_OK)



@extend_schema(
    tags=["Orders"],
    request=None,
    responses={status.HTTP_200_OK: OrderReadSerializer},
)
class OrderCancellationAPIView(APIView):
    permission_classes = [IsCustomer]

    def post(self, request, public_id):
        try:
            order = cancel_order(
                order_public_id=public_id,
                customer=request.user,
            )
        except DjangoValidationError as error:
            detail = getattr(error, "message_dict", {"detail": error.messages})

            return Response(
                detail,
                status=status.HTTP_400_BAD_REQUEST,
            )

        response_serializer = OrderReadSerializer(
            order,
            context={"request": request},
        )

        return Response(
            response_serializer.data,
            status=status.HTTP_200_OK,
        )

@extend_schema(
    tags=["Locker Device"],
    request=None,
    parameters=[LOCKER_DEVICE_IDEMPOTENCY_KEY_PARAMETER],
    responses={status.HTTP_200_OK: OrderReadSerializer},
)
class OrderDepositAPIView(generics.GenericAPIView):
    permission_classes = [IsLockerDevice]

    @transaction.atomic
    def post(self, request, public_id):
        idempotency_key = parse_idempotency_key(request)

        try:
            locker_device = LockerDevice.objects.select_for_update().get(
                user=request.user,
                is_active=True,
            )
        except LockerDevice.DoesNotExist:
            return Response(
                {"device": "Active locker device not found."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        operation = (
            LockerDeviceRequest.Operation.DEPOSIT_CONFIRMATION
        )
        request_hash = build_request_hash(
            operation=operation,
            payload={"order_public_id": str(public_id)},
        )

        replay_receipt = get_replay_receipt(
            locker_device=locker_device,
            idempotency_key=idempotency_key,
            operation=operation,
            request_hash=request_hash,
        )

        if replay_receipt is not None:
            return Response(
                replay_receipt.response_body,
                status=replay_receipt.response_status,
            )

        try:
            order = confirm_order_deposit(
                order_public_id=public_id,
                device_user=request.user,
            )
        except DjangoValidationError as error:
            detail = getattr(
                error,
                "message_dict",
                {"detail": error.messages},
            )

            return Response(
                detail,
                status=status.HTTP_400_BAD_REQUEST,
            )

        response_serializer = OrderReadSerializer(
            order,
            context=self.get_serializer_context(),
        )
        response_data = response_serializer.data

        create_completed_receipt(
            locker_device=locker_device,
            order=order,
            operation=operation,
            idempotency_key=idempotency_key,
            request_hash=request_hash,
            response_status=status.HTTP_200_OK,
            response_body=response_data,
        )

        return Response(
            response_data,
            status=status.HTTP_200_OK,
        )


@extend_schema(
    tags=["Orders"],
    request=None,
    responses={status.HTTP_200_OK: PickupQRResponseSerializer},
)
class OrderPickupQRAPIView(APIView):
    permission_classes = [IsCustomer]

    def post(self, request, public_id):
        try:
            qr_token, raw_token = issue_pickup_qr_token(
                order_public_id=public_id,
                customer=request.user,
            )
        except DjangoValidationError as error:
            detail = getattr(error, "message_dict", {"detail": error.messages})

            return Response(
                detail,
                status=status.HTTP_400_BAD_REQUEST,
            )

        order = qr_token.order

        response_serializer = PickupQRResponseSerializer(
            instance={
                "token": raw_token,
                "expires_at": qr_token.expires_at,
                "order_public_id": order.public_id,
                "locker_name": order.locker_station.name,
                "locker_code": order.locker_station.code,
                "locker_address": order.locker_station.address,
            }
        )

        return Response(
            response_serializer.data,
            status=status.HTTP_200_OK,
            headers={"Cache-Control": "no-store"},
        ) 





@extend_schema(
    tags=["Order Administration"],
    request=OrderCourierAssignmentSerializer,
    responses={
        status.HTTP_200_OK: OrderCourierAssignmentResponseSerializer,
    },
)
class OrderCourierAssignmentAPIView(generics.GenericAPIView):
    serializer_class = OrderCourierAssignmentSerializer
    permission_classes = [IsAdminRole]

    def post(self, request, public_id):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            order = assign_courier_to_order(
                order_public_id=public_id,
                courier_id=serializer.validated_data["courier_id"],
                actor=request.user,
            )
        except DjangoValidationError as error:
            detail = getattr(error, "message_dict", {"detail": error.messages})

            return Response(
                detail,
                status=status.HTTP_400_BAD_REQUEST,
            )

        response_serializer = OrderCourierAssignmentResponseSerializer(
            instance={
                "order_public_id": order.public_id,
                "courier_id": order.assigned_courier_id,
                "courier_username": order.assigned_courier.username,
                "courier_assigned_at": order.courier_assigned_at,
            }
        )

        return Response(
            response_serializer.data,
            status=status.HTTP_200_OK,
        )       

class CourierAssignmentListAPIView(generics.ListAPIView):
    serializer_class = CourierAssignmentOrderSerializer
    permission_classes = [IsCourier]

    def get_queryset(self):
        return (
            Order.objects.filter(
                assigned_courier=self.request.user,
                status__in=(
                    Order.Status.AWAITING_LOCKER,
                    Order.Status.ASSIGNED,
                ),
            )
            .select_related(
                "locker_station",
                "assigned_drawer",
            )
            .prefetch_related("items")
            .order_by("courier_assigned_at", "created_at")
        )



class CourierReturnOrderListAPIView(generics.ListAPIView):
    serializer_class = OrderReadSerializer
    permission_classes = [IsCourier]

    def get_queryset(self):
        return (
            Order.objects.filter(
                assigned_courier=self.request.user,
                status=Order.Status.EXPIRED,
            )
            .select_related(
                "locker_station",
                "assigned_drawer",
            )
            .prefetch_related(
                "items",
                "items__product",
            )
            .order_by("-updated_at")
        )



@extend_schema(
    tags=["Courier"],
    request=None,
    responses={status.HTTP_200_OK: CourierReturnQRResponseSerializer},
)
class OrderReturnQRAPIView(APIView):
    permission_classes = [IsCourier]

    def post(self, request, public_id):
        try:
            qr_token, raw_token = issue_return_qr_token(
                order_public_id=public_id,
                courier=request.user,
            )
        except DjangoValidationError as error:
            detail = getattr(error, "message_dict", {"detail": error.messages})

            return Response(
                detail,
                status=status.HTTP_400_BAD_REQUEST,
            )

        order = qr_token.order

        response_serializer = CourierReturnQRResponseSerializer(
            instance={
                "token": raw_token,
                "expires_at": qr_token.expires_at,
                "order_public_id": order.public_id,
                "locker_name": order.locker_station.name,
                "locker_code": order.locker_station.code,
                "locker_address": order.locker_station.address,
            }
        )

        return Response(
            response_serializer.data,
            status=status.HTTP_200_OK,
            headers={"Cache-Control": "no-store"},
        )   