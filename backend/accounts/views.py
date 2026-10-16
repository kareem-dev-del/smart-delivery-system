from django.contrib.auth import get_user_model
from rest_framework import generics, status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from django.core.exceptions import ValidationError as DjangoValidationError
from drf_spectacular.utils import extend_schema, extend_schema_view

from .serializers import (
    AdminCourierSerializer,
    AccountProfileSerializer,
    AccountProfileUpdateSerializer,
    CustomerRegistrationSerializer,
    ChangePasswordSerializer,
    LogoutSerializer,
    AuthenticationResponseSerializer,
)
from .models import UserProfile
from .permissions import IsAdminRole

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


@extend_schema(
    tags=["Account Administration"],
    responses={status.HTTP_200_OK: AdminCourierSerializer(many=True)},
)
class AdminCourierListAPIView(generics.ListAPIView):
    serializer_class = AdminCourierSerializer
    permission_classes = [IsAdminRole]

    def get_queryset(self):
        return (
            User.objects.filter(
                is_active=True,
                profile__role=UserProfile.Role.COURIER,
            )
            .select_related("profile")
            .order_by("username")
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

