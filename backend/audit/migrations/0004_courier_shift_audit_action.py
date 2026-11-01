from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("audit", "0003_add_account_management_audit_choices"),
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
                    ("courier_shift_changed", "Courier Shift Changed"),
                ],
                max_length=50,
            ),
        ),
    ]
