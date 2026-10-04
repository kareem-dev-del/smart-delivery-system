from django.core.cache import cache


ACTIVE_PRODUCT_LIST_CACHE_KEY = "products:active-list:v1"


def invalidate_active_product_list_cache():
    cache.delete(ACTIVE_PRODUCT_LIST_CACHE_KEY)