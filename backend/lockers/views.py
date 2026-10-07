from django.db.models import Count, Q
from .services import (
    create_drawer,
    update_drawer_maintenance_status,
    provision_locker_device,
    record_locker_heartbeat,
    get_admin_dashboard_summary,
    set_locker_device_active,
)
from drf_spectacular.utils import extend_schema

from django.utils import timezone

from rest_framework import generics
from rest_framework.permissions import IsAuthenticated

from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.permissions import IsAdminRole, IsLockerDevice
from orders.services import (
    authorize_pickup_by_qr,
    confirm_package_collection,
    authorize_return_by_qr,
    confirm_package_return,
    
)

from accounts.throttles import LockerQRScanRateThrottle




from accounts.models import UserProfile
from accounts.permissions import get_user_role

from .models import Drawer, LockerDevice, LockerStation
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
)


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
    responses={
        status.HTTP_200_OK: OpenDrawerAuthorizationSerializer,
    },
)
class LockerPickupScanAPIView(APIView):
    permission_classes = [IsLockerDevice]
    throttle_classes = [LockerQRScanRateThrottle]

    def post(self, request):
        serializer = PickupQRScanSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            order, drawer = authorize_pickup_by_qr(
                raw_token=serializer.validated_data["token"],
                device_user=request.user,
            )
        except DjangoValidationError as error:
            detail = getattr(error, "message_dict", {"detail": error.messages})

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

        return Response(
            response_serializer.data,
            status=status.HTTP_200_OK,
            headers={"Cache-Control": "no-store"},
        )  



@extend_schema(
    tags=["Locker Device"],
    request=PickupQRScanSerializer,
    responses={
        status.HTTP_200_OK: OpenDrawerAuthorizationSerializer,
    },
)
class LockerReturnScanAPIView(APIView):
    permission_classes = [IsLockerDevice]
    throttle_classes = [LockerQRScanRateThrottle]

    def post(self, request):
        serializer = PickupQRScanSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            order, drawer = authorize_return_by_qr(
                raw_token=serializer.validated_data["token"],
                device_user=request.user,
            )
        except DjangoValidationError as error:
            detail = getattr(error, "message_dict", {"detail": error.messages})

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

        return Response(
            response_serializer.data,
            status=status.HTTP_200_OK,
            headers={"Cache-Control": "no-store"},
        )      



@extend_schema(
    tags=["Locker Device"],
    request=None,
    responses={
        status.HTTP_200_OK: CollectionConfirmationResponseSerializer,
    },
)
class LockerCollectionConfirmationAPIView(APIView):
    permission_classes = [IsLockerDevice]

    def post(self, request, public_id):
        try:
            order, drawer = confirm_package_collection(
                order_public_id=public_id,
                device_user=request.user,
            )
        except DjangoValidationError as error:
            detail = getattr(error, "message_dict", {"detail": error.messages})

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

        return Response(
            response_serializer.data,
            status=status.HTTP_200_OK,
            headers={"Cache-Control": "no-store"},
        )




@extend_schema(
    tags=["Locker Device"],
    request=None,
    responses={
        status.HTTP_200_OK: ReturnConfirmationResponseSerializer,
    },
)
class LockerReturnConfirmationAPIView(APIView):
    permission_classes = [IsLockerDevice]

    def post(self, request, public_id):
        try:
            order, drawer = confirm_package_return(
                order_public_id=public_id,
                device_user=request.user,
                
            )
        except DjangoValidationError as error:
            detail = getattr(error, "message_dict", {"detail": error.messages})

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

        return Response(
            response_serializer.data,
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
    