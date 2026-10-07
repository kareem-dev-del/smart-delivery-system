from unittest.mock import patch

from django.test import TestCase
from django.urls import reverse


class HealthAPIViewTests(TestCase):
    def test_health_reports_process_is_alive(self):
        response = self.client.get(reverse("health"))

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"status": "ok"})
        self.assertEqual(response["Cache-Control"], "no-store")

    def test_health_rejects_non_get_requests(self):
        response = self.client.post(reverse("health"))

        self.assertEqual(response.status_code, 405)

    def test_readiness_reports_database_is_available(self):
        response = self.client.get(reverse("readiness"))

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {
                "status": "ready",
                "checks": {
                    "database": "ok",
                },
            },
        )
        self.assertEqual(response["Cache-Control"], "no-store")

    def test_readiness_reports_unavailable_database(self):
        with patch(
            "config.health.database_is_available",
            return_value=False,
        ):
            response = self.client.get(reverse("readiness"))

        self.assertEqual(response.status_code, 503)
        self.assertEqual(
            response.json(),
            {
                "status": "unavailable",
                "checks": {
                    "database": "unavailable",
                },
            },
        )