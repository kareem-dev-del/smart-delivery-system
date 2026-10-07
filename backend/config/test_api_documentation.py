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