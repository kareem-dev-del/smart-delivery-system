from django.db import transaction
from django.db.models.signals import post_delete, post_save, pre_save
from django.dispatch import receiver

from .cache import invalidate_active_product_list_cache
from .models import Category, Product


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


@receiver(post_save, sender=Category)
@receiver(post_delete, sender=Category)
def invalidate_product_list_cache_after_category_change(
    sender,
    instance,
    **kwargs,
):
    schedule_product_list_cache_invalidation()


@receiver(pre_save, sender=Product)
def delete_replaced_product_image_after_save(sender, instance, **kwargs):
    if not instance.pk:
        return

    previous = Product.objects.filter(pk=instance.pk).only("image").first()
    if not previous or not previous.image:
        return

    old_image = previous.image
    new_image_name = instance.image.name if instance.image else None
    if old_image.name != new_image_name:
        transaction.on_commit(lambda: old_image.delete(save=False))


@receiver(post_delete, sender=Product)
def delete_product_image_after_delete(sender, instance, **kwargs):
    if instance.image:
        image = instance.image
        transaction.on_commit(lambda: image.delete(save=False))
