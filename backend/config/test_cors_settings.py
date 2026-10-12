from django.conf import settings
from django.test import SimpleTestCase


class CORSSettingsTests(SimpleTestCase):
    def test_cors_application_is_installed(self):
        self.assertIn("corsheaders", settings.INSTALLED_APPS)

    def test_cors_middleware_runs_before_common_middleware(self):
        cors_index = settings.MIDDLEWARE.index(
            "corsheaders.middleware.CorsMiddleware"
        )
        common_index = settings.MIDDLEWARE.index(
            "django.middleware.common.CommonMiddleware"
        )

        self.assertLess(cors_index, common_index)

    def test_local_frontend_origins_are_allowed_by_default(self):
        self.assertIn(
            "http://localhost:3000",
            settings.CORS_ALLOWED_ORIGINS,
        )
        self.assertIn(
            "http://127.0.0.1:5173",
            settings.CORS_ALLOWED_ORIGINS,
        )
