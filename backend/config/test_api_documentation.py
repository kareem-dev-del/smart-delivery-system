from django.test import SimpleTestCase
from django.urls import reverse


class APIDocumentationTests(SimpleTestCase):
    def test_openapi_schema_is_available(self):
        response = self.client.get(reverse("api-schema"))

        self.assertEqual(response.status_code, 200)
        self.assertIn(b"openapi", response.content)
        self.assertIn(b"/api/orders/", response.content)

    def test_swagger_ui_is_available(self):
        response = self.client.get(reverse("api-docs"))

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "SwaggerUIBundle")

    def test_device_mutation_endpoints_document_idempotency_key(self):
        response = self.client.get(
            reverse("api-schema"),
            {"format": "json"},
        )

        self.assertEqual(response.status_code, 200)

        schema = response.json()
        endpoint_paths = (
            "/api/orders/{public_id}/deposit/",
            "/api/lockers/pickup-scan/",
            "/api/lockers/orders/{public_id}/confirm-collection/",
            "/api/lockers/return-scan/",
            "/api/lockers/orders/{public_id}/confirm-return/",
        )

        for endpoint_path in endpoint_paths:
            with self.subTest(endpoint_path=endpoint_path):
                parameters = schema["paths"][endpoint_path]["post"].get(
                    "parameters",
                    [],
                )
                idempotency_parameters = [
                    parameter
                    for parameter in parameters
                    if (
                        parameter["name"] == "Idempotency-Key"
                        and parameter["in"] == "header"
                    )
                ]

                self.assertEqual(len(idempotency_parameters), 1)

                parameter = idempotency_parameters[0]
                self.assertTrue(parameter["required"])
                self.assertEqual(parameter["schema"]["format"], "uuid")
