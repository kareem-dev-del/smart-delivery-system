from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("audit", "0002_alter_auditlog_action"),
    ]

    operations = [
        migrations.AlterField(
            model_name="auditlog",
            name="action",
            field=models.CharField(
                choices=[
                    ("order_drawer_assigned", "Order Drawer Assigned"),
                    ("order_courier_assigned", "Order Courier Assigned"),
                    ("order_cancelled", "Order Cancelled"),
                    ("locker_station_created", "Locker Station Created"),
                    ("locker_station_updated", "Locker Station Updated"),
                    ("drawer_created", "Drawer Created"),
                    ("drawer_maintenance_status_changed", "Drawer Maintenance Status Changed"),
                    ("locker_device_provisioned", "Locker Device Provisioned"),
                    ("locker_device_deactivated", "Locker Device Deactivated"),
                    ("locker_device_activated", "Locker Device Activated"),
                    ("account_created", "Account Created"),
                    ("account_status_changed", "Account Status Changed"),
                ],
                max_length=50,
            ),
        ),
        migrations.AlterField(
            model_name="auditlog",
            name="target_type",
            field=models.CharField(
                choices=[
                    ("order", "Order"),
                    ("locker_station", "Locker Station"),
                    ("drawer", "Drawer"),
                    ("locker_device", "Locker Device"),
                    ("user", "User"),
                ],
                max_length=30,
            ),
        ),
    ]
