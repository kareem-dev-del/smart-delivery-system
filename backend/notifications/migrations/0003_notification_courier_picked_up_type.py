from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("notifications", "0002_notification_delivered_at_and_more"),
    ]

    operations = [
        migrations.AlterField(
            model_name="notification",
            name="notification_type",
            field=models.CharField(
                choices=[
                    ("order_ready_for_pickup", "Order Ready For Pickup"),
                    ("order_pickup_expired", "Order Pickup Expired"),
                    ("courier_assigned", "Courier Assigned"),
                    ("order_courier_picked_up", "Order Courier Picked Up"),
                    ("courier_return_required", "Courier Return Required"),
                ],
                max_length=40,
            ),
        ),
    ]
