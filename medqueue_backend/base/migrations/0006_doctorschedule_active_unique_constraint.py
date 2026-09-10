from django.db import migrations, models
from django.db.models import Q


class Migration(migrations.Migration):

    dependencies = [
        ("base", "0005_profile_picture_upload"),
    ]

    operations = [
        migrations.AlterUniqueTogether(
            name="doctorschedule",
            unique_together=set(),
        ),
        migrations.AddConstraint(
            model_name="doctorschedule",
            constraint=models.UniqueConstraint(
                fields=("doctor", "day_of_week"),
                condition=Q(is_active=True),
                name="unique_active_doctor_day_schedule",
            ),
        ),
    ]