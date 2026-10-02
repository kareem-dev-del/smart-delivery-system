from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase


User = get_user_model()


class AuthenticationThrottleAPIViewTests(APITestCase):
    def setUp(self):
        cache.clear()

        User.objects.create_user(
            username="customer",
            password="correct-password",
        )

    def tearDown(self):
        cache.clear()

    def test_login_is_throttled_after_five_attempts(self):
        for _ in range(5):
            response = self.client.post(
                reverse("token-obtain-pair"),
                {
                    "username": "customer",
                    "password": "wrong-password",
                },
                format="json",
            )

            self.assertEqual(
                response.status_code,
                status.HTTP_401_UNAUTHORIZED,
            )

        blocked_response = self.client.post(
            reverse("token-obtain-pair"),
            {
                "username": "customer",
                "password": "wrong-password",
            },
            format="json",
        )

        self.assertEqual(
            blocked_response.status_code,
            status.HTTP_429_TOO_MANY_REQUESTS,
        )
        self.assertIn("Retry-After", blocked_response)