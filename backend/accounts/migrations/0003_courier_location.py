from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("accounts", "0002_courier_shift_state")]

    operations = [
        migrations.AddField(
            model_name="userprofile",
            name="courier_latitude",
            field=models.DecimalField(
                blank=True, decimal_places=6, max_digits=9, null=True
            ),
        ),
        migrations.AddField(
            model_name="userprofile",
            name="courier_longitude",
            field=models.DecimalField(
                blank=True, decimal_places=6, max_digits=9, null=True
            ),
        ),
        migrations.AddField(
            model_name="userprofile",
            name="courier_location_updated_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]
