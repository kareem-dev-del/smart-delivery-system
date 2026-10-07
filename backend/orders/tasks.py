from celery import shared_task

from .services import expire_overdue_orders


@shared_task(ignore_result=True)
def expire_overdue_orders_task():
    return expire_overdue_orders(limit=100)