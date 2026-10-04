from django.db import transaction
from django.db.models.signals import post_delete, post_save
from django.dispatch import receiver

from .cache import invalidate_active_product_list_cache
from .models import Product


def schedule_product_list_cache_invalidation():
    transaction.on_commit(
        invalidate_active_product_list_cache
    )


@receiver(post_save, sender=Product)
def invalidate_product_list_cache_after_save(
    sender,
    instance,
    **kwargs,
):
    schedule_product_list_cache_invalidation()


@receiver(post_delete, sender=Product)
def invalidate_product_list_cache_after_delete(
    sender,
    instance,
    **kwargs,
):
    schedule_product_list_cache_invalidation()