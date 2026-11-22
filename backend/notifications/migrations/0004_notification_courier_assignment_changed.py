from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("notifications", "0003_notification_courier_picked_up_type")]

    operations = [
        migrations.AlterField(
            model_name="notification",
            name="notification_type",
            field=models.CharField(
                choices=[
                    ("order_ready_for_pickup", "Order Ready For Pickup"),
                    ("order_pickup_expired", "Order Pickup Expired"),
                    ("courier_assigned", "Courier Assigned"),
                    ("courier_assignment_changed", "Courier Assignment Changed"),
                    ("order_courier_picked_up", "Order Courier Picked Up"),
                    ("courier_return_required", "Courier Return Required"),
                ],
                max_length=40,
            ),
        ),
    ]
