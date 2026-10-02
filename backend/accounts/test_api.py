from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from .models import UserProfile


User = get_user_model()


class AccountAPIViewTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="customer",
            password="SafePass123!2026",
        )

    def register_url(self):
        return reverse("account-register")

    def me_url(self):
        return reverse("account-me")

    def test_customer_can_register_and_receive_tokens(self):
        response = self.client.post(
            self.register_url(),
            {
                "username": "kareem",
                "password": "SafePass123!2026",
                "password_confirm": "SafePass123!2026",
                "first_name": "Kareem",
                "email": "kareem@example.com",
                "phone": "+201012345678",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn("access", response.data)
        self.assertIn("refresh", response.data)
        self.assertEqual(response.data["user"]["username"], "kareem")
        self.assertEqual(
            response.data["user"]["phone"],
            "+201012345678",
        )
        self.assertEqual(response["Cache-Control"], "no-store")

        user = User.objects.get(username="kareem")

        self.assertTrue(
            user.check_password("SafePass123!2026")
        )
        self.assertEqual(
            user.profile.role,
            UserProfile.Role.CUSTOMER,
        )

    def test_register_rejects_existing_username(self):
        response = self.client.post(
            self.register_url(),
            {
                "username": "Customer",
                "password": "SafePass123!2026",
                "password_confirm": "SafePass123!2026",
                "phone": "+201012345678",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("username", response.data)

    def test_register_rejects_mismatched_password_confirmation(self):
        response = self.client.post(
            self.register_url(),
            {
                "username": "new-customer",
                "password": "SafePass123!2026",
                "password_confirm": "DifferentPass123!2026",
                "phone": "+201012345678",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("password_confirm", response.data)

    def test_unauthenticated_user_cannot_read_profile(self):
        response = self.client.get(self.me_url())

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_authenticated_user_can_read_own_profile(self):
        self.user.profile.phone = "+201111111111"
        self.user.profile.save(update_fields=("phone",))

        self.client.force_authenticate(user=self.user)

        response = self.client.get(self.me_url())

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["username"], "customer")
        self.assertEqual(
            response.data["phone"],
            "+201111111111",
        )
        self.assertEqual(
            response.data["role"],
            UserProfile.Role.CUSTOMER,
        )

    def test_authenticated_user_can_update_own_profile(self):
        self.client.force_authenticate(user=self.user)

        response = self.client.patch(
            self.me_url(),
            {
                "first_name": "Kareem",
                "phone": "01012345678",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["first_name"], "Kareem")
        self.assertEqual(
            response.data["phone"],
            "01012345678",
        )

        self.user.refresh_from_db()
        self.user.profile.refresh_from_db()

        self.assertEqual(self.user.first_name, "Kareem")
        self.assertEqual(
            self.user.profile.phone,
            "01012345678",
        )