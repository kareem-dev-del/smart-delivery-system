import math

from django.db.models import Count, Q
from .services import (
    create_drawer,
    update_drawer_maintenance_status,
    provision_locker_device,
    record_locker_heartbeat,
    get_admin_dashboard_summary,
    set_locker_device_active,
)

from django.db import transaction
from .openapi import LOCKER_DEVICE_IDEMPOTENCY_KEY_PARAMETER

from orders.models import Order

from .idempotency import (
    OpenCommandReplayUnavailable,
    build_request_hash,
    can_replay_open_command,
    create_completed_receipt,
    get_replay_receipt,
    parse_idempotency_key,
)

from drf_spectacular.utils import extend_schema

from django.utils import timezone

from rest_framework import generics
from rest_framework.permissions import IsAuthenticated

from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.permissions import IsAdminRole, IsCustomer, IsLockerDevice
from orders.services import (
    authorize_pickup_by_qr,
    confirm_package_collection,
    authorize_return_by_qr,
    confirm_package_return,

)

from accounts.throttles import LockerQRScanRateThrottle




from accounts.models import UserProfile
from accounts.permissions import get_user_role


from .models import (
    Drawer,
    LockerDevice,
    LockerDeviceRequest,
    LockerStation,
)
from products.models import Product



from .serializers import (
    LockerStationDetailSerializer,
    LockerStationListSerializer,
    OpenDrawerAuthorizationSerializer,
    PickupQRScanSerializer,
    CollectionConfirmationResponseSerializer,
    ReturnConfirmationResponseSerializer,
    AdminLockerStationWriteSerializer,
    DrawerCreateSerializer,
    DrawerMaintenanceStatusSerializer,
    DrawerSerializer,
    LockerDeviceProvisionSerializer,
    LockerDeviceProvisionResponseSerializer,
    LockerDeviceHeartbeatResponseSerializer,
    AdminLockerDeviceSerializer,
    AdminDashboardSummarySerializer,
    LockerDeviceActivationSerializer,
    NearbyLockerQuerySerializer,
    NearbyLockerSerializer,
)


class NearbyLockerStationAPIView(APIView):
    permission_classes = [IsCustomer]

    @extend_schema(
        parameters=[NearbyLockerQuerySerializer],
        responses={200: NearbyLockerSerializer(many=True)},
        tags=["Lockers"],
    )
    def get(self, request):
        query = NearbyLockerQuerySerializer(data=request.query_params)
        query.is_valid(raise_exception=True)
        data = query.validated_data

        products = list(
            Product.objects.filter(
                id__in=data["product_ids"],
                is_active=True,
            ).only("id", "size")
        )
        if len(products) != len(data["product_ids"]):
            return Response(
                {"product_ids": "One or more products are unavailable."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        size_rank = {
            Product.Size.SMALL: 1,
            Product.Size.MEDIUM: 2,
            Product.Size.LARGE: 3,
        }
        required_rank = max(size_rank[product.size] for product in products)
        compatible_sizes = [
            size for size, rank in size_rank.items() if rank >= required_rank
        ]
        stations = list(
            LockerStation.objects.filter(status=LockerStation.Status.ONLINE)
            .annotate(
                available_drawers_count=Count(
                    "drawers",
                    filter=Q(
                        drawers__status=Drawer.Status.AVAILABLE,
                        drawers__size__in=compatible_sizes,
                    ),
                )
            )
            .filter(available_drawers_count__gt=0)
        )

        latitude = data.get("latitude")
        longitude = data.get("longitude")
        for station in stations:
            station.distance_km = None
            if latitude is not None and longitude is not None:
                station.distance_km = self._distance_km(
                    float(latitude),
                    float(longitude),
                    float(station.latitude),
                    float(station.longitude),
                )

        stations.sort(
            key=lambda station: (
                station.distance_km is None,
                station.distance_km if station.distance_km is not None else 0,
                station.name.lower(),
            )
        )
        return Response(NearbyLockerSerializer(stations, many=True).data)

    @staticmethod
    def _distance_km(latitude_a, longitude_a, latitude_b, longitude_b):
        radians = math.pi / 180
        latitude_delta = (latitude_b - latitude_a) * radians
        longitude_delta = (longitude_b - longitude_a) * radians
        value = (
            math.sin(latitude_delta / 2) ** 2
            + math.cos(latitude_a * radians)
            * math.cos(latitude_b * radians)
            * math.sin(longitude_delta / 2) ** 2
        )
        return round(6371 * 2 * math.asin(math.sqrt(value)), 2)


class AdminLockerDeviceActivationAPIView(generics.GenericAPIView):
    serializer_class = LockerDeviceActivationSerializer
    permission_classes = [IsAdminRole]

    def patch(self, request, device_id):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            locker_device = set_locker_device_active(
                device_id=device_id,
                is_active=serializer.validated_data["is_active"],
                actor=request.user,
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

        response_serializer = AdminLockerDeviceSerializer(
            locker_device,
            context={"now": timezone.now()},
        )

        return Response(
            response_serializer.data,
            status=status.HTTP_200_OK,
            headers={"Cache-Control": "no-store"},
        )


def is_admin(user):
    return get_user_role(user) == UserProfile.Role.ADMIN

class AdminLockerStationCreateAPIView(generics.CreateAPIView):
    queryset = LockerStation.objects.all()
    serializer_class = AdminLockerStationWriteSerializer
    permission_classes = [IsAdminRole]


class AdminLockerStationUpdateAPIView(generics.UpdateAPIView):
    queryset = LockerStation.objects.all()
    serializer_class = AdminLockerStationWriteSerializer
    permission_classes = [IsAdminRole]


class AdminDrawerCreateAPIView(generics.GenericAPIView):
    serializer_class = DrawerCreateSerializer
    permission_classes = [IsAdminRole]

    def post(self, request, locker_station_id):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            drawer = create_drawer(
            locker_station_id=locker_station_id,
            number=serializer.validated_data["number"],
            size=serializer.validated_data["size"],
            actor=request.user,
             )
        except DjangoValidationError as error:
            detail = getattr(error, "message_dict", {"detail": error.messages})

            return Response(
                detail,
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(
            DrawerSerializer(drawer).data,
            status=status.HTTP_201_CREATED,
        )


class AdminDrawerMaintenanceStatusAPIView(generics.GenericAPIView):
    serializer_class = DrawerMaintenanceStatusSerializer
    permission_classes = [IsAdminRole]

    def patch(self, request, drawer_id):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            drawer = update_drawer_maintenance_status(
            drawer_id=drawer_id,
            target_status=serializer.validated_data["status"],
            actor=request.user,
           )
        except DjangoValidationError as error:
            detail = getattr(error, "message_dict", {"detail": error.messages})

            return Response(
                detail,
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(
            DrawerSerializer(drawer).data,
            status=status.HTTP_200_OK,
        )



@extend_schema(
    tags=["Locker Administration"],
    request=LockerDeviceProvisionSerializer,
    responses={
        status.HTTP_201_CREATED: LockerDeviceProvisionResponseSerializer,
    },
)
class AdminLockerDeviceProvisionAPIView(APIView):
    permission_classes = [IsAdminRole]

    def post(self, request, locker_station_id):
        serializer = LockerDeviceProvisionSerializer(
            data=request.data
        )
        serializer.is_valid(raise_exception=True)

        try:
            locker_device, username, initial_password = (
            provision_locker_device(
                locker_station_id=locker_station_id,
                device_code=serializer.validated_data["device_code"],
                actor=request.user,
            )
        )
        except DjangoValidationError as error:
            detail = getattr(error, "message_dict", {"detail": error.messages})

            return Response(
                detail,
                status=status.HTTP_400_BAD_REQUEST,
            )

        response_serializer = LockerDeviceProvisionResponseSerializer(
            instance={
                "device_id": locker_device.id,
                "locker_station_id": locker_device.locker_station_id,
                "locker_code": locker_device.locker_station.code,
                "device_code": locker_device.device_code,
                "username": username,
                "initial_password": initial_password,
            }
        )

        return Response(
            response_serializer.data,
            status=status.HTTP_201_CREATED,
            headers={"Cache-Control": "no-store"},
        )


class LockerStationListAPIView(generics.ListAPIView):
    serializer_class = LockerStationListSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        queryset = LockerStation.objects.annotate(
            available_drawers_count=Count(
                "drawers",
                filter=Q(drawers__status=Drawer.Status.AVAILABLE),
            )
        ).order_by("name")

        if not is_admin(self.request.user):
            queryset = queryset.filter(status=LockerStation.Status.ONLINE)

        return queryset


class LockerStationRetrieveAPIView(generics.RetrieveAPIView):
    serializer_class = LockerStationDetailSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        queryset = LockerStation.objects.prefetch_related("drawers").order_by("name")

        if not is_admin(self.request.user):
            queryset = queryset.filter(status=LockerStation.Status.ONLINE)

        return queryset



@extend_schema(
    tags=["Locker Device"],
    request=PickupQRScanSerializer,
    parameters=[LOCKER_DEVICE_IDEMPOTENCY_KEY_PARAMETER],
    responses={
        status.HTTP_200_OK: OpenDrawerAuthorizationSerializer,
    },
)
class LockerPickupScanAPIView(APIView):
    permission_classes = [IsLockerDevice]
    throttle_classes = [LockerQRScanRateThrottle]

    @transaction.atomic
    def post(self, request):
        serializer = PickupQRScanSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

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

        operation = LockerDeviceRequest.Operation.PICKUP_SCAN
        raw_token = serializer.validated_data["token"]
        request_hash = build_request_hash(
            operation=operation,
            payload={"token": raw_token},
        )

        replay_receipt = get_replay_receipt(
            locker_device=locker_device,
            idempotency_key=idempotency_key,
            operation=operation,
            request_hash=request_hash,
        )

        if replay_receipt is not None:
            if (
                not replay_receipt.order_id
                or not can_replay_open_command(
                    receipt=replay_receipt,
                )
            ):
                raise OpenCommandReplayUnavailable()

            replay_order = Order.objects.select_for_update().get(
                id=replay_receipt.order_id,
            )

            if (
                replay_order.status != Order.Status.READY_FOR_PICKUP
                or not replay_order.assigned_drawer_id
                or replay_order.locker_station_id
                != locker_device.locker_station_id
            ):
                raise OpenCommandReplayUnavailable()

            replay_drawer = Drawer.objects.select_for_update().get(
                id=replay_order.assigned_drawer_id,
            )

            if replay_drawer.status != Drawer.Status.OCCUPIED:
                raise OpenCommandReplayUnavailable()

            return Response(
                replay_receipt.response_body,
                status=replay_receipt.response_status,
                headers={"Cache-Control": "no-store"},
            )

        try:
            order, drawer = authorize_pickup_by_qr(
                raw_token=raw_token,
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

        response_serializer = OpenDrawerAuthorizationSerializer(
            instance={
                "command": "open_drawer",
                "drawer_number": drawer.number,
                "order_public_id": order.public_id,
            }
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
            headers={"Cache-Control": "no-store"},
        )


@extend_schema(
    tags=["Locker Device"],
    request=PickupQRScanSerializer,
    parameters=[LOCKER_DEVICE_IDEMPOTENCY_KEY_PARAMETER],
    responses={
        status.HTTP_200_OK: OpenDrawerAuthorizationSerializer,
    },
)
class LockerReturnScanAPIView(APIView):
    permission_classes = [IsLockerDevice]
    throttle_classes = [LockerQRScanRateThrottle]

    @transaction.atomic
    def post(self, request):
        serializer = PickupQRScanSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

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

        operation = LockerDeviceRequest.Operation.RETURN_SCAN
        raw_token = serializer.validated_data["token"]
        request_hash = build_request_hash(
            operation=operation,
            payload={"token": raw_token},
        )

        replay_receipt = get_replay_receipt(
            locker_device=locker_device,
            idempotency_key=idempotency_key,
            operation=operation,
            request_hash=request_hash,
        )

        if replay_receipt is not None:
            if (
                not replay_receipt.order_id
                or not can_replay_open_command(
                    receipt=replay_receipt,
                )
            ):
                raise OpenCommandReplayUnavailable()

            replay_order = Order.objects.select_for_update().get(
                id=replay_receipt.order_id,
            )

            if (
                replay_order.status != Order.Status.EXPIRED
                or not replay_order.return_opened_at
                or not replay_order.assigned_drawer_id
                or replay_order.locker_station_id
                != locker_device.locker_station_id
            ):
                raise OpenCommandReplayUnavailable()

            replay_drawer = Drawer.objects.select_for_update().get(
                id=replay_order.assigned_drawer_id,
            )

            if replay_drawer.status != Drawer.Status.RETURN_PENDING:
                raise OpenCommandReplayUnavailable()

            return Response(
                replay_receipt.response_body,
                status=replay_receipt.response_status,
                headers={"Cache-Control": "no-store"},
            )

        try:
            order, drawer = authorize_return_by_qr(
                raw_token=raw_token,
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

        response_serializer = OpenDrawerAuthorizationSerializer(
            instance={
                "command": "open_drawer",
                "drawer_number": drawer.number,
                "order_public_id": order.public_id,
            }
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
            headers={"Cache-Control": "no-store"},
        )



@extend_schema(
    tags=["Locker Device"],
    parameters=[LOCKER_DEVICE_IDEMPOTENCY_KEY_PARAMETER],
    request=None,
    responses={
        status.HTTP_200_OK: CollectionConfirmationResponseSerializer,
    },
)
class LockerCollectionConfirmationAPIView(APIView):
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
            LockerDeviceRequest.Operation.COLLECTION_CONFIRMATION
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
                headers={"Cache-Control": "no-store"},
            )

        try:
            order, drawer = confirm_package_collection(
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

        response_serializer = CollectionConfirmationResponseSerializer(
            instance={
                "order_public_id": order.public_id,
                "status": order.status,
                "drawer_number": drawer.number,
                "drawer_status": drawer.status,
                "collected_at": order.collected_at,
            }
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
            headers={"Cache-Control": "no-store"},
        )




@extend_schema(
    tags=["Locker Device"],
    parameters=[LOCKER_DEVICE_IDEMPOTENCY_KEY_PARAMETER],
    request=None,
    responses={
        status.HTTP_200_OK: ReturnConfirmationResponseSerializer,
    },
)
class LockerReturnConfirmationAPIView(APIView):
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
            LockerDeviceRequest.Operation.RETURN_CONFIRMATION
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
                headers={"Cache-Control": "no-store"},
            )

        try:
            order, drawer = confirm_package_return(
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

        response_serializer = ReturnConfirmationResponseSerializer(
            instance={
                "order_public_id": order.public_id,
                "status": order.status,
                "drawer_number": drawer.number,
                "drawer_status": drawer.status,
                "returned_at": order.returned_at,
            }
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
            headers={"Cache-Control": "no-store"},
        )




@extend_schema(
    tags=["Locker Device"],
    request=None,
    responses={
        status.HTTP_200_OK: LockerDeviceHeartbeatResponseSerializer,
    },
)
class LockerDeviceHeartbeatAPIView(APIView):
    permission_classes = [IsLockerDevice]

    def post(self, request):
        try:
            locker_device = record_locker_heartbeat(
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

        response_serializer = LockerDeviceHeartbeatResponseSerializer(
            instance={
                "device_code": locker_device.device_code,
                "locker_code": locker_device.locker_station.code,
                "locker_status": locker_device.locker_station.status,
                "last_heartbeat_at": locker_device.last_heartbeat_at,
            }
        )

        return Response(
            response_serializer.data,
            status=status.HTTP_200_OK,
            headers={"Cache-Control": "no-store"},
        )


class AdminLockerDeviceListAPIView(generics.ListAPIView):
    serializer_class = AdminLockerDeviceSerializer
    permission_classes = [IsAdminRole]

    def get_queryset(self):
        return LockerDevice.objects.select_related(
            "locker_station"
        ).order_by(
            "locker_station__name"
        )

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context["now"] = timezone.now()
        return context



@extend_schema(
    tags=["Locker Administration"],
    responses={
        status.HTTP_200_OK: AdminDashboardSummarySerializer,
    },
)
class AdminDashboardSummaryAPIView(APIView):
    permission_classes = [IsAdminRole]

    def get(self, request):
        summary = get_admin_dashboard_summary()

        serializer = AdminDashboardSummarySerializer(
            instance=summary,
        )

        return Response(
            serializer.data,
            status=status.HTTP_200_OK,
            headers={"Cache-Control": "no-store"},
        )

