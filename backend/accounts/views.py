from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from django.core.exceptions import ValidationError as DjangoValidationError

from .serializers import (
    AccountProfileSerializer,
    AccountProfileUpdateSerializer,
    CustomerRegistrationSerializer,
    ChangePasswordSerializer,
    LogoutSerializer,
)

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
    