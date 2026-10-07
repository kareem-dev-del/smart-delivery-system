from django.core.cache import cache
from django.test import TestCase


class CacheConfigurationTests(TestCase):
    cache_key = "test:config:cache-round-trip"

    def tearDown(self):
        cache.delete(self.cache_key)
        super().tearDown()

    def test_default_cache_stores_and_retrieves_a_value(self):
        cache.set(self.cache_key, "ready", timeout=30)

        self.assertEqual(
            cache.get(self.cache_key),
            "ready",
        )