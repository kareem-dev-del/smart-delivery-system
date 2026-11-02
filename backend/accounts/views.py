from django.contrib.auth import get_user_model
from django.db import transaction
from django.db.models import Count, Q
from rest_framework import generics, status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from django.core.exceptions import ValidationError as DjangoValidationError
from django.shortcuts import get_object_or_404
from django.utils import timezone
from drf_spectacular.utils import extend_schema, extend_schema_view
from audit.models import AuditLog
from audit.services import create_audit_log

from .serializers import (
    AdminCourierSerializer,
    AccountProfileSerializer,
    AccountProfileUpdateSerializer,
    CustomerRegistrationSerializer,
    ChangePasswordSerializer,
    LogoutSerializer,
    AuthenticationResponseSerializer,
    AdminManagedAccountSerializer,
    AdminManagedAccountCreateSerializer,
    AdminAccountStatusSerializer,
    AdminCourierShiftSerializer,
)
from .models import UserProfile
from .permissions import IsAdminRole, IsCourier
from orders.models import Order

from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
)


from .throttles import (
    AuthenticationRateThrottle,
    PasswordChangeRateThrottle,
)

from .services import (
    blacklist_refresh_token,
    change_password_and_issue_tokens,
)

class ThrottledTokenObtainPairView(TokenObtainPairView):
    throttle_classes = [AuthenticationRateThrottle]


class ThrottledTokenRefreshView(TokenRefreshView):
    throttle_classes = [AuthenticationRateThrottle]


User = get_user_model()
ACTIVE_COURIER_ORDER_STATUSES = (
    Order.Status.AWAITING_LOCKER,
    Order.Status.ASSIGNED,
    Order.Status.EXPIRED,
)


def _with_active_courier_order_count(queryset):
    return queryset.annotate(
        active_order_count=Count(
            "assigned_orders",
            filter=Q(assigned_orders__status__in=ACTIVE_COURIER_ORDER_STATUSES),
            distinct=True,
        )
    )


@extend_schema(
    tags=["Account Administration"],
    responses={status.HTTP_200_OK: AdminCourierSerializer(many=True)},
)
class AdminCourierListAPIView(generics.ListAPIView):
    serializer_class = AdminCourierSerializer
    permission_classes = [IsAdminRole]

    def get_queryset(self):
        return _with_active_courier_order_count(
            User.objects.filter(
                is_active=True,
                profile__role=UserProfile.Role.COURIER,
            )
            .select_related("profile")
            .order_by("username")
        )


@extend_schema_view(
    get=extend_schema(
        tags=["Account Administration"],
        responses={status.HTTP_200_OK: AdminManagedAccountSerializer(many=True)},
    ),
    post=extend_schema(
        tags=["Account Administration"],
        request=AdminManagedAccountCreateSerializer,
        responses={status.HTTP_201_CREATED: AdminManagedAccountSerializer},
    ),
)
class AdminManagedAccountListCreateAPIView(APIView):
    permission_classes = [IsAdminRole]

    def get(self, request):
        users = _with_active_courier_order_count(
            User.objects.filter(
                profile__role__in=(
                    UserProfile.Role.CUSTOMER,
                    UserProfile.Role.COURIER,
                    UserProfile.Role.ADMIN,
                )
            )
            .select_related("profile")
            .order_by("profile__role", "username")
        )
        return Response(
            AdminManagedAccountSerializer(users, many=True).data,
            status=status.HTTP_200_OK,
            headers={"Cache-Control": "no-store"},
        )

    @transaction.atomic
    def post(self, request):
        serializer = AdminManagedAccountCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        create_audit_log(
            actor=request.user,
            action=AuditLog.Action.ACCOUNT_CREATED,
            target_type=AuditLog.TargetType.USER,
            target_id=user.id,
            metadata={"username": user.username, "role": user.profile.role},
        )
        return Response(
            AdminManagedAccountSerializer(user).data,
            status=status.HTTP_201_CREATED,
            headers={"Cache-Control": "no-store"},
        )


@extend_schema(
    tags=["Account Administration"],
    request=AdminAccountStatusSerializer,
    responses={status.HTTP_200_OK: AdminManagedAccountSerializer},
)
class AdminManagedAccountStatusAPIView(APIView):
    permission_classes = [IsAdminRole]

    @transaction.atomic
    def patch(self, request, user_id):
        user = get_object_or_404(
            User.objects.select_for_update(of=("self",)).select_related("profile"),
            pk=user_id,
            profile__role__in=(
                UserProfile.Role.CUSTOMER,
                UserProfile.Role.COURIER,
                UserProfile.Role.ADMIN,
            ),
        )
        serializer = AdminAccountStatusSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        next_is_active = serializer.validated_data["is_active"]
        previous_is_active = user.is_active

        if (
            user.profile.role == UserProfile.Role.ADMIN
            and previous_is_active
            and not next_is_active
        ):
            if user.pk == request.user.pk:
                return Response(
                    {"detail": "You cannot deactivate your own admin account."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            active_admins = list(
                User.objects.select_for_update()
                .filter(is_active=True, profile__role=UserProfile.Role.ADMIN)
                .order_by("pk")
                .values_list("pk", flat=True)
            )
            if len(active_admins) <= 1:
                return Response(
                    {"detail": "The last active admin account cannot be deactivated."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

        if previous_is_active != next_is_active:
            user.is_active = next_is_active
            user.save(update_fields=("is_active",))
            if not next_is_active and user.profile.is_on_shift:
                user.profile.is_on_shift = False
                user.profile.shift_updated_at = timezone.now()
                user.profile.save(
                    update_fields=("is_on_shift", "shift_updated_at", "updated_at")
                )
            create_audit_log(
                actor=request.user,
                action=AuditLog.Action.ACCOUNT_STATUS_CHANGED,
                target_type=AuditLog.TargetType.USER,
                target_id=user.id,
                metadata={
                    "username": user.username,
                    "role": user.profile.role,
                    "is_active": next_is_active,
                },
            )

        user = _with_active_courier_order_count(
            User.objects.filter(pk=user.pk).select_related("profile")
        ).get()
        return Response(
            AdminManagedAccountSerializer(user).data,
            status=status.HTTP_200_OK,
            headers={"Cache-Control": "no-store"},
        )


@extend_schema(
    tags=["Account Administration"],
    request=AdminCourierShiftSerializer,
    responses={status.HTTP_200_OK: AdminManagedAccountSerializer},
)
class AdminCourierShiftAPIView(APIView):
    permission_classes = [IsAdminRole]

    @transaction.atomic
    def patch(self, request, user_id):
        courier = get_object_or_404(
            User.objects.select_for_update(of=("self",)).select_related(
                "profile"
            ),
            pk=user_id,
            profile__role=UserProfile.Role.COURIER,
        )
        serializer = AdminCourierShiftSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        next_is_on_shift = serializer.validated_data["is_on_shift"]

        if next_is_on_shift and not courier.is_active:
            return Response(
                {"detail": "Reactivate this courier account before starting a shift."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not next_is_on_shift and Order.objects.filter(
            assigned_courier=courier,
            status__in=ACTIVE_COURIER_ORDER_STATUSES,
        ).exists():
            return Response(
                {"detail": "Reassign the courier's active orders before ending the shift."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        profile = courier.profile
        previous_is_on_shift = profile.is_on_shift
        if previous_is_on_shift != next_is_on_shift:
            profile.is_on_shift = next_is_on_shift
            profile.shift_updated_at = timezone.now()
            profile.save(
                update_fields=("is_on_shift", "shift_updated_at", "updated_at")
            )
            create_audit_log(
                actor=request.user,
                action=AuditLog.Action.COURIER_SHIFT_CHANGED,
                target_type=AuditLog.TargetType.USER,
                target_id=courier.id,
                metadata={
                    "username": courier.username,
                    "is_on_shift": next_is_on_shift,
                },
            )

        courier = _with_active_courier_order_count(
            User.objects.filter(pk=courier.pk).select_related("profile")
        ).get()
        return Response(
            AdminManagedAccountSerializer(courier).data,
            status=status.HTTP_200_OK,
            headers={"Cache-Control": "no-store"},
        )


@extend_schema_view(
    get=extend_schema(
        tags=["Courier"],
        responses={status.HTTP_200_OK: AdminCourierSerializer},
    ),
    patch=extend_schema(
        tags=["Courier"],
        request=AdminCourierShiftSerializer,
        responses={status.HTTP_200_OK: AdminCourierSerializer},
    ),
)
class CourierSelfShiftAPIView(APIView):
    permission_classes = [IsCourier]

    def get(self, request):
        courier = _with_active_courier_order_count(
            User.objects.filter(pk=request.user.pk).select_related("profile")
        ).get()
        return Response(
            AdminCourierSerializer(courier).data,
            status=status.HTTP_200_OK,
            headers={"Cache-Control": "no-store"},
        )

    @transaction.atomic
    def patch(self, request):
        courier = (
            User.objects.select_for_update(of=("self",))
            .select_related("profile")
            .get(
                pk=request.user.pk,
            )
        )
        serializer = AdminCourierShiftSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        next_is_on_shift = serializer.validated_data["is_on_shift"]

        if not next_is_on_shift and Order.objects.filter(
            assigned_courier=courier,
            status__in=ACTIVE_COURIER_ORDER_STATUSES,
        ).exists():
            return Response(
                {"detail": "Finish or reassign your active orders before ending your shift."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        profile = courier.profile
        if profile.is_on_shift != next_is_on_shift:
            profile.is_on_shift = next_is_on_shift
            profile.shift_updated_at = timezone.now()
            profile.save(
                update_fields=("is_on_shift", "shift_updated_at", "updated_at")
            )
            create_audit_log(
                actor=courier,
                action=AuditLog.Action.COURIER_SHIFT_CHANGED,
                target_type=AuditLog.TargetType.USER,
                target_id=courier.id,
                metadata={
                    "username": courier.username,
                    "is_on_shift": next_is_on_shift,
                    "source": "courier_app",
                },
            )

        courier = _with_active_courier_order_count(
            User.objects.filter(pk=courier.pk).select_related("profile")
        ).get()
        return Response(
            AdminCourierSerializer(courier).data,
            status=status.HTTP_200_OK,
            headers={"Cache-Control": "no-store"},
        )


@extend_schema(
    tags=["Accounts"],
    request=CustomerRegistrationSerializer,
    responses={status.HTTP_201_CREATED: AuthenticationResponseSerializer},
)

class CustomerRegistrationAPIView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [AuthenticationRateThrottle]


    def post(self, request):
        serializer = CustomerRegistrationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        user = serializer.save()

        refresh = RefreshToken.for_user(user)

        return Response(
            {
                "user": AccountProfileSerializer(user).data,
                "access": str(refresh.access_token),
                "refresh": str(refresh),
            },
            status=status.HTTP_201_CREATED,
            headers={"Cache-Control": "no-store"},
        )

@extend_schema_view(
    get=extend_schema(
        tags=["Accounts"],
        responses={status.HTTP_200_OK: AccountProfileSerializer},
    ),
    patch=extend_schema(
        tags=["Accounts"],
        request=AccountProfileUpdateSerializer,
        responses={status.HTTP_200_OK: AccountProfileSerializer},
    ),
)
class MyAccountAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(
            AccountProfileSerializer(request.user).data,
            status=status.HTTP_200_OK,
        )

    def patch(self, request):
        serializer = AccountProfileUpdateSerializer(
            request.user,
            data=request.data,
            partial=True,
        )
        serializer.is_valid(raise_exception=True)

        user = serializer.save()

        return Response(
            AccountProfileSerializer(user).data,
            status=status.HTTP_200_OK,
        )

@extend_schema(
    tags=["Accounts"],
    request=ChangePasswordSerializer,
    responses={status.HTTP_200_OK: AuthenticationResponseSerializer},
)
class ChangePasswordAPIView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_classes = [PasswordChangeRateThrottle]

    def post(self, request):
        serializer = ChangePasswordSerializer(
            data=request.data,
            context={"request": request},
        )
        serializer.is_valid(raise_exception=True)

        user, refresh = change_password_and_issue_tokens(
            user=request.user,
            new_password=serializer.validated_data["new_password"],
        )

        return Response(
            {
                "user": AccountProfileSerializer(user).data,
                "access": str(refresh.access_token),
                "refresh": str(refresh),
            },
            status=status.HTTP_200_OK,
            headers={"Cache-Control": "no-store"},
        )

@extend_schema(
    tags=["Accounts"],
    request=LogoutSerializer,
    responses={status.HTTP_205_RESET_CONTENT: None},
)
class LogoutAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = LogoutSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            blacklist_refresh_token(
                user=request.user,
                raw_refresh_token=serializer.validated_data["refresh"],
            )
        except DjangoValidationError as error:
            detail = getattr(error, "message_dict", {"detail": error.messages})

            return Response(
                detail,
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(
            status=status.HTTP_205_RESET_CONTENT,
            headers={"Cache-Control": "no-store"},
        )

