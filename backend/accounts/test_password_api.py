from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.token_blacklist.models import (
    BlacklistedToken,
)
from rest_framework_simplejwt.tokens import RefreshToken


User = get_user_model()


class AccountPasswordAPIViewTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="customer",
            password="OldSafePass123!2026",
        )

    def change_password_url(self):
        return reverse("account-change-password")

    def logout_url(self):
        return reverse("account-logout")

    def test_unauthenticated_user_cannot_change_password(self):
        response = self.client.post(
            self.change_password_url(),
            {},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_user_can_change_password_and_receive_new_tokens(self):
        old_refresh = RefreshToken.for_user(self.user)

        self.client.force_authenticate(user=self.user)

        response = self.client.post(
            self.change_password_url(),
            {
                "current_password": "OldSafePass123!2026",
                "new_password": "NewSafePass456!2026",
                "new_password_confirm": "NewSafePass456!2026",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("access", response.data)
        self.assertIn("refresh", response.data)
        self.assertEqual(response["Cache-Control"], "no-store")

        self.user.refresh_from_db()

        self.assertTrue(
            self.user.check_password("NewSafePass456!2026")
        )

        self.assertTrue(
            BlacklistedToken.objects.filter(
                token__jti=old_refresh["jti"]
            ).exists()
        )

        new_refresh = RefreshToken(response.data["refresh"])

        self.assertEqual(
            str(new_refresh["user_id"]),
            str(self.user.id),
        )

    def test_change_password_rejects_incorrect_current_password(self):
        self.client.force_authenticate(user=self.user)

        response = self.client.post(
            self.change_password_url(),
            {
                "current_password": "WrongPassword123!",
                "new_password": "NewSafePass456!2026",
                "new_password_confirm": "NewSafePass456!2026",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("current_password", response.data)

    def test_user_can_logout_and_blacklist_refresh_token(self):
        refresh = RefreshToken.for_user(self.user)

        self.client.force_authenticate(user=self.user)

        response = self.client.post(
            self.logout_url(),
            {
                "refresh": str(refresh),
            },
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_205_RESET_CONTENT,
        )

        self.assertTrue(
            BlacklistedToken.objects.filter(
                token__jti=refresh["jti"]
            ).exists()
        )

        with self.assertRaises(TokenError):
            RefreshToken(str(refresh))

    def test_user_cannot_logout_with_another_users_refresh_token(self):
        other_user = User.objects.create_user(
            username="other-customer",
            password="OtherSafePass123!2026",
        )

        other_refresh = RefreshToken.for_user(other_user)

        self.client.force_authenticate(user=self.user)

        response = self.client.post(
            self.logout_url(),
            {
                "refresh": str(other_refresh),
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("refresh", response.data)