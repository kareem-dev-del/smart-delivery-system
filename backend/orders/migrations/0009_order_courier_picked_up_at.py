from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("orders", "0008_order_cancelled_at"),
    ]

    operations = [
        migrations.AddField(
            model_name="order",
            name="courier_picked_up_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]
